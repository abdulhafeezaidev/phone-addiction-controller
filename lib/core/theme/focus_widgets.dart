import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'focus_tokens.dart';

/// 1. FocusCard — White Rounded Card (Kidsafe Style)
/// bg pure white, radius 24, 1px subtle hairline border, soft ambient shadow
class FocusCard extends StatelessWidget {
  const FocusCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FocusTokens.cardPadding),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.gradient,
    this.isLift = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final bool isLift;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? FocusTokens.borderRadiusCard;

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? FocusTokens.surface) : null,
        gradient: gradient,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: borderColor ?? FocusTokens.divider,
          width: 1,
        ),
        boxShadow: isLift ? FocusTokens.shadowLift : FocusTokens.shadowSoft,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          splashColor: FocusTokens.primarySoft,
          highlightColor: FocusTokens.elevated,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// 2. FocusButton — Kidsafe Pill Button (Radius 999, Height 52)
/// Primary: Coral Red Gradient (#FF4757 -> #FF3B5C), Bold White Text, Button Shadow
enum FocusButtonVariant { primary, secondary, outlined, ghost, danger }

class FocusButton extends StatefulWidget {
  const FocusButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = FocusButtonVariant.primary,
    this.isPrimary = true,
    this.isDestructive = false,
    this.accentColor,
    this.isLoading = false,
    this.height = 52.0,
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final FocusButtonVariant variant;
  final bool isPrimary;
  final bool isDestructive;
  final Color? accentColor;
  final bool isLoading;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<FocusButton> createState() => _FocusButtonState();
}

class _FocusButtonState extends State<FocusButton> {
  bool _isPressed = false;

