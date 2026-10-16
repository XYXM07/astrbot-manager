import 'package:flutter/material.dart';

/// Short, finite transitions keep the glass surfaces quiet once settled.
/// Timing reference: FlClash's 100/200/300 ms tiers, implemented locally.
/// https://github.com/chen08209/FlClash/blob/main/lib/common/constant.dart
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 100);
  static const medium = Duration(milliseconds: 200);
  static const page = Duration(milliseconds: 300);
  static const curve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration duration(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// Plays once per mounted item, never on refresh or theme changes.
class MotionEntrance extends StatefulWidget {
  final Widget child;
  final int order;

  const MotionEntrance({super.key, required this.child, this.order = 0});

  @override
  State<MotionEntrance> createState() => _MotionEntranceState();
}

class _MotionEntranceState extends State<MotionEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late Animation<double> _progress;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      final delay = widget.order.clamp(0, 5) * 35;
      final total = AppMotion.page.inMilliseconds + delay;
      _controller.duration = Duration(milliseconds: total);
      _progress = _controller.drive(
        CurveTween(curve: Interval(delay / total, 1, curve: AppMotion.curve)),
      );
      _started = true;
      _controller.forward();
    }
    if (AppMotion.reduced(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _progress,
        child: AnimatedBuilder(
          animation: _progress,
          child: widget.child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 14 * (1 - _progress.value)),
            child: child,
          ),
        ),
      );
}

/// Slides the outgoing and incoming pages together without fading the backdrop.
/// Every page uses the same layout offset, including native views. Positioning
/// avoids scale, opacity and transform layers around Android platform views.
class MotionIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Set<int> nativeViewPages;

  const MotionIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.nativeViewPages = const {},
  }) : assert(index >= 0 && index < children.length);

  @override
  State<MotionIndexedStack> createState() => _MotionIndexedStackState();
}

class _MotionIndexedStackState extends State<MotionIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.page,
    value: 1,
  );
  late List<double> _from = List.filled(widget.children.length, 0);
  late List<double> _to = List.filled(widget.children.length, 0);
  late Set<int> _visible = {widget.index};

  double get _progress => Curves.easeInOutCubic.transform(_controller.value);

  void _settle() {
    _visible = {widget.index};
    _from = List.filled(widget.children.length, 0);
    _to = List.filled(widget.children.length, 0);
    _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _settle();
  }

  @override
  void didUpdateWidget(covariant MotionIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (AppMotion.reduced(context)) {
        _settle();
      } else {
        if (_controller.isCompleted) _visible = {oldWidget.index};
        final direction = widget.index > oldWidget.index ? 1.0 : -1.0;
        final progress = _progress;
        for (var i = 0; i < widget.children.length; i++) {
          _from[i] = _visible.contains(i)
              ? _from[i] + (_to[i] - _from[i]) * progress
              : direction;
          _to[i] = i == widget.index ? 0 : -direction;
        }
        _visible.add(widget.index);
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => ClipRect(
              child: Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < widget.children.length; i++)
                Positioned(
                  key: ValueKey(i),
                  left: (_from[i] + (_to[i] - _from[i]) * _progress) *
                      constraints.maxWidth,
                  width: constraints.maxWidth,
                  top: 0,
                  bottom: 0,
                  child: Offstage(
                    offstage: i != widget.index &&
                        (!_visible.contains(i) || _controller.isCompleted),
                    child: TickerMode(
                        enabled: i == widget.index,
                        child: IgnorePointer(
                            ignoring: i != widget.index ||
                                (widget.nativeViewPages.contains(i) &&
                                    _controller.isAnimating),
                            child: ExcludeSemantics(
                                excluding: i != widget.index,
                                child: ExcludeFocus(
                                  excluding: i != widget.index,
                                  child: ClipRect(
                                      child: RepaintBoundary(
                                          child: widget.children[i])),
                                )))),
                  ),
                ),
            ],
          )),
        ),
      );
}

/// Visual feedback only: the child's gesture recognizer owns the action.
class MotionPress extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const MotionPress({super.key, required this.child, this.enabled = true});

  @override
  State<MotionPress> createState() => _MotionPressState();
}

class _MotionPressState extends State<MotionPress>
    with SingleTickerProviderStateMixin {
  int? _pointer;
  Offset _origin = Offset.zero;
  int _sequence = 0;
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.curve,
    reverseCurve: Curves.easeInCubic,
  );
  late final _scale = _curve.drive(Tween<double>(begin: 1, end: 0.94));

  void _release(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    final sequence = _sequence;
    // Finish the downstroke even when down/up arrive before the next frame.
    _controller.forward().whenCompleteOrCancel(() {
      if (mounted && _pointer == null && sequence == _sequence) {
        _controller.reverse();
      }
    });
  }

  void _cancel(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _sequence++;
    _controller.reverse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _pointer = null;
      _sequence++;
      _controller.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant MotionPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pointer = null;
      _sequence++;
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _sequence++;
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (event) {
          if (widget.enabled &&
              _pointer == null &&
              !AppMotion.reduced(context)) {
            _pointer = event.pointer;
            _origin = event.position;
            _sequence++;
            _controller.forward();
          }
        },
        onPointerMove: (event) {
          if ((event.position - _origin).distance > 18) _cancel(event);
        },
        onPointerUp: _release,
        onPointerCancel: _cancel,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      );
}

/// Shares the same quick-tap feedback across custom text and chip controls.
class MotionTap extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const MotionTap({super.key, this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => MotionPress(
        enabled: onTap != null,
        child: GestureDetector(onTap: onTap, child: child),
      );
}

class MotionIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  const MotionIconButton(
      {super.key, required this.icon, this.onPressed, this.tooltip});

  @override
  Widget build(BuildContext context) => MotionPress(
        enabled: onPressed != null,
        child: IconButton(icon: icon, onPressed: onPressed, tooltip: tooltip),
      );
}

class MotionTextButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  const MotionTextButton({super.key, required this.child, this.onPressed});

  @override
  Widget build(BuildContext context) => MotionPress(
        enabled: onPressed != null,
        child: TextButton(onPressed: onPressed, child: child),
      );
}

/// Uses the existing MaterialPageRoute navigation and back behavior.
class FrostedPageTransitionsBuilder extends PageTransitionsBuilder {
  const FrostedPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    final progress = animation.drive(CurveTween(curve: AppMotion.curve));
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: progress.drive(
          Tween(begin: const Offset(0.04, 0), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }
}
