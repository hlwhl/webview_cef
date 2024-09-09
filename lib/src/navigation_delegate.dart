typedef OnNavigationDecisionCb = NavigationDecision Function(String url);

class NavigationDelegate {
  final OnNavigationDecisionCb? onNavigationRequest;

  NavigationDelegate({this.onNavigationRequest});
}

enum NavigationDecision {
  prevent,
  navigate,
}