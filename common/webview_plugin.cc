#include "webview_plugin.h"

#ifdef OS_MAC
#include <include/wrapper/cef_library_loader.h>
#endif

#include <math.h>
#include <memory>
#include <thread>
#include <iostream>
#include <unordered_map>
#include <cstdlib>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <vector>
#include <algorithm>
#include <chrono>

#include "include/wrapper/cef_closure_task.h"

namespace
{
	class LambdaTask : public CefTask
	{
	public:
		explicit LambdaTask(std::function<void()> f) : f_(std::move(f)) {}
		void Execute() override
		{
			if (f_)
				f_();
		}

	private:
		std::function<void()> f_;
		IMPLEMENT_REFCOUNTING(LambdaTask);
	};
	inline void RunOnCefUI(std::function<void()> fn)
	{
		if (CefCurrentlyOn(TID_UI))
		{
			fn();
		}
		else
		{
			CefPostTask(TID_UI, new LambdaTask(std::move(fn)));
		}
	}
	inline void RunOnCefIO(std::function<void()> fn)
	{
		if (CefCurrentlyOn(TID_IO))
		{
			fn();
		}
		else
		{
			CefPostTask(TID_IO, new LambdaTask(std::move(fn)));
		}
	}

	// Execute on CEF UI thread and block until completion (with short timeout).
	inline void RunOnCefUISync(std::function<void()> fn)
	{
		if (CefCurrentlyOn(TID_UI))
		{
			fn();
			return;
		}
		std::mutex mtx;
		std::condition_variable cv;
		bool done = false;
		CefPostTask(TID_UI, new LambdaTask([&]()
										   {
			fn();
			std::unique_lock<std::mutex> lk(mtx);
			done = true;
			cv.notify_one(); }));
		std::unique_lock<std::mutex> lk(mtx);
		cv.wait_for(lk, std::chrono::seconds(2), [&]()
					{ return done; });
	}
}

namespace webview_cef
{
	CefMainArgs mainArgs;
	CefRefPtr<WebviewApp> app;
	CefString userAgent;
	CefString cachePath;
	bool enableGPU = false;
	bool persistSessionCookies = false;
	bool persistUserPreferences = false;
	bool isCefInitialized = false;
	// atexit-based shutdown is disabled for Flutter integration.
	static std::atomic<int> s_openBrowsers{0};
	static std::atomic<bool> s_shutdownRequested{false};
	static std::mutex s_handlerMutex;
	static std::vector<CefRefPtr<WebviewHandler>> s_handlers;

	// no-op

	WebviewPlugin::WebviewPlugin()
	{
		m_handler = new WebviewHandler();
		{
			std::lock_guard<std::mutex> lock(s_handlerMutex);
			s_handlers.push_back(m_handler);
		}
	}

	WebviewPlugin::~WebviewPlugin()
	{
		uninitCallback();
		RunOnCefUI([=]()
				   {
			if (m_handler.get()) m_handler->CloseAllBrowsers(true); });
		{
			std::lock_guard<std::mutex> lock(s_handlerMutex);
			s_handlers.erase(std::remove(s_handlers.begin(), s_handlers.end(), m_handler), s_handlers.end());
		}
		m_handler = nullptr;
		if (!m_renderers.empty())
		{
			m_renderers.clear();
		}
	}

	void WebviewPlugin::initCallback()
	{
		if (!m_init)
		{
			// One-time wiring from CEF events to lifecycle counters.
			m_handler->onLoadStart = [=](int nBrowserId, std::string urlId)
			{
				if (m_invokeFunc)
				{
					WValue *bId = webview_value_new_int(nBrowserId);
					WValue *uId = webview_value_new_string(const_cast<char *>(urlId.c_str()));
					WValue *retMap = webview_value_new_map();
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "urlId", uId);
					m_invokeFunc("onLoadStart", retMap);
					webview_value_unref(bId);
					webview_value_unref(uId);
					webview_value_unref(retMap);
				}
			};

			m_handler->onLoadEnd = [=](int nBrowserId, std::string urlId)
			{
				if (m_invokeFunc)
				{
					WValue *bId = webview_value_new_int(nBrowserId);
					WValue *uId = webview_value_new_string(const_cast<char *>(urlId.c_str()));
					WValue *retMap = webview_value_new_map();
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "urlId", uId);
					m_invokeFunc("onLoadEnd", retMap);
					webview_value_unref(bId);
					webview_value_unref(uId);
					webview_value_unref(retMap);
				}
			};

