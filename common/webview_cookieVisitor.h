#ifndef WEBVIEW_CEF_COOKIE_VISITOR_H_
#define WEBVIEW_CEF_COOKIE_VISITOR_H_

#include "include/cef_base.h"
#include "include/cef_cookie.h"
#include <mutex>
#include <map>

class WebviewCookieVisitor : public CefCookieVisitor
{
public:
	WebviewCookieVisitor();
	~WebviewCookieVisitor();

	//CefCookieVisitor
	bool Visit(const CefCookie& cookie, int count, int total, bool& deleteCookie) override;

	std::map<std::string, std::map<std::string, std::string>> getVisitedCookies();

    // Include the default reference counting implementation.
    IMPLEMENT_REFCOUNTING(WebviewCookieVisitor);

private:
	std::vector<CefCookie> m_vecAllCookies;
	std::mutex m_mutexCookieVector;
};

#endif  // WEBVIEW_CEF_COOKIE_VISITOR_H_