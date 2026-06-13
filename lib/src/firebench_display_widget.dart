import 'package:flutter/widgets.dart';

import 'firebench.dart';

/// Wraps a screen to manage its time-to-full-display report. When [child] is a
/// [StatelessWidget] the screen is reported as fully displayed immediately;
/// otherwise descendants can call [FirebenchDisplay.reportFullyDisplayed] via
/// [of].
class FirebenchDisplayWidget extends StatefulWidget {
  /// Wraps [child] with display tracking for the active screen.
  const FirebenchDisplayWidget({super.key, required this.child});

  /// The wrapped screen content.
  final Widget child;

  /// Returns the [FirebenchDisplay] for the nearest enclosing
  /// [FirebenchDisplayWidget], or `null` when there is none.
  static FirebenchDisplay? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_FirebenchDisplayScope>()
        ?.display;
  }

  @override
  State<FirebenchDisplayWidget> createState() => _FirebenchDisplayWidgetState();
}

class _FirebenchDisplayWidgetState extends State<FirebenchDisplayWidget> {
  FirebenchDisplay? _display;

  @override
  void initState() {
    super.initState();
    if (!Firebench.isInitialized) return;
    _display = Firebench.instance.currentDisplay();
    if (widget.child is StatelessWidget) _display?.reportFullyDisplayed();
  }

  @override
  Widget build(BuildContext context) {
    return _FirebenchDisplayScope(display: _display, child: widget.child);
  }
}

class _FirebenchDisplayScope extends InheritedWidget {
  const _FirebenchDisplayScope({required this.display, required super.child});

  final FirebenchDisplay? display;

  @override
  bool updateShouldNotify(_FirebenchDisplayScope oldWidget) =>
      display != oldWidget.display;
}
