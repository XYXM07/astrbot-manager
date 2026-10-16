import 'package:flutter/widgets.dart';

/// Space for the floating dock belongs at the end of scrollable content, not
/// around the viewport: content can still paint and receive taps beside it.
class ShellLayout extends InheritedWidget {
  static const dockHeight = 64.0;
  static const dockTopGap = 8.0;
  static const dockBottomGap = 12.0;

  final double bottomClearance;

  const ShellLayout({
    super.key,
    required this.bottomClearance,
    required super.child,
  });

  static double bottomInsetOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShellLayout>()
          ?.bottomClearance ??
      MediaQuery.paddingOf(context).bottom;

  @override
  bool updateShouldNotify(ShellLayout oldWidget) =>
      bottomClearance != oldWidget.bottomClearance;
}
