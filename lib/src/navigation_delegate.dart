typedef NavigationDecision = bool Function(String url);

class NavigationDelegate {
  final NavigationDecision? onNavigationRequest;

  NavigationDelegate({this.onNavigationRequest});
}