typedef TitleChangeCb = void Function(String title);
typedef UrlChangeCb = void Function(String url);
typedef AllCookieVisitedCb = void Function(Map<String, dynamic> cookies);
typedef UrlCookieVisitedCb = void Function(Map<String, dynamic> cookies);

class WebviewEventsListener {
  TitleChangeCb? onTitleChanged;
  UrlChangeCb? onUrlChanged;
  AllCookieVisitedCb? onAllCookiesVisited;
  UrlCookieVisitedCb? onUrlCookiesVisited;

  WebviewEventsListener(
      {this.onTitleChanged,
      this.onUrlChanged,
      this.onAllCookiesVisited,
      this.onUrlCookiesVisited});
}
