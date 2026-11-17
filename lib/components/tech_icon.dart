import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:devspace/core/model/models.dart';

class TechIcon extends StatelessWidget {
  const TechIcon({
    super.key,
    required this.stack,
    this.size = 14.0,
  });

  final TechStack stack;
  final double size;

  static String? _assetPath(TechStack stack) {
    return switch (stack) {
      TechStack.kotlin => 'assets/icons/kotlin.png',
      TechStack.flutter => 'assets/icons/flutter.png',
      TechStack.rust => 'assets/icons/rust.png',
      TechStack.python => 'assets/icons/python.png',
      TechStack.go => 'assets/icons/go.png',
      TechStack.swift => 'assets/icons/swift.png',
      TechStack.java => 'assets/icons/java.png',
      TechStack.cpp => 'assets/icons/cpp.png',
      TechStack.node => 'assets/icons/node.png',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetPath(stack);
    if (asset != null) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _TechIconPainter(stack),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TechIconPainter(stack),
      ),
    );
  }
}

class _TechIconPainter extends CustomPainter {
  const _TechIconPainter(this.stack);
  final TechStack stack;

  @override
  void paint(Canvas canvas, Size size) {
    switch (stack) {
      case TechStack.kotlin:
        _drawKotlin(canvas, size);
        break;
      case TechStack.flutter:
        _drawFlutter(canvas, size);
        break;
      case TechStack.react:
        _drawReact(canvas, size);
        break;
      case TechStack.python:
        _drawPython(canvas, size);
        break;
      case TechStack.rust:
        _drawRust(canvas, size);
        break;
      case TechStack.go:
        _drawGo(canvas, size);
        break;
      case TechStack.node:
        _drawNode(canvas, size);
        break;
      case TechStack.swift:
        _drawSwift(canvas, size);
        break;
      case TechStack.java:
        _drawJava(canvas, size);
        break;
      case TechStack.cpp:
        _drawCpp(canvas, size);
        break;
      case TechStack.general:
        _drawGeneral(canvas, size);
        break;
    }
  }

