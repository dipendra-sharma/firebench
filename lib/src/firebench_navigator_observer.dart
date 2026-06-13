import 'package:flutter/widgets.dart';

import 'firebench.dart';
import 'screen_trace.dart';

/// A drop-in [NavigatorObserver] that starts and finalizes one [Firebench]
/// screen trace per route visit. Add it to `navigatorObservers` (or a
/// router's `observers`).
///
/// Each observer instance tracks only its own navigator's active screen, so a
/// separate observer can be attached to a nested navigator without the two
/// clobbering each other.
class FirebenchNavigatorObserver extends RouteObserver<PageRoute<dynamic>> {
  ScreenTrace? _current;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (!Firebench.isInitialized) return;
    _beginTracking(to: route, from: previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (!Firebench.isInitialized) return;
    _beginTracking(to: newRoute, from: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (!Firebench.isInitialized) return;
    if (_routeName(route) != _current?.routeName) return;
    _finalizeCurrent();
  }

  void _beginTracking({Route<dynamic>? to, Route<dynamic>? from}) {
    final routeName = _routeName(to);
    if (routeName == null) return;
    if (Firebench.instance.config.ignoreRoutes.contains(routeName)) return;
    _finalizeCurrent();
    _current = Firebench.instance.beginScreen(
      routeName,
      previousRouteName: _routeName(from),
    );
  }

  void _finalizeCurrent() {
    final current = _current;
    _current = null;
    if (current != null) Firebench.instance.finalizeScreen(current);
  }

  String? _routeName(Route<dynamic>? route) {
    final settings = route?.settings;
    if (settings == null) return null;
    final extractor = Firebench.instance.config.routeNameExtractor;
    return extractor?.call(settings) ?? settings.name;
  }
}