  FocusButtonVariant get _effectiveVariant {
    if (widget.isDestructive) return FocusButtonVariant.danger;
    if (!widget.isPrimary) return FocusButtonVariant.secondary;
    return widget.variant;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.borderRadius ?? FocusTokens.borderRadiusButton;
    final variant = _effectiveVariant;

    Color? bg;
    Gradient? gradient;
    Color fg;
    Border? border;
    List<BoxShadow>? shadows;

    switch (variant) {
      case FocusButtonVariant.primary:
        if (widget.accentColor != null) {
          bg = widget.accentColor;
        } else {
          gradient = FocusTokens.primaryGradient;
        }
        fg = Colors.white;
        shadows = FocusTokens.shadowPrimaryButton;
        break;
      case FocusButtonVariant.secondary:
        bg = FocusTokens.elevated;
        fg = FocusTokens.ink;
        break;
      case FocusButtonVariant.outlined:
        bg = Colors.transparent;
        fg = FocusTokens.ink;
        border = Border.all(color: FocusTokens.divider);
        break;
      case FocusButtonVariant.ghost:
        bg = Colors.transparent;
        fg = FocusTokens.inkMuted;
        break;
      case FocusButtonVariant.danger:
        bg = Colors.transparent;
        fg = FocusTokens.danger;
        break;
    }

    final scale = _isPressed ? 0.97 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: FocusTokens.motionFast,
      curve: FocusTokens.motionStandard,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: SizedBox(
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              gradient: gradient,
              borderRadius: effectiveRadius,
              border: border,
              boxShadow: shadows,
            ),
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: fg,
                shape: RoundedRectangleBorder(borderRadius: effectiveRadius),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: widget.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          widget.icon!,
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: FocusTokens.bodyStrong.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3. FocusChip — Kidsafe Filter Tab Pill (Active Red with White text vs Inactive Gray)
enum FocusChipTone { primary, secondary, accent, danger, muted }

class FocusChip extends StatelessWidget {
  const FocusChip({
    super.key,
    required this.label,
    this.tone = FocusChipTone.primary,
    this.color,
    this.showDot = false,
    this.icon,
    this.isSelected = true,
  });

  final String label;
  final FocusChipTone tone;
  final Color? color;
  final bool showDot;
  final Widget? icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    if (!isSelected) {
      bg = FocusTokens.elevated;
      fg = FocusTokens.inkMuted;
    } else if (color != null) {
      bg = color!;
      fg = Colors.white;
    } else {
      switch (tone) {
        case FocusChipTone.primary:
          bg = FocusTokens.primary;
          fg = Colors.white;
          break;
        case FocusChipTone.secondary:
          bg = FocusTokens.secondary;
          fg = Colors.white;
          break;
        case FocusChipTone.accent:
          bg = FocusTokens.accent;
          fg = Colors.white;
          break;
        case FocusChipTone.danger:
          bg = FocusTokens.danger;
          fg = Colors.white;
          break;
        case FocusChipTone.muted:
          bg = FocusTokens.elevated;
          fg = FocusTokens.inkMuted;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: FocusTokens.borderRadiusPill,
        boxShadow: isSelected && tone == FocusChipTone.primary
            ? [
                BoxShadow(
                  color: FocusTokens.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: FocusTokens.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy alias for FocusChip
class FocusStatusBadge extends StatelessWidget {
  const FocusStatusBadge({
    super.key,
    required this.label,
    this.color = FocusTokens.primary,
    this.showDot = true,
  });

  final String label;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return FocusChip(
      label: label,
      color: color,
      showDot: showDot,
    );
  }
}

/// 4. FocusProgressBar — Kidsafe rounded progress bar
class FocusProgressBar extends StatelessWidget {
  const FocusProgressBar({
    super.key,
    required this.progress,
    this.label,
    this.summary,
    this.accentColor = FocusTokens.primary,
    this.height = 8.0,
  });

  final double progress;
  final String? label;
  final String? summary;
  final Color accentColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || summary != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: FocusTokens.caption.copyWith(
                    color: FocusTokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (summary != null)
                Text(
                  summary!,
                  style: FocusTokens.caption.copyWith(color: FocusTokens.inkMuted),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            color: FocusTokens.elevated,
            borderRadius: FocusTokens.borderRadiusPill,
          ),
          child: ClipRRect(
            borderRadius: FocusTokens.borderRadiusPill,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: clamped,
                  child: Container(
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: FocusTokens.borderRadiusPill,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 5. FocusMetricCard — White Card with eyebrow, value, and icon
class FocusMetricCard extends StatelessWidget {
  const FocusMetricCard({
    super.key,
    required this.eyebrow,
    required this.icon,
    required this.value,
    required this.caption,
    this.iconColor = FocusTokens.primary,
  });

  final String eyebrow;
  final IconData icon;
  final String value;
  final String caption;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return FocusCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: FocusTokens.eyebrow,
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontFamily: FocusTokens.fontFamily,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: FocusTokens.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: FocusTokens.caption,
          ),
        ],
      ),
    );
  }
}

/// 6. FocusProgressCard — Kidsafe Usage Statistics Card
class FocusProgressCard extends StatelessWidget {
  const FocusProgressCard({
    super.key,
    required this.title,
    required this.badge,
    required this.progress,
    required this.caption,
    required this.rightValue,
    this.barColor = FocusTokens.primary,
  });

  final String title;
  final Widget badge;
  final double progress;
  final String caption;
  final String rightValue;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return FocusCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: FocusTokens.sectionTitle),
              badge,
            ],
          ),
          const SizedBox(height: 16),
          FocusProgressBar(
            progress: progress,
            accentColor: barColor,
            height: 10,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(caption, style: FocusTokens.caption),
              Text(
                rightValue,
                style: FocusTokens.caption.copyWith(
                  color: FocusTokens.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 7. FocusTaskCard — White Card with Kidsafe circular check
class FocusTaskCard extends StatelessWidget {
  const FocusTaskCard({
    super.key,
    required this.title,
    required this.meta,
    required this.isDone,
    required this.onToggle,
  });

  final String title;
  final String meta;
  final bool isDone;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: FocusTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FocusTokens.divider),
        boxShadow: FocusTokens.shadowSoft,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? FocusTokens.secondary : Colors.transparent,
                border: Border.all(
                  color: isDone ? FocusTokens.secondary : FocusTokens.borderStrong,
                  width: 1.5,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FocusTokens.bodyStrong.copyWith(
                    color: isDone ? FocusTokens.inkMuted : FocusTokens.ink,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: FocusTokens.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 8. FocusCountdownRing — Kidsafe Circular Timer Gauge
/// Thick light gray track with vibrant Coral Red progress arc
class FocusCountdownRing extends StatelessWidget {
  const FocusCountdownRing({
    super.key,
    required this.size,
    required this.progress,
    required this.time,
    this.label,
    this.sub,
    this.isActive = true,
  });

  final double size;
  final double progress;
  final String time;
  final String? label;
  final String? sub;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final innerDiameter = size - 44.0;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient soft glow
            if (isActive)
              Container(
                width: size * 0.85,
                height: size * 0.85,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: FocusTokens.primaryGlow,
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),

            // Canvas ring track & arc
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: progress.clamp(0.0, 1.0),
                trackColor: FocusTokens.elevated,
                progressColor: FocusTokens.primary,
                strokeWidth: 10.0,
              ),
            ),

            // Inner disc (pure white surface + subtle border)
            Container(
              width: innerDiameter,
              height: innerDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FocusTokens.surface,
                border: Border.all(color: FocusTokens.divider, width: 1),
                boxShadow: FocusTokens.shadowSoft,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (label != null) ...[
                    Text(
                      label!,
                      style: FocusTokens.eyebrow,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    time,
                    style: TextStyle(
                      fontFamily: FocusTokens.fontFamily,
                      fontSize: size * 0.17,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      letterSpacing: -0.5,
                      color: FocusTokens.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        sub!,
                        textAlign: TextAlign.center,
                        style: FocusTokens.caption.copyWith(
                          fontSize: 12,
                          color: FocusTokens.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (-90 degrees offset)
    if (progress > 0.001) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

/// 9. AllowedAppTile — 48-52px rounded-16 tile
class AllowedAppTile extends StatelessWidget {
  const AllowedAppTile({
    super.key,
    required this.appName,
    this.iconBytes,
    this.icon,
    this.onTap,
    this.size = 48.0,
  });

  final String appName;
  final Uint8List? iconBytes;
  final IconData? icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: FocusTokens.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FocusTokens.divider),
        ),
        alignment: Alignment.center,
        child: iconBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(iconBytes!, width: size - 16, height: size - 16),
              )
            : Icon(
                icon ?? Icons.apps_rounded,
                color: FocusTokens.primary,
                size: size * 0.48,
              ),
      ),
    );
  }
}

/// 10. FocusAppDock — Horizontal dock
class FocusAppDock extends StatelessWidget {
  const FocusAppDock({
    super.key,
    required this.children,
    this.onTapManage,
  });

  final List<Widget> children;
  final VoidCallback? onTapManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FocusTokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FocusTokens.divider),
        boxShadow: FocusTokens.shadowLift,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      ),
    );
  }
}

/// 11. Section Header
class FocusSectionHeader extends StatelessWidget {
  const FocusSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FocusTokens.screenPaddingX,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: FocusTokens.sectionTitle,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: FocusTokens.caption,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 12. FocusTile — Standard white card list tile
class FocusTile extends StatelessWidget {
  const FocusTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FocusCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: FocusTokens.screenPaddingX, vertical: 4),
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: FocusTokens.elevated,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: leading,
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FocusTokens.bodyStrong),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: FocusTokens.caption),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
