import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The seven emotional states of Lumi the Sprout Spirit.
enum LumiMood {
  idleHappy,
  zenFocus,
  celebrating,
  sleeping,
  gentleNudge,
  comforting,
  wateringPlant,
}

/// Sizing variants for Lumi.
enum LumiSize {
  sm(70, 75),
  md(120, 130),
  lg(160, 175),
  hero(210, 230);

  final double width;
  final double height;
  const LumiSize(this.width, this.height);
}

/// Rich vector-rendered, interactive mascot character for Bloomly.
class LumiMascot extends StatefulWidget {
  final LumiMood mood;
  final LumiSize size;
  final bool showSpeechBubble;
  final String? speechText;
  final String? subtext;
  final bool isInteractive;
  final VoidCallback? onPet;
  final VoidCallback? onSpeechTap;

  const LumiMascot({
    super.key,
    required this.mood,
    this.size = LumiSize.md,
    this.showSpeechBubble = false,
    this.speechText,
    this.subtext,
    this.isInteractive = true,
    this.onPet,
    this.onSpeechTap,
  });

  @override
  State<LumiMascot> createState() => _LumiMascotState();
}

class _LumiMascotState extends State<LumiMascot>
    with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _petController;
  late AnimationController _sproutController;

  late Animation<double> _breatheAnim;
  late Animation<double> _sproutSwayAnim;
  late Animation<double> _petScaleAnim;
  late Animation<double> _loveFloatAnim;
  late Animation<double> _loveOpacityAnim;

  bool _isPetting = false;

  @override
  void initState() {
    super.initState();

    // 1. Gentle breathing / floating idle cycle
    _idleController = AnimationController(
      vsync: this,
      duration: _durationForMood(widget.mood),
    )..repeat(reverse: true);

    _breatheAnim = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOutSine),
    );

    // 2. Head sprout sway
    _sproutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _sproutSwayAnim = Tween<double>(begin: -0.07, end: 0.07).animate(
      CurvedAnimation(parent: _sproutController, curve: Curves.easeInOutSine),
    );

    // 3. Petting micro-interaction
    _petController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _petScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.94), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _petController, curve: Curves.easeOutBack));

    _loveFloatAnim = Tween<double>(begin: 0.0, end: -36.0).animate(
      CurvedAnimation(parent: _petController, curve: Curves.easeOutCubic),
    );

    _loveOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_petController);

    _petController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _isPetting = false);
      }
    });
  }

  Duration _durationForMood(LumiMood mood) {
    switch (mood) {
      case LumiMood.celebrating:
        return const Duration(milliseconds: 750);
      case LumiMood.zenFocus:
        return const Duration(milliseconds: 3800);
      case LumiMood.sleeping:
        return const Duration(milliseconds: 4200);
      case LumiMood.wateringPlant:
        return const Duration(milliseconds: 1800);
      case LumiMood.gentleNudge:
        return const Duration(milliseconds: 2200);
      default:
        return const Duration(milliseconds: 2600);
    }
  }

  @override
  void didUpdateWidget(covariant LumiMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _idleController.duration = _durationForMood(widget.mood);
      _idleController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _petController.dispose();
    _sproutController.dispose();
    super.dispose();
  }

  void _handlePet() {
    if (!widget.isInteractive) return;
    HapticFeedback.lightImpact();
    setState(() => _isPetting = true);
    _petController.forward(from: 0.0);
    widget.onPet?.call();
  }

  @override
  Widget build(BuildContext context) {
    final auraColor = _getAuraColor(widget.mood);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Optional Dynamic Speech Bubble
        if (widget.showSpeechBubble && widget.speechText != null) ...[
          _SpeechBubble(
            text: widget.speechText!,
            subtext: widget.subtext,
            onTap: widget.onSpeechTap,
          ),
          const SizedBox(height: 6),
        ],

        // Mascot Body with breathing & petting physics
        GestureDetector(
          onTap: _handlePet,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_idleController, _petController, _sproutController]),
            builder: (context, child) {
              final verticalOffset = widget.mood == LumiMood.celebrating
                  ? math.sin(_idleController.value * math.pi * 2) * 8.0
                  : _breatheAnim.value;

              final scale = _petController.isAnimating
                  ? _petScaleAnim.value
                  : (widget.mood == LumiMood.zenFocus
                      ? 1.0 + (_breatheAnim.value / 60.0)
                      : 1.0);

              return Transform.translate(
                offset: Offset(0, verticalOffset),
                child: Transform.scale(
                  scale: scale,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // 1. Soft Ambient Aura Glow
                      Container(
                        width: widget.size.width * 0.95,
                        height: widget.size.height * 0.95,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: auraColor,
                              blurRadius: widget.size.width * 0.45,
                              spreadRadius: widget.size.width * 0.15,
                            ),
                          ],
                        ),
                      ),

                      // 2. High-Fidelity Custom Painted Vector Lumi
                      CustomPaint(
                        size: Size(widget.size.width, widget.size.height),
                        painter: _LumiPainter(
                          mood: widget.mood,
                          sproutRotation: _sproutSwayAnim.value,
                          isPet: _isPetting,
                        ),
                      ),

                      // 3. Floating "+Love" bubble when petted
                      if (_isPetting)
                        Positioned(
                          top: _loveFloatAnim.value,
                          child: Opacity(
                            opacity: _loveOpacityAnim.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFFD1DC)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22F43F5E),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '♥',
                                    style: TextStyle(
                                      color: Color(0xFFF43F5E),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '+Love',
                                    style: TextStyle(
                                      color: Color(0xFFE11D48),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getAuraColor(LumiMood mood) {
    switch (mood) {
      case LumiMood.idleHappy:
        return const Color(0x5986EFAC); // Sage Green
      case LumiMood.zenFocus:
        return const Color(0x6BA7F3D0); // Misty Mint
      case LumiMood.celebrating:
        return const Color(0x80FDE047); // Warm Golden
      case LumiMood.sleeping:
        return const Color(0x6093C5FD); // Starlight Sky Blue
      case LumiMood.gentleNudge:
        return const Color(0x66FDBA74); // Soft Peach Amber
      case LumiMood.comforting:
        return const Color(0x6BDDD6FE); // Lavender Dusk
      case LumiMood.wateringPlant:
        return const Color(0x666EE7B7); // Emerald Sprout
    }
  }
}

/// Custom vector painter drawing Lumi's seed silhouette, facial features, accessories & sprout.
class _LumiPainter extends CustomPainter {
  final LumiMood mood;
  final double sproutRotation;
  final bool isPet;

  _LumiPainter({
    required this.mood,
    required this.sproutRotation,
    required this.isPet,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // We draw on a canonical 120x120 viewBox coordinate system and scale to size
    final double scale = size.width / 120.0;
    canvas.save();
    canvas.scale(scale, scale);

    // ── 1. Sprout Leaf or Sleeping Nightcap ─────────────────────────
    if (mood == LumiMood.sleeping) {
      _paintNightCap(canvas);
    } else {
      _paintSprout(canvas);
    }

    // ── 2. Main Seed Body (Silhouette) ──────────────────────────────
    _paintBody(canvas);

    // ── 3. Belly Accent ─────────────────────────────────────────────
    _paintBelly(canvas);

    // ── 4. Rosy Blush Cheeks ────────────────────────────────────────
    _paintCheeks(canvas);

    // ── 5. Eyes ─────────────────────────────────────────────────────
    _paintEyes(canvas);

    // ── 6. Mouth ────────────────────────────────────────────────────
    _paintMouth(canvas);

    // ── 7. Hands / Accessories (Blanket, Watering Can, Paws) ────────
    _paintAccessories(canvas);

    canvas.restore();
  }

  void _paintSprout(Canvas canvas) {
    canvas.save();
    // Rotate sprout around base point (60, 30)
    canvas.translate(60, 30);
    canvas.rotate(sproutRotation + (mood == LumiMood.celebrating ? 0.20 : 0.0));
    canvas.translate(-60, -30);

    // Stem
    final stemPaint = Paint()
      ..color = const Color(0xFF15803D)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stemPath = Path()
      ..moveTo(60, 30)
      ..cubicTo(60, 22, 62, 18, 63, 14);
    canvas.drawPath(stemPath, stemPaint);

    // Main Leaf with gradient
    const leafRect = Rect.fromLTWH(58, 6, 22, 22);
    final leafPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
      ).createShader(leafRect)
      ..style = PaintingStyle.fill;

    final leafPath = Path()
      ..moveTo(63, 14)
      ..cubicTo(64, 6, 75, 8, 76, 17)
      ..cubicTo(76, 24, 66, 22, 63, 14)
      ..close();
    canvas.drawPath(leafPath, leafPaint);

    // Secondary Sprout Shoot
    final shootPaint = Paint()
      ..color = const Color(0xFF86EFAC)
      ..style = PaintingStyle.fill;

    final shootPath = Path()
      ..moveTo(61, 20)
      ..cubicTo(56, 16, 50, 19, 52, 24)
      ..cubicTo(54, 28, 60, 25, 61, 20)
      ..close();
    canvas.drawPath(shootPath, shootPaint);

    canvas.restore();
  }

  void _paintNightCap(Canvas canvas) {
    // Cozy night sleeping cap
    const capRect = Rect.fromLTWH(42, 10, 48, 30);
    final capPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF93C5FD), Color(0xFF3B82F6)],
      ).createShader(capRect)
      ..style = PaintingStyle.fill;

    // Dome of cap on head
    final capPath = Path()
      ..moveTo(45, 28)
      ..cubicTo(45, 14, 75, 14, 75, 28)
      ..close();
    canvas.drawPath(capPath, capPaint);

    // Curving drooping tip
    final tasselPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final tasselPath = Path()
      ..moveTo(72, 20)
      ..quadraticBezierTo(86, 24, 88, 36);
    canvas.drawPath(tasselPath, tasselPaint);

    // Fluffy white pompom
    canvas.drawCircle(
      const Offset(89, 38),
      4.5,
      Paint()..color = Colors.white,
    );
  }

  void _paintBody(Canvas canvas) {
    const bodyRect = Rect.fromLTWH(26, 24, 68, 80);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF9F6F0),
          Color(0xFFEFE8DD),
        ],
        stops: [0.0, 0.75, 1.0],
      ).createShader(bodyRect)
      ..style = PaintingStyle.fill;

    // Organic cloud-seedling silhouette path
    // M60 26 C 40 26, 28 42, 28 64 C 28 85, 38 102, 60 102 C 82 102, 92 85, 92 64 C 92 42, 80 26, 60 26 Z
    final bodyPath = Path()
      ..moveTo(60, 26)
      ..cubicTo(40, 26, 28, 42, 28, 64)
      ..cubicTo(28, 85, 38, 102, 60, 102)
      ..cubicTo(82, 102, 92, 85, 92, 64)
      ..cubicTo(92, 42, 80, 26, 60, 26)
      ..close();

    canvas.drawPath(bodyPath, bodyPaint);

    // Soft outline border
    final outlinePaint = Paint()
      ..color = const Color(0xFFE5DEC9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bodyPath, outlinePaint);
  }

  void _paintBelly(Canvas canvas) {
    final bellyPaint = Paint()
      ..color = const Color(0xFFFDFBF7).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(60, 74), width: 44, height: 36),
      bellyPaint,
    );
  }

  void _paintCheeks(Canvas canvas) {
    double opacity = 0.6;
    if (mood == LumiMood.celebrating) opacity = 0.85;
    if (mood == LumiMood.sleeping) opacity = 0.4;
    if (mood == LumiMood.comforting) opacity = 0.75;

    final blushPaint = Paint()
      ..color = const Color(0xFFF472B6).withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(41, 65), width: 11, height: 6.4),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(79, 65), width: 11, height: 6.4),
      blushPaint,
    );
  }

  void _paintEyes(Canvas canvas) {
    final strokePaint = Paint()
      ..color = const Color(0xFF292524)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (mood) {
      case LumiMood.idleHappy:
      case LumiMood.wateringPlant:
        // Happy curved arcs (^^)
        final leftEye = Path()
          ..moveTo(43, 57)
          ..quadraticBezierTo(48, 52, 53, 57);
        final rightEye = Path()
          ..moveTo(67, 57)
          ..quadraticBezierTo(72, 52, 77, 57);
        canvas.drawPath(leftEye, strokePaint);
        canvas.drawPath(rightEye, strokePaint);
        break;

      case LumiMood.zenFocus:
        // Peaceful relaxed downward slits
        final peacefulPaint = Paint()
          ..color = const Color(0xFF44403C)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        final left = Path()
          ..moveTo(43, 59)
          ..quadraticBezierTo(48, 62, 53, 59);
        final right = Path()
          ..moveTo(67, 59)
          ..quadraticBezierTo(72, 62, 77, 59);
        canvas.drawPath(left, peacefulPaint);
        canvas.drawPath(right, peacefulPaint);
        break;

      case LumiMood.celebrating:
        // Big sparkling eyes with double catchlights
        final darkPaint = Paint()..color = const Color(0xFF292524);
        final shinePaint = Paint()..color = Colors.white;

        // Left eye
        canvas.drawCircle(const Offset(48, 56), 5.5, darkPaint);
        canvas.drawCircle(const Offset(46.5, 54), 2.2, shinePaint);
        canvas.drawCircle(const Offset(50, 58), 1.1, shinePaint);

        // Right eye
        canvas.drawCircle(const Offset(72, 56), 5.5, darkPaint);
        canvas.drawCircle(const Offset(70.5, 54), 2.2, shinePaint);
        canvas.drawCircle(const Offset(74, 58), 1.1, shinePaint);

        // Gold Sparkle Stars beside eyes
        _paintSparkleStar(canvas, const Offset(33, 49), const Color(0xFFFBBF24));
        _paintSparkleStar(canvas, const Offset(87, 49), const Color(0xFFFBBF24));
        break;

      case LumiMood.gentleNudge:
        // Curious: one wide eye with shine, one relaxed arc
        final darkPaint = Paint()..color = const Color(0xFF292524);
        final shinePaint = Paint()..color = Colors.white;

        canvas.drawCircle(const Offset(48, 56), 5.0, darkPaint);
        canvas.drawCircle(const Offset(46.5, 54.5), 1.8, shinePaint);

        final rightArc = Path()
          ..moveTo(68, 57)
          ..quadraticBezierTo(72, 54, 76, 57);
        canvas.drawPath(rightArc, strokePaint);
        break;

      case LumiMood.comforting:
        // Loving happy arcs + floating pink heart
        final leftHeartEye = Path()
          ..moveTo(43, 57)
          ..quadraticBezierTo(48, 53, 53, 57);
        final rightHeartEye = Path()
          ..moveTo(67, 57)
          ..quadraticBezierTo(72, 53, 77, 57);
        canvas.drawPath(leftHeartEye, strokePaint);
        canvas.drawPath(rightHeartEye, strokePaint);

        // Soft heart overhead
        _paintMiniHeart(canvas, const Offset(60, 40), const Color(0xFFFB7185));
        break;

      case LumiMood.sleeping:
        // Sleepy downward lines + floating z Z
        final sleepPaint = Paint()
          ..color = const Color(0xFF57534E)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        final left = Path()
          ..moveTo(44, 58)
          ..quadraticBezierTo(48, 61, 52, 58);
        final right = Path()
          ..moveTo(68, 58)
          ..quadraticBezierTo(72, 61, 76, 58);
        canvas.drawPath(left, sleepPaint);
        canvas.drawPath(right, sleepPaint);

        // Floating 'z' and 'Z'
        final textPainter = TextPainter(
          textDirection: TextDirection.ltr,
        );
        textPainter.text = const TextSpan(
          text: 'z',
          style: TextStyle(
            color: Color(0xFF93C5FD),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, const Offset(82, 42));

        textPainter.text = const TextSpan(
          text: 'Z',
          style: TextStyle(
            color: Color(0xFF60A5FA),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, const Offset(88, 32));
        break;
    }
  }

  void _paintSparkleStar(Canvas canvas, Offset center, Color color) {
    final starPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy - 5)
      ..lineTo(center.dx + 1.5, center.dy - 1.5)
      ..lineTo(center.dx + 5, center.dy)
      ..lineTo(center.dx + 1.5, center.dy + 1.5)
      ..lineTo(center.dx, center.dy + 5)
      ..lineTo(center.dx - 1.5, center.dy + 1.5)
      ..lineTo(center.dx - 5, center.dy)
      ..lineTo(center.dx - 1.5, center.dy - 1.5)
      ..close();

    canvas.drawPath(path, starPaint);
  }

  void _paintMiniHeart(Canvas canvas, Offset center, Color color) {
    final heartPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(center.dx, center.dy + 3)
      ..cubicTo(center.dx - 4, center.dy, center.dx - 4, center.dy - 4, center.dx, center.dy - 1.5)
      ..cubicTo(center.dx + 4, center.dy - 4, center.dx + 4, center.dy, center.dx, center.dy + 3)
      ..close();
    canvas.drawPath(path, heartPaint);
  }

  void _paintMouth(Canvas canvas) {
    final mouthStroke = Paint()
      ..color = const Color(0xFF292524)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (mood) {
      case LumiMood.idleHappy:
      case LumiMood.wateringPlant:
        final smile = Path()
          ..moveTo(56, 65)
          ..quadraticBezierTo(60, 69, 64, 65);
        canvas.drawPath(smile, mouthStroke);
        break;

      case LumiMood.celebrating:
        // Open joy mouth with tongue
        final mouthPath = Path()
          ..moveTo(55, 64)
          ..quadraticBezierTo(60, 72, 65, 64)
          ..close();
        canvas.drawPath(mouthPath, Paint()..color = const Color(0xFFE11D48));

        final tonguePath = Path()
          ..moveTo(57, 67)
          ..quadraticBezierTo(60, 70, 63, 67)
          ..close();
        canvas.drawPath(tonguePath, Paint()..color = const Color(0xFFFDA4AF));
        break;

      case LumiMood.zenFocus:
        final calmPaint = Paint()
          ..color = const Color(0xFF44403C)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final calm = Path()
          ..moveTo(57, 66)
          ..quadraticBezierTo(60, 67.5, 63, 66);
        canvas.drawPath(calm, calmPaint);
        break;

      case LumiMood.gentleNudge:
        // Cute tiny 'o'
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(60, 67), width: 5.0, height: 7.0),
          Paint()..color = const Color(0xFF44403C),
        );
        break;

      case LumiMood.comforting:
        final gentle = Path()
          ..moveTo(56, 66)
          ..quadraticBezierTo(60, 69, 64, 66);
        canvas.drawPath(gentle, mouthStroke);
        break;

      case LumiMood.sleeping:
        // Sleepy tiny dot
        canvas.drawCircle(const Offset(60, 68), 1.8, Paint()..color = const Color(0xFF57534E));
        break;
    }
  }

  void _paintAccessories(Canvas canvas) {
    if (mood == LumiMood.comforting) {
      // 1. Cozy Blanket draped over lower body
      const blanketRect = Rect.fromLTWH(30, 65, 60, 40);
      final blanketPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDD6FE), Color(0xFFC4B5FD)],
        ).createShader(blanketRect)
        ..style = PaintingStyle.fill;

      final blanketPath = Path()
        ..moveTo(36, 78)
        ..cubicTo(45, 72, 75, 72, 84, 78)
        ..cubicTo(86, 88, 82, 96, 60, 97)
        ..cubicTo(38, 96, 34, 88, 36, 78)
        ..close();
      canvas.drawPath(blanketPath, blanketPaint);
      canvas.drawPath(
        blanketPath,
        Paint()
          ..color = const Color(0xFFC4B5FD)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );

      // Cozy Mug with Heart
      final mugRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(54, 74, 12, 12),
        const Radius.circular(3),
      );
      canvas.drawRRect(mugRRect, Paint()..color = Colors.white);
      canvas.drawRRect(
        mugRRect,
        Paint()
          ..color = const Color(0xFFA78BFA)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
      _paintMiniHeart(canvas, const Offset(60, 80), const Color(0xFFF43F5E));
      return;
    }

    if (mood == LumiMood.wateringPlant) {
      // 2. Tiny Mint Watering Can + Little Sprout
      final canBody = Path()
        ..moveTo(42, 76)
        ..cubicTo(49, 72, 58, 73, 63, 78)
        ..lineTo(60, 88)
        ..lineTo(43, 87)
        ..close();
      canvas.drawPath(canBody, Paint()..color = const Color(0xFFC7E8D2));
      canvas.drawPath(
        canBody,
        Paint()
          ..color = const Color(0xFF6CB783)
          ..strokeWidth = 1.3
          ..style = PaintingStyle.stroke,
      );

      // Spout
      final spout = Path()
        ..moveTo(61, 79)
        ..lineTo(72, 75)
        ..lineTo(75, 77)
        ..lineTo(64, 83);
      canvas.drawPath(
        spout,
        Paint()
          ..color = const Color(0xFF6CB783)
          ..strokeWidth = 1.3
          ..style = PaintingStyle.stroke,
      );

      // Water droplets
      canvas.drawCircle(const Offset(77, 76), 1.3, Paint()..color = const Color(0xFF60A5FA));
      canvas.drawCircle(const Offset(80, 80), 1.1, Paint()..color = const Color(0xFF60A5FA));

      // Baby green sprout at base
      final sproutStem = Paint()
        ..color = const Color(0xFF16A34A)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(52, 89), const Offset(52, 84), sproutStem);
      canvas.drawCircle(const Offset(50, 84), 1.8, Paint()..color = const Color(0xFF4ADE80));
      canvas.drawCircle(const Offset(54, 84), 1.8, Paint()..color = const Color(0xFF4ADE80));
      return;
    }

    if (mood == LumiMood.celebrating) {
      // 3. Paws thrown joyfully in the air!
      final pawPaint = Paint()..color = const Color(0xFFEFE8DD);
      final pawStroke = Paint()
        ..color = const Color(0xFFE5DEC9)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.save();
      canvas.translate(36, 50);
      canvas.rotate(-0.35);
      canvas.drawOval(const Rect.fromLTWH(-4.5, -4, 9, 8), pawPaint);
      canvas.drawOval(const Rect.fromLTWH(-4.5, -4, 9, 8), pawStroke);
      canvas.restore();

      canvas.save();
      canvas.translate(84, 50);
      canvas.rotate(0.35);
      canvas.drawOval(const Rect.fromLTWH(-4.5, -4, 9, 8), pawPaint);
      canvas.drawOval(const Rect.fromLTWH(-4.5, -4, 9, 8), pawStroke);
      canvas.restore();
      return;
    }

    // Default: Soft marshmallow paws resting peacefully on belly
    final pawPaint = Paint()..color = const Color(0xFFF5EFEB);
    final pawStroke = Paint()
      ..color = const Color(0xFFE5DEC9)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawOval(Rect.fromCenter(center: const Offset(46, 75), width: 9, height: 8), pawPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(46, 75), width: 9, height: 8), pawStroke);

    canvas.drawOval(Rect.fromCenter(center: const Offset(74, 75), width: 9, height: 8), pawPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(74, 75), width: 9, height: 8), pawStroke);
  }

  @override
  bool shouldRepaint(covariant _LumiPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.sproutRotation != sproutRotation ||
        oldDelegate.isPet != isPet;
  }
}

/// Dynamic, polished Speech Bubble rendered above Lumi
class _SpeechBubble extends StatelessWidget {
  final String text;
  final String? subtext;
  final VoidCallback? onTap;

  const _SpeechBubble({
    required this.text,
    this.subtext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE7DFD5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF292524),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      if (subtext != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtext!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF78716C),
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.volume_up_rounded,
                  size: 15,
                  color: Color(0xFF15803D),
                ),
              ],
            ),
          ),
          // Downward pointer arrow
          CustomPaint(
            size: const Size(12, 6),
            painter: _BubbleTailPainter(),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.96)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFE7DFD5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawLine(Offset.zero, Offset(size.width / 2, size.height), borderPaint);
    canvas.drawLine(Offset(size.width / 2, size.height), Offset(size.width, 0), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
