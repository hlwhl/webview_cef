typedef TitleChangeCb = void Function(String title);
typedef UrlChangeCb = void Function(String url);

class WebviewEventsListener {
  TitleChangeCb? onTitleChanged;
  UrlChangeCb? onUrlChanged;

  WebviewEventsListener({
    this.onTitleChanged,
    this.onUrlChanged,
  });
}
