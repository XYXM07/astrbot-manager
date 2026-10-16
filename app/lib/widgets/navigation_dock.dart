import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../l10n.dart';
import '../theme.dart';
import 'motion.dart';
import 'shell_layout.dart';

/// A floating glass pill with a continuous spring-driven selection capsule.
/// Inspired by FlClash's navigation dock; keeps this app's glass and colors.
class FrostedNavigationDock extends StatefulWidget {
  final int index;
  final ValueChanged<int> onSelected;
  final bool blurEnabled;
  final double blurSigma;

  const FrostedNavigationDock({
    super.key,
    required this.index,
    required this.onSelected,
    this.blurEnabled = true,
    this.blurSigma = 16,
  });

  @override
  State<FrostedNavigationDock> createState() => _FrostedNavigationDockState();
}

class _FrostedNavigationDockState extends State<FrostedNavigationDock>
    with SingleTickerProviderStateMixin {
  late final _selection = AnimationController.unbounded(
    vsync: this,
    value: widget.index.toDouble(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _selection.value = widget.index.toDouble();
  }

  @override
  void didUpdateWidget(covariant FrostedNavigationDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (AppMotion.reduced(context)) {
      _selection.value = widget.index.toDouble();
    } else {
      _selection.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 360, damping: 32),
        _selection.value,
        widget.index.toDouble(),
        _selection.velocity,
      ));
    }
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = [L10n.t('仪表盘'), L10n.t('文件'), 'WebUI', L10n.t('设置')];
    const icons = [
      Icons.space_dashboard_outlined,
      Icons.folder_outlined,
      Icons.language,
      Icons.settings_outlined
    ];
    const selectedIcons = [
      Icons.space_dashboard,
      Icons.folder,
      Icons.language,
      Icons.settings
    ];
    Widget surface = Container(
      decoration: BoxDecoration(
        color: (AppColors.light ? Colors.white : const Color(0xFF1C2148))
            .withValues(alpha: AppColors.light ? 0.24 : 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.text.withValues(alpha: 0.13)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: LayoutBuilder(builder: (context, constraints) {
          final extent = constraints.maxWidth / labels.length;
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _selection,
                builder: (context, _) => PositionedDirectional(
                  start: _selection.value.clamp(0, 3) * extent,
                  top: 0,
                  bottom: 0,
                  width: extent,
                  child: DecoratedBox(
                    key: const ValueKey('dock-selection'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(colors: [
                        AppColors.violet.withValues(alpha: 0.30),
                        AppColors.cyan.withValues(alpha: 0.14),
                      ]),
                      border: Border.all(
                          color: AppColors.text.withValues(alpha: 0.10)),
                    ),
                  ),
                ),
              ),
              Row(children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                      child: Semantics(
                    selected: i == widget.index,
                    button: true,
                    label: labels[i],
                    child: Tooltip(
                      message: labels[i],
                      child: MotionPress(
                          child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => widget.onSelected(i),
                        child: ExcludeSemantics(
                            child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                                i == widget.index ? selectedIcons[i] : icons[i],
                                size: 22,
                                color: AppColors.text.withValues(
                                    alpha: i == widget.index ? 1 : 0.55)),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration:
                                  AppMotion.duration(context, AppMotion.medium),
                              style: TextStyle(
                                  fontFamily: 'sans-serif',
                                  fontSize: 10.5,
                                  fontWeight: i == widget.index
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: AppColors.text.withValues(
                                      alpha: i == widget.index ? 1 : 0.55)),
                              child: Text(labels[i],
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        )),
                      )),
                    ),
                  )),
              ]),
            ],
          );
        }),
      ),
    );
    if (widget.blurEnabled) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
        child: surface,
      );
    }
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
          20, ShellLayout.dockTopGap, 20, ShellLayout.dockBottomGap),
      child: Center(
        heightFactor: 1,
        child: SizedBox(
          width: 280,
          child: DecoratedBox(
            key: const ValueKey('navigation-dock-surface'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                    color: Colors.black
                        .withValues(alpha: AppColors.light ? 0.10 : 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8))
              ],
            ),
            child: SizedBox(
              height: ShellLayout.dockHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child:
                    Material(type: MaterialType.transparency, child: surface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