  void _drawKotlin(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Top triangle (violet / purple)
    final topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(0, h)
      ..close();
    final topPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7F52FF), Color(0xFFC711E1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawPath(topPath, topPaint);

    // Bottom triangle (orange / coral)
    final botPath = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.5, h * 0.5)
      ..lineTo(w, h)
      ..close();
    final botPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF8E42), Color(0xFFE4485D)],
        begin: Alignment.bottomLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawPath(botPath, botPaint);

    // Middle trapezoid (magenta / pink)
    final midPath = Path()
      ..moveTo(w, 0)
      ..lineTo(w * 0.5, h * 0.5)
      ..lineTo(w, h)
      ..close();
    final midPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFC711E1), Color(0xFFE4485D)],
        begin: Alignment.topRight,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawPath(midPath, midPaint);
  }

  void _drawFlutter(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top light blue chevron
    final top = Path()
      ..moveTo(w * 0.62, 0)
      ..lineTo(w * 0.12, h * 0.50)
      ..lineTo(w * 0.38, h * 0.76)
      ..lineTo(w * 0.98, h * 0.16)
      ..close();
    canvas.drawPath(top, Paint()..color = const Color(0xFF54C5F8));

    // Bottom navy chevron
    final bot = Path()
      ..moveTo(w * 0.38, h * 0.76)
      ..lineTo(w * 0.60, h)
      ..lineTo(w * 0.98, h * 0.62)
      ..lineTo(w * 0.76, h * 0.38)
      ..close();
    canvas.drawPath(bot, Paint()..color = const Color(0xFF01579B));

    // Overlap shadow
    final overlap = Path()
      ..moveTo(w * 0.38, h * 0.76)
      ..lineTo(w * 0.76, h * 0.38)
      ..lineTo(w * 0.60, h * 0.54)
      ..close();
    canvas.drawPath(overlap, Paint()..color = const Color(0xFF02569B));
  }

  void _drawReact(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final atomPaint = Paint()
      ..color = const Color(0xFF61DAFB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    // Nucleus
    canvas.drawCircle(center, size.width * 0.14, Paint()..color = const Color(0xFF61DAFB));

    // 3 orbital rings
    final r = Rect.fromCenter(center: center, width: size.width * 0.95, height: size.height * 0.38);
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * math.pi / 3);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawOval(r, atomPaint);
      canvas.restore();
    }
  }

  void _drawPython(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top blue snake
    final bluePaint = Paint()..color = const Color(0xFF3776AB);
    final blue = Path()
      ..moveTo(w * 0.50, 0)
      ..lineTo(w * 0.20, 0)
      ..quadraticBezierTo(0, 0, 0, h * 0.25)
      ..lineTo(0, h * 0.40)
      ..lineTo(w * 0.35, h * 0.40)
      ..lineTo(w * 0.35, h * 0.60)
      ..lineTo(w * 0.70, h * 0.60)
      ..quadraticBezierTo(w * 0.85, h * 0.60, w * 0.85, h * 0.45)
      ..lineTo(w * 0.85, h * 0.25)
      ..quadraticBezierTo(w * 0.85, 0, w * 0.50, 0)
      ..close();
    canvas.drawPath(blue, bluePaint);

    // Blue eye
    canvas.drawCircle(Offset(w * 0.25, h * 0.15), w * 0.05, Paint()..color = Colors.white);

    // Bottom yellow snake
    final yellowPaint = Paint()..color = const Color(0xFFFFD43B);
    final yellow = Path()
      ..moveTo(w * 0.50, h)
      ..lineTo(w * 0.80, h)
      ..quadraticBezierTo(w, h, w, h * 0.75)
      ..lineTo(w, h * 0.60)
      ..lineTo(w * 0.65, h * 0.60)
      ..lineTo(w * 0.65, h * 0.40)
      ..lineTo(w * 0.30, h * 0.40)
      ..quadraticBezierTo(w * 0.15, h * 0.40, w * 0.15, h * 0.55)
      ..lineTo(w * 0.15, h * 0.75)
      ..quadraticBezierTo(w * 0.15, h, w * 0.50, h)
      ..close();
    canvas.drawPath(yellow, yellowPaint);

    // Yellow eye
    canvas.drawCircle(Offset(w * 0.75, h * 0.85), w * 0.05, Paint()..color = Colors.white);
  }

  void _drawRust(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = const Color(0xFFDEA584);
    final r = size.width * 0.44;

    canvas.drawCircle(center, r, paint);

    // Cog teeth
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final tooth = Path()
        ..addRect(Rect.fromCenter(
          center: center + Offset(math.cos(angle) * r, math.sin(angle) * r),
          width: size.width * 0.16,
          height: size.height * 0.16,
        ));
      canvas.drawPath(tooth, paint);
    }

    // Inner hole
    canvas.drawCircle(center, size.width * 0.22, Paint()..color = const Color(0xFF1C1E22));

    // Central letter 'R' representation
    final rPaint = Paint()
      ..color = const Color(0xFFDEA584)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(size.width * 0.44, size.height * 0.32), Offset(size.width * 0.44, size.height * 0.68), rPaint);
  }

  void _drawGo(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF00ADD8));

    // Bold 'GO' mark
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'GO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  void _drawNode(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final r = w * 0.48;

    // Hexagon
    final hex = Path();
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 6;
      final pt = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        hex.moveTo(pt.dx, pt.dy);
      } else {
        hex.lineTo(pt.dx, pt.dy);
      }
    }
    hex.close();
    canvas.drawPath(hex, Paint()..color = const Color(0xFF339933));

    // Inner 'N'
    final nPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.35, h * 0.30), Offset(w * 0.35, h * 0.70), nPaint);
    canvas.drawLine(Offset(w * 0.35, h * 0.30), Offset(w * 0.65, h * 0.70), nPaint);
    canvas.drawLine(Offset(w * 0.65, h * 0.30), Offset(w * 0.65, h * 0.70), nPaint);
  }

  void _drawSwift(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3.5));
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFA7343), Color(0xFFF05138)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(rect);
    canvas.drawRRect(r, bgPaint);

    final w = size.width;
    final h = size.height;

    // Soaring swift bird silhouette
    final bird = Path()
      ..moveTo(w * 0.85, h * 0.15)
      ..quadraticBezierTo(w * 0.50, h * 0.35, w * 0.20, h * 0.75)
      ..quadraticBezierTo(w * 0.45, h * 0.65, w * 0.65, h * 0.70)
      ..quadraticBezierTo(w * 0.40, h * 0.50, w * 0.50, h * 0.30)
      ..quadraticBezierTo(w * 0.70, h * 0.25, w * 0.85, h * 0.15)
      ..close();
    canvas.drawPath(bird, Paint()..color = Colors.white);
  }

  void _drawJava(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Steam lines (orange)
    final steam = Paint()
      ..color = const Color(0xFFED8B00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.40, h * 0.15), Offset(w * 0.40, h * 0.35), steam);
    canvas.drawLine(Offset(w * 0.60, h * 0.10), Offset(w * 0.60, h * 0.32), steam);

    // Coffee cup body (blue)
    final cup = Path()
      ..moveTo(w * 0.22, h * 0.40)
      ..lineTo(w * 0.78, h * 0.40)
      ..quadraticBezierTo(w * 0.75, h * 0.80, w * 0.50, h * 0.80)
      ..quadraticBezierTo(w * 0.25, h * 0.80, w * 0.22, h * 0.40)
      ..close();
    canvas.drawPath(cup, Paint()..color = const Color(0xFF5382A1));

    // Saucer line
    canvas.drawLine(
      Offset(w * 0.15, h * 0.88),
      Offset(w * 0.85, h * 0.88),
      Paint()
        ..color = const Color(0xFFED8B00)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCpp(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF00599C));

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'C++',
        style: TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  void _drawGeneral(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = const Color(0xFF8E99A2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // < >
    canvas.drawLine(Offset(w * 0.35, h * 0.25), Offset(w * 0.15, h * 0.50), p);
    canvas.drawLine(Offset(w * 0.15, h * 0.50), Offset(w * 0.35, h * 0.75), p);

    canvas.drawLine(Offset(w * 0.65, h * 0.25), Offset(w * 0.85, h * 0.50), p);
    canvas.drawLine(Offset(w * 0.85, h * 0.50), Offset(w * 0.65, h * 0.75), p);

    // /
    canvas.drawLine(Offset(w * 0.58, h * 0.20), Offset(w * 0.42, h * 0.80), p);
  }

  @override
  bool shouldRepaint(_TechIconPainter old) => old.stack != stack;
}
