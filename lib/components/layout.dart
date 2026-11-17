import 'package:flutter/material.dart';
import 'package:devspace/components/buttons.dart';
import 'package:devspace/components/drag_devices.dart';
import 'package:devspace/components/modifiers.dart';
import 'package:devspace/components/tech_icon.dart';
import 'package:devspace/components/text.dart';
import 'package:devspace/core/model/models.dart';
import 'package:devspace/theme/icons.dart';
import 'package:devspace/theme/theme.dart';

class SplitPane extends StatelessWidget {
  const SplitPane({
    super.key,
    required this.fraction,
    required this.onFraction,
    required this.first,
    required this.second,
    this.minFraction = 0.15,
    this.maxFraction = 0.40,
    this.minWidth = 220.0,
    this.dividerWidth = 4.0,
  });

  final double fraction;
  final ValueChanged<double> onFraction;
  final Widget first;
  final Widget second;
  final double minFraction;
  final double maxFraction;
  final double minWidth;
  final double dividerWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth.clamp(1.0, double.infinity);
        final rawWidth = totalWidth * fraction;
        final maxW = (totalWidth * maxFraction).clamp(minWidth, totalWidth);
        final firstWidth = rawWidth.clamp(minWidth, maxW);

        void onDrag(double delta) {
          final next = (firstWidth + delta) / totalWidth;
          onFraction(next.clamp(minFraction, maxFraction));
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: firstWidth,
              child: first,
            ),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Critical desktop rule: exclude trackpad so two-finger scroll does not resize dividers
                supportedDevices: kDragDevices,
                onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
                child: Container(
                  width: dividerWidth,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 1,
                      color: p.border,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class TechBadge extends StatelessWidget {
  const TechBadge({
    super.key,
    required this.label,
    required this.color,
    this.stack,
  });

  final String label;
  final Color color;
  final TechStack? stack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.35), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stack != null) ...[
            TechIcon(stack: stack!, size: 12),
            const SizedBox(width: 4),
          ],
          T(
            label,
            size: 11,
            weight: FontWeight.w600,
            color: color,
          ),
        ],
      ),
    );
  }
}

class ModalScaffold extends StatelessWidget {
  const ModalScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    this.actions = const [],
    this.width = 540,
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Center(
      child: ClickableNoRipple(
        onClick: () {},
        child: Container(
          width: width,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: p.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawBottomBorder(
                color: p.border,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: T(title, size: 14, weight: FontWeight.w600),
                      ),
                      IconBtn(
                        icon: AppIcons.close,
                        onClick: onClose,
                        size: 24,
                        iconSize: 13,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
              if (actions.isNotEmpty)
                DrawTopBorder(
                  color: p.border,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 8,
                      children: actions,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