			m_handler->onPaintCallback = [=](int browserId, const void *buffer, int32_t width, int32_t height)
			{
				if (m_renderers.find(browserId) != m_renderers.end() && m_renderers[browserId] != nullptr)
				{
					m_renderers[browserId]->onFrame(buffer, width, height);
				}
			};

			m_handler->onTooltipEvent = [=](int browserId, std::string text)
			{
				if (m_invokeFunc)
				{
					WValue *bId = webview_value_new_int(browserId);
					WValue *wText = webview_value_new_string(const_cast<char *>(text.c_str()));
					WValue *retMap = webview_value_new_map();
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "text", wText);
					m_invokeFunc("onTooltip", retMap);
					webview_value_unref(bId);
					webview_value_unref(wText);
					webview_value_unref(retMap);
				}
			};

			m_handler->onCursorChangedEvent = [=](int browserId, int type)
			{
				if (m_invokeFunc)
				{
					WValue *bId = webview_value_new_int(browserId);
					WValue *wType = webview_value_new_int(type);
					WValue *retMap = webview_value_new_map();
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "type", wType);
					m_invokeFunc("onCursorChanged", retMap);
					webview_value_unref(bId);
					webview_value_unref(wType);
					webview_value_unref(retMap);
				}
			};

			m_handler->onConsoleMessageEvent = [=](int browserId, int level, std::string message, std::string source, int line)
			{
				if (m_invokeFunc)
				{
					WValue *bId = webview_value_new_int(browserId);
					WValue *wLevel = webview_value_new_int(level);
					WValue *wMessage = webview_value_new_string(const_cast<char *>(message.c_str()));
					WValue *wSource = webview_value_new_string(const_cast<char *>(source.c_str()));
					WValue *wLine = webview_value_new_int(line);
					WValue *retMap = webview_value_new_map();
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "level", wLevel);
					webview_value_set_string(retMap, "message", wMessage);
					webview_value_set_string(retMap, "source", wSource);
					webview_value_set_string(retMap, "line", wLine);
					m_invokeFunc("onConsoleMessage", retMap);
					webview_value_unref(bId);
					webview_value_unref(wLevel);
					webview_value_unref(wMessage);
					webview_value_unref(wSource);
					webview_value_unref(wLine);
					webview_value_unref(retMap);
				}
			};

			m_handler->onUrlChangedEvent = [=](int browserId, std::string url)
			{
				if (m_invokeFunc)
				{
					WValue *bId = webview_value_new_int(browserId);
					WValue *wUrl = webview_value_new_string(const_cast<char *>(url.c_str()));
					WValue *retMap = webview_value_new_map();
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "url", wUrl);
					m_invokeFunc("urlChanged", retMap);
					webview_value_unref(bId);
					webview_value_unref(wUrl);
					webview_value_unref(retMap);
				}
			};

			m_handler->onTitleChangedEvent = [=](int browserId, std::string title)
			{
				if (m_invokeFunc)
				{
					WValue *bId = webview_value_new_int(browserId);
					WValue *wTitle = webview_value_new_string(const_cast<char *>(title.c_str()));
					WValue *retMap = webview_value_new_map();
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "title", wTitle);
					m_invokeFunc("titleChanged", retMap);
					webview_value_unref(bId);
					webview_value_unref(wTitle);
					webview_value_unref(retMap);
				}
			};

			m_handler->onJavaScriptChannelMessage = [=](std::string channelName, std::string message, std::string callbackId, int browserId, std::string frameId)
			{
				if (m_invokeFunc)
				{
					WValue *retMap = webview_value_new_map();
					WValue *channel = webview_value_new_string(const_cast<char *>(channelName.c_str()));
					WValue *msg = webview_value_new_string(const_cast<char *>(message.c_str()));
					WValue *cbId = webview_value_new_string(const_cast<char *>(callbackId.c_str()));
					WValue *bId = webview_value_new_int(browserId);
					WValue *fId = webview_value_new_string(const_cast<char *>(frameId.c_str()));
					webview_value_set_string(retMap, "channel", channel);
					webview_value_set_string(retMap, "message", msg);
					webview_value_set_string(retMap, "callbackId", cbId);
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "frameId", fId);
					m_invokeFunc("javascriptChannelMessage", retMap);
					webview_value_unref(retMap);
					webview_value_unref(channel);
					webview_value_unref(msg);
					webview_value_unref(cbId);
					webview_value_unref(bId);
					webview_value_unref(fId);
				}
			};

			m_handler->onFocusedNodeChangeMessage = [=](int nBrowserId, bool bEditable)
			{
				if (m_invokeFunc)
				{
					WValue *bId = webview_value_new_int(int64_t(nBrowserId));
					WValue *editable = webview_value_new_bool(bEditable);
					WValue *retMap = webview_value_new_map();
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "editable", editable);
					m_invokeFunc("onFocusedNodeChangeMessage", retMap);
					webview_value_unref(bId);
					webview_value_unref(editable);
					webview_value_unref(retMap);
				}
			};

			m_handler->onImeCompositionRangeChangedMessage = [=](int nBrowserId, int32_t x, int32_t y)
			{
				if (m_invokeFunc)
				{
					WValue *bId = webview_value_new_int(nBrowserId);
					WValue *retMap = webview_value_new_map();
					WValue *xValue = webview_value_new_int(x);
					WValue *yValue = webview_value_new_int(y);
					webview_value_set_string(retMap, "browserId", bId);
					webview_value_set_string(retMap, "x", xValue);
					webview_value_set_string(retMap, "y", yValue);
					m_invokeFunc("onImeCompositionRangeChangedMessage", retMap);
					webview_value_unref(bId);
					webview_value_unref(xValue);
					webview_value_unref(yValue);
					webview_value_unref(retMap);
				}
			};

			m_init = true;
		}
	}

	void WebviewPlugin::uninitCallback()
	{
		m_handler->onPaintCallback = nullptr;
		m_handler->onTooltipEvent = nullptr;
		m_handler->onCursorChangedEvent = nullptr;
		m_handler->onConsoleMessageEvent = nullptr;
		m_handler->onUrlChangedEvent = nullptr;
		m_handler->onTitleChangedEvent = nullptr;
		m_handler->onJavaScriptChannelMessage = nullptr;
		m_handler->onFocusedNodeChangeMessage = nullptr;
		m_handler->onImeCompositionRangeChangedMessage = nullptr;
		m_init = false;
	}

	void WebviewPlugin::HandleMethodCall(std::string name, WValue *values, std::function<void(int, WValue *)> result)
	{
		if (name.compare("init") == 0)
		{
			if (!isCefInitialized)
			{
				if (values != nullptr)
				{
					// Support both legacy string (userAgent) and new map options.
					WValueType vtype = webview_value_get_type(values);
					if (vtype == Webview_Value_Type_String)
					{
						userAgent = CefString(webview_value_get_string(values));
					}
					else if (vtype == Webview_Value_Type_Map)
					{
						// userAgent
						if (auto ua = webview_value_get_by_string(values, "userAgent"))
						{
							if (webview_value_get_type(ua) == Webview_Value_Type_String)
							{
								userAgent = CefString(webview_value_get_string(ua));
							}
						}
						// cachePath
						if (auto cp = webview_value_get_by_string(values, "cachePath"))
						{
							if (webview_value_get_type(cp) == Webview_Value_Type_String)
							{
								cachePath = CefString(webview_value_get_string(cp));
							}
						}
						// persist flags
						if (auto psc = webview_value_get_by_string(values, "persistSessionCookies"))
						{
							if (webview_value_get_type(psc) == Webview_Value_Type_Bool)
							{
								persistSessionCookies = webview_value_get_bool(psc);
							}
						}
						if (auto pup = webview_value_get_by_string(values, "persistUserPreferences"))
						{
							if (webview_value_get_type(pup) == Webview_Value_Type_Bool)
							{
								persistUserPreferences = webview_value_get_bool(pup);
							}
						}
						// enableGPU
						if (auto egpu = webview_value_get_by_string(values, "enableGPU"))
						{
							if (webview_value_get_type(egpu) == Webview_Value_Type_Bool)
							{
								enableGPU = webview_value_get_bool(egpu);
							}
						}
					}
				}
				// Configure optional runtime toggles
				if (app.get())
				{
					app->SetEnableGPU(enableGPU);
				}
				startCEF();
			}
			initCallback();
			result(1, nullptr);
		}
		else if (name.compare("quit") == 0)
		{
			// Release plugin-held references before shutting down CEF to avoid
			// "Object reference incorrectly held at CefShutdown" fatals.
			uninitCallback();
			// Drop renderers on the plugin side.
			if (!m_renderers.empty())
			{
				m_renderers.clear();
			}
			// Ask existing browsers to close on the CEF UI thread.
			// Close browsers synchronously on the CEF UI thread.
			RunOnCefUISync([this]()
						   {
				if (m_handler.get()) m_handler->CloseAllBrowsers(true); });
			// Finally drop the handler reference held by the plugin.
			m_handler = nullptr;
			// Now perform shutdown.
			stopCEF();
			result(1, nullptr);
		}
		else if (name.compare("create") == 0)
		{
			std::string url = webview_value_get_string(values);
			RunOnCefUI([=]()
					   { m_handler->createBrowser(url, [=](int browserId)
												  {
				std::shared_ptr<WebviewTexture> renderer = m_createTextureFunc();
				m_renderers[browserId] = renderer;
				WValue	*response = webview_value_new_list();
				webview_value_append(response, webview_value_new_int(browserId));
				webview_value_append(response, webview_value_new_int(renderer->textureId));
				result(1, response);
				webview_value_unref(response); }); });
		}
		else if (name.compare("close") == 0)
		{
			int browserId = int(webview_value_get_int(values));
			RunOnCefUI([=]()
					   { m_handler->closeBrowser(browserId); });
			if (m_renderers.find(browserId) != m_renderers.end() && m_renderers[browserId] != nullptr)
			{
				m_renderers[browserId].reset();
			}
			result(1, nullptr);
		}
		else if (name.compare("loadUrl") == 0)
		{
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			const auto url = webview_value_get_string(webview_value_get_list_value(values, 1));
			if (url != nullptr)
			{
				RunOnCefUI([=]()
						   { m_handler->loadUrl(browserId, url); });
				result(1, nullptr);
			}
		}
		else if (name.compare("setSize") == 0)
		{
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			const auto dpi = webview_value_get_double(webview_value_get_list_value(values, 1));
			const auto width = webview_value_get_double(webview_value_get_list_value(values, 2));
			const auto height = webview_value_get_double(webview_value_get_list_value(values, 3));
			RunOnCefUI([=]()
					   { m_handler->changeSize(browserId, (float)dpi, (int)std::round(width), (int)std::round(height)); });
			result(1, nullptr);
		}
		else if (name.compare("cursorClickDown") == 0 || name.compare("cursorClickUp") == 0 || name.compare("cursorMove") == 0 || name.compare("cursorDragging") == 0)
		{
			result(cursorAction(values, name), nullptr);
		}
		else if (name.compare("setScrollDelta") == 0)
		{
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			auto x = webview_value_get_int(webview_value_get_list_value(values, 1));
			auto y = webview_value_get_int(webview_value_get_list_value(values, 2));
			auto deltaX = webview_value_get_int(webview_value_get_list_value(values, 3));
			auto deltaY = webview_value_get_int(webview_value_get_list_value(values, 4));
			RunOnCefUI([=]()
					   { m_handler->sendScrollEvent(browserId, (int)x, (int)y, (int)deltaX, (int)deltaY); });
			result(1, nullptr);
		}
		else if (name.compare("goForward") == 0)
		{
			int browserId = int(webview_value_get_int(values));
			RunOnCefUI([=]()
					   { m_handler->goForward(browserId); });
			result(1, nullptr);
		}
		else if (name.compare("goBack") == 0)
		{
			int browserId = int(webview_value_get_int(values));
			RunOnCefUI([=]()
					   { m_handler->goBack(browserId); });
			result(1, nullptr);
		}
		else if (name.compare("reload") == 0)
		{
			int browserId = int(webview_value_get_int(values));
			RunOnCefUI([=]()
					   { m_handler->reload(browserId); });
			result(1, nullptr);
		}
		else if (name.compare("openDevTools") == 0)
		{
			int browserId = int(webview_value_get_int(values));
			RunOnCefUI([=]()
					   { m_handler->openDevTools(browserId); });
			result(1, nullptr);
		}
		else if (name.compare("imeSetComposition") == 0)
		{
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			const auto text = webview_value_get_string(webview_value_get_list_value(values, 1));
			RunOnCefUI([=]()
					   { m_handler->imeSetComposition(browserId, text); });
			result(1, nullptr);
		}
		else if (name.compare("imeCommitText") == 0)
		{
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			const auto text = webview_value_get_string(webview_value_get_list_value(values, 1));
			RunOnCefUI([=]()
					   { m_handler->imeCommitText(browserId, text); });
			result(1, nullptr);
		}
		else if (name.compare("setClientFocus") == 0)
		{
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			if (m_renderers.find(browserId) != m_renderers.end() && m_renderers[browserId] != nullptr)
			{
				m_renderers[browserId].get()->isFocused = webview_value_get_bool(webview_value_get_list_value(values, 1));
				RunOnCefUI([=]()
						   { m_handler->setClientFocus(browserId, m_renderers[browserId].get()->isFocused); });
			}
			result(1, nullptr);
		}
		else if (name.compare("setCookie") == 0)
		{
			const auto domain = webview_value_get_string(webview_value_get_list_value(values, 0));
			const auto key = webview_value_get_string(webview_value_get_list_value(values, 1));
			const auto value = webview_value_get_string(webview_value_get_list_value(values, 2));
			RunOnCefIO([=]()
					   { m_handler->setCookie(domain, key, value); });
			result(1, nullptr);
		}
		else if (name.compare("deleteCookie") == 0)
		{
			const auto domain = webview_value_get_string(webview_value_get_list_value(values, 0));
			const auto key = webview_value_get_string(webview_value_get_list_value(values, 1));
			RunOnCefIO([=]()
					   { m_handler->deleteCookie(domain, key); });
			result(1, nullptr);
		}
		else if (name.compare("visitAllCookies") == 0)
		{
			RunOnCefIO([=]()
					   { m_handler->visitAllCookies([=](std::map<std::string, std::map<std::string, std::string>> cookies)
													{
					WValue* retMap = webview_value_new_map();
					for (auto &cookie : cookies) {
						WValue* tempMap = webview_value_new_map();
						for (auto &c : cookie.second) {
							WValue * val = webview_value_new_string(const_cast<char *>(c.second.c_str()));
							webview_value_set_string(tempMap, c.first.c_str(), val);
							webview_value_unref(val);
						}
						webview_value_set_string(retMap, cookie.first.c_str(), tempMap);
						webview_value_unref(tempMap);
					}
					result(1, retMap);
					webview_value_unref(retMap); }); });
		}
		else if (name.compare("visitUrlCookies") == 0)
		{
			const auto domain = webview_value_get_string(webview_value_get_list_value(values, 0));
			const auto isHttpOnly = webview_value_get_bool(webview_value_get_list_value(values, 1));
			RunOnCefIO([=]()
					   { m_handler->visitUrlCookies(domain, isHttpOnly, [=](std::map<std::string, std::map<std::string, std::string>> cookies)
													{
					WValue* retMap = webview_value_new_map();
					for (auto &cookie : cookies) {
						WValue* tempMap = webview_value_new_map();
						for (auto &c : cookie.second) {
							WValue * val = webview_value_new_string(const_cast<char *>(c.second.c_str()));
							webview_value_set_string(tempMap, c.first.c_str(), val);
							webview_value_unref(val);
						}
						webview_value_set_string(retMap, cookie.first.c_str(), tempMap);
						webview_value_unref(tempMap);
					}
					result(1, retMap);
					webview_value_unref(retMap); }); });
		}
		else if (name.compare("setJavaScriptChannels") == 0)
		{
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			WValue *list = webview_value_get_list_value(values, 1);
			auto len = webview_value_get_len(list);
			std::vector<std::string> channels;
			for (size_t i = 0; i < len; i++)
			{
				auto channel = webview_value_get_string(webview_value_get_list_value(list, i));
				channels.push_back(channel);
			}
			RunOnCefUI([=]()
					   { m_handler->setJavaScriptChannels(browserId, channels); });
			result(1, nullptr);
		}
		else if (name.compare("sendJavaScriptChannelCallBack") == 0)
		{
			const auto error = webview_value_get_bool(webview_value_get_list_value(values, 0));
			const auto ret = webview_value_get_string(webview_value_get_list_value(values, 1));
			const auto callbackId = webview_value_get_string(webview_value_get_list_value(values, 2));
			const auto browserId = int(webview_value_get_int(webview_value_get_list_value(values, 3)));
			const auto frameId = webview_value_get_string(webview_value_get_list_value(values, 4));
			RunOnCefUI([=]()
					   { m_handler->sendJavaScriptChannelCallBack(error, ret, callbackId, browserId, frameId); });
			result(1, nullptr);
		}
		else if (name.compare("executeJavaScript") == 0)
		{
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			const auto code = webview_value_get_string(webview_value_get_list_value(values, 1));
			RunOnCefUI([=]()
					   { m_handler->executeJavaScript(browserId, code); });
			result(1, nullptr);
		}
		else if (name.compare("evaluateJavascript") == 0)
		{
			int browserId = int(webview_value_get_int(webview_value_get_list_value(values, 0)));
			const auto code = webview_value_get_string(webview_value_get_list_value(values, 1));
			RunOnCefUI([=]()
					   { m_handler->executeJavaScript(browserId, code, [=](CefRefPtr<CefValue> values)
													  {
                WValue* retValue;

                if (values == nullptr) {
                    result(1, nullptr);
                    return;
                }

                switch(values->GetType()) {
                    case VTYPE_BOOL:
                        retValue = webview_value_new_bool(values->GetBool());
                        break;
                    case VTYPE_DOUBLE:
                        retValue = webview_value_new_double(values->GetDouble());
                        break;
                    case VTYPE_INT:
                        retValue = webview_value_new_int(values->GetInt());
                        break;
                    case VTYPE_STRING:
                        retValue = webview_value_new_string(values->GetString().ToString().c_str());
                        break;
                    case VTYPE_LIST: {
                        retValue = webview_value_new_list();
                        CefRefPtr<CefListValue> list = values->GetList();
                        
                        if (list) {
                            for (size_t i = 0; i < list->GetSize(); ++i) {
                                CefValueType type = list->GetType(i);
                                CefRefPtr<CefValue> listItem = list->GetValue(i);

                                if (type == VTYPE_INT) {
                                    webview_value_append(retValue, webview_value_new_int(listItem->GetInt()));
                                } else if (type == VTYPE_BOOL) {
                                    webview_value_append(retValue, webview_value_new_bool(listItem->GetBool()));
                                } else if (type == VTYPE_STRING) {
                                    webview_value_append(retValue, webview_value_new_string(listItem->GetString().ToString().c_str()));
                                } else if (type == VTYPE_DOUBLE) {
                                    webview_value_append(retValue, webview_value_new_double(listItem->GetDouble()));
                                } else {
                                    continue;
                                }
                            }
                        }
                        break;
                    }
                    default:
                        // Return null as fallback
                        result(1, nullptr);
                        return;
                }

				result(1, retValue);
				webview_value_unref(retValue); }); });
		}
		else
		{
			result = 0;
		}
	}

	void WebviewPlugin::sendKeyEvent(CefKeyEvent &ev)
	{
		// Ensure key events are sent on the CEF UI thread.
		CefKeyEvent ev_copy = ev;
		RunOnCefUI([this, ev_copy]() mutable
				   { m_handler->sendKeyEvent(ev_copy); });
		if (ev.type == KEYEVENT_RAWKEYDOWN && ev.windows_key_code == 0x7B && (ev.modifiers & EVENTFLAG_CONTROL_DOWN) != 0)
		{
			for (auto render : m_renderers)
			{
				if (render.second.get()->isFocused)
				{
					RunOnCefUI([=]()
							   { m_handler->openDevTools(render.first); });
				}
			}
		}
	}

	void WebviewPlugin::setInvokeMethodFunc(std::function<void(std::string, WValue *)> func)
	{
		m_invokeFunc = func;
	}

	void WebviewPlugin::setCreateTextureFunc(std::function<std::shared_ptr<WebviewTexture>()> func)
	{
		m_createTextureFunc = func;
	}

	bool WebviewPlugin::getAnyBrowserFocused()
	{
		for (auto render : m_renderers)
		{
			if (render.second != nullptr && render.second.get()->isFocused)
			{
				return true;
			}
		}
		return false;
	}

	int WebviewPlugin::cursorAction(WValue *args, std::string name)
	{
		if (!args || webview_value_get_len(args) != 3)
		{
			return 0;
		}
		int browserId = int(webview_value_get_int(webview_value_get_list_value(args, 0)));
		int x = int(webview_value_get_int(webview_value_get_list_value(args, 1)));
		int y = int(webview_value_get_int(webview_value_get_list_value(args, 2)));
		if (!x && !y)
		{
			return 0;
		}
		if (name.compare("cursorClickDown") == 0)
		{
			RunOnCefUI([=]()
					   { m_handler->cursorClick(browserId, x, y, false); });
		}
		else if (name.compare("cursorClickUp") == 0)
		{
			RunOnCefUI([=]()
					   { m_handler->cursorClick(browserId, x, y, true); });
		}
		else if (name.compare("cursorMove") == 0)
		{
			RunOnCefUI([=]()
					   { m_handler->cursorMove(browserId, x, y, false); });
		}
		else if (name.compare("cursorDragging") == 0)
		{
			RunOnCefUI([=]()
					   { m_handler->cursorMove(browserId, x, y, true); });
		}
		return 1;
	}

	int initCEFProcesses(CefMainArgs args)
	{
		mainArgs = args;
		return initCEFProcesses();
	}

	int initCEFProcesses()
	{
#ifdef OS_MAC
		CefScopedLibraryLoader loader;
		if (!loader.LoadInMain())
		{
			printf("load cef err");
		}
#endif
		// handler = new WebviewHandler();
		app = new WebviewApp();
		return CefExecuteProcess(mainArgs, app, nullptr);
	}

	void startCEF()
	{
		CefSettings cefs;
		cefs.windowless_rendering_enabled = true;
		cefs.no_sandbox = true;
		if (!userAgent.empty())
		{
			CefString(&cefs.user_agent_product) = userAgent;
		}
		if (!cachePath.empty())
		{
			CefString(&cefs.cache_path) = cachePath;
		}
		// Encourage unique root cache path to avoid singleton collisions (warning seen at runtime).
		if (!cachePath.empty())
		{
			CefString(&cefs.root_cache_path) = cachePath;
		}
		cefs.persist_session_cookies = persistSessionCookies;
		// Some CEF builds do not expose persist_user_preferences on CefSettings.
		// If needed, this can be implemented via CefRequestContextSettings per-context.
		// locale language setting
		// CefString(&cefs.locale) = "zh-CN";
#ifdef OS_MAC
		// cef message loop handle by MainApplication on mac
		cefs.external_message_pump = true;
		// CefString(&cefs.browser_subprocess_path) = "/Library/Chaches"; //the helper Program path

#else
#ifdef __linux__
		// Use CEF's multi-threaded message loop on Linux.
		cefs.multi_threaded_message_loop = true;
#else
		// cef message run in another thread on windows
		cefs.multi_threaded_message_loop = true;
#endif
#endif
		if (CefInitialize(mainArgs, cefs, app.get(), nullptr))
		{
			isCefInitialized = true;
			// Disable atexit shutdown for Flutter apps; lifecycle managed explicitly via 'quit'.
		}
	}

	void doMessageLoopWork()
	{
		CefDoMessageLoopWork();
	}

	bool IsCefInitialized() { return isCefInitialized; }

	void SwapBufferFromBgraToRgba(void *_dest, const void *_src, int width, int height)
	{
		int32_t *dest = (int32_t *)_dest;
		int32_t *src = (int32_t *)_src;
		int32_t rgba;
		int32_t bgra;
		int length = width * height;
		for (int i = 0; i < length; i++)
		{
			bgra = src[i];
			// BGRA in hex = 0xAARRGGBB.
			rgba = (bgra & 0x00ff0000) >> 16	// Red >> Blue.
				   | (bgra & 0xff00ff00)		// Green Alpha.
				   | (bgra & 0x000000ff) << 16; // Blue >> Red.
			dest[i] = rgba;
		}
	}

	static void deferred_shutdown()
	{
		// Attempt shutdown only when requested.
		if (!s_shutdownRequested || !isCefInitialized)
			return;

		// Ask all handlers to close browsers synchronously on the UI thread.
		{
			std::lock_guard<std::mutex> lock(s_handlerMutex);
			for (auto &h : s_handlers)
			{
				if (!h.get())
					continue;
				RunOnCefUISync([h]()
							   {
					if (h.get())
						h->CloseAllBrowsers(true); });
			}
		}

		// Wait up to 2 seconds for browsers to close.
		for (int i = 0; i < 1000; ++i)
		{
			if (s_openBrowsers.load() == 0)
				break;
			std::this_thread::sleep_for(std::chrono::milliseconds(10));
		}

		// Drop all remaining handler references before CefShutdown to avoid
		// "Object reference incorrectly held at CefShutdown" fatals.
		{
			std::lock_guard<std::mutex> lock(s_handlerMutex);
			s_handlers.clear();
		}

		// Release the global application reference as well.
		app = nullptr;

		CefShutdown();
		isCefInitialized = false;
		s_shutdownRequested = false;
	}

	void stopCEF()
	{
		// Mark a shutdown request and try now; if browsers still open it will complete later.
		s_shutdownRequested = true;
		deferred_shutdown();
	}

	bool hasOpenBrowsers()
	{
		return s_openBrowsers.load() > 0;
	}

	void NotifyBrowserCreated()
	{
		s_openBrowsers.fetch_add(1);
	}

	void NotifyBrowserClosed()
	{
		int prev = s_openBrowsers.fetch_sub(1);
		if (prev <= 1)
		{
			// If this was the last browser, attempt deferred shutdown.
			deferred_shutdown();
		}
	}
}
