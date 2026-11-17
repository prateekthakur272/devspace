import 'package:flutter/material.dart';
import 'package:devspace/core/model/models.dart';

class IdeIcon extends StatelessWidget {
  const IdeIcon({
    super.key,
    required this.editor,
    this.size = 14.0,
  });

  final EditorType editor;
  final double size;

  static String? _assetPath(EditorType editor) {
    return switch (editor) {
      EditorType.xcode => 'assets/icons/xcode.png',
      EditorType.vscode => 'assets/icons/vscode.png',
      EditorType.androidStudio => 'assets/icons/android_studio.png',
      EditorType.intellij => 'assets/icons/intellij.png',
      EditorType.cursor => 'assets/icons/cursor.png',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetPath(editor);
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
            painter: _IdeIconPainter(editor),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IdeIconPainter(editor),
      ),
    );
  }
}

class _IdeIconPainter extends CustomPainter {
  const _IdeIconPainter(this.editor);
  final EditorType editor;

  @override
  void paint(Canvas canvas, Size size) {
    switch (editor) {
      case EditorType.vscode:
        _drawVsCode(canvas, size);
        break;
      case EditorType.cursor:
        _drawCursor(canvas, size);
        break;
      case EditorType.vscodium:
        _drawVscodium(canvas, size);
        break;
      case EditorType.androidStudio:
        _drawAndroidStudio(canvas, size);
        break;
      case EditorType.intellij:
        _drawIntellij(canvas, size);
        break;
      case EditorType.xcode:
        _drawXcode(canvas, size);
        break;
      case EditorType.zed:
        _drawZed(canvas, size);
        break;
      case EditorType.sublime:
        _drawSublime(canvas, size);
        break;
      case EditorType.webstorm:
        _drawWebStorm(canvas, size);
        break;
      case EditorType.pycharm:
        _drawPyCharm(canvas, size);
        break;
      case EditorType.rustrover:
        _drawRustRover(canvas, size);
        break;
      case EditorType.goland:
        _drawGoLand(canvas, size);
        break;
      case EditorType.clion:
        _drawCLion(canvas, size);
        break;
      case EditorType.fleet:
        _drawFleet(canvas, size);
        break;
      case EditorType.terminal:
        _drawTerminal(canvas, size);
        break;
      case EditorType.custom:
        _drawCustom(canvas, size);
        break;
    }
  }

  void _drawVsCode(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Right wing (dark navy)
    final rightWing = Path()
      ..moveTo(w * 0.72, h * 0.10)
      ..lineTo(w * 0.98, h * 0.22)
      ..lineTo(w * 0.98, h * 0.78)
      ..lineTo(w * 0.72, h * 0.90)
      ..close();
    canvas.drawPath(rightWing, Paint()..color = const Color(0xFF0065A9));

    // Upper fold (medium blue)
    final upperFold = Path()
      ..moveTo(w * 0.72, h * 0.10)
      ..lineTo(w * 0.28, h * 0.42)
      ..lineTo(w * 0.04, h * 0.28)
      ..lineTo(w * 0.72, h * 0.90)
      ..close();
    canvas.drawPath(upperFold, Paint()..color = const Color(0xFF007ACC));

    // Front main ribbon (bright cyan blue)
    final frontRibbon = Path()
      ..moveTo(w * 0.04, h * 0.72)
      ..lineTo(w * 0.28, h * 0.58)
      ..lineTo(w * 0.72, h * 0.90)
      ..lineTo(w * 0.98, h * 0.78)
      ..lineTo(w * 0.35, h * 0.35)
      ..close();
    canvas.drawPath(frontRibbon, Paint()..color = const Color(0xFF1F8AD2));
  }

  void _drawCursor(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF18181B));

    // 3D Isometric cube / prism arrow mark
    final w = size.width;
    final h = size.height;
    final prism = Path()
      ..moveTo(w * 0.50, h * 0.20)
      ..lineTo(w * 0.80, h * 0.38)
      ..lineTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.20, h * 0.38)
      ..close();
    canvas.drawPath(prism, Paint()..color = Colors.white);

    final leftFace = Path()
      ..moveTo(w * 0.20, h * 0.38)
      ..lineTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.50, h * 0.82)
      ..lineTo(w * 0.20, h * 0.64)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = const Color(0xFFA1A1AA));

    final rightFace = Path()
      ..moveTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.80, h * 0.38)
      ..lineTo(w * 0.80, h * 0.64)
      ..lineTo(w * 0.50, h * 0.82)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = const Color(0xFFD4D4D8));
  }

  void _drawVscodium(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Right wing
    final right = Path()
      ..moveTo(w * 0.72, h * 0.10)
      ..lineTo(w * 0.98, h * 0.22)
      ..lineTo(w * 0.98, h * 0.78)
      ..lineTo(w * 0.72, h * 0.90)
      ..close();
    canvas.drawPath(right, Paint()..color = const Color(0xFF1E88E5));

    final front = Path()
      ..moveTo(w * 0.04, h * 0.72)
      ..lineTo(w * 0.28, h * 0.58)
      ..lineTo(w * 0.72, h * 0.90)
      ..lineTo(w * 0.98, h * 0.78)
      ..lineTo(w * 0.35, h * 0.35)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF42A5F5));
  }

  void _drawAndroidStudio(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3.5));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF3DDC84));

    final w = size.width;
    final h = size.height;

    // Head semi-circle
    final head = Path()
      ..addArc(
        Rect.fromCenter(center: Offset(w * 0.50, h * 0.55), width: w * 0.56, height: h * 0.56),
        3.14159,
        3.14159,
      );
    canvas.drawPath(head, Paint()..color = const Color(0xFF1E293B));

    // Antennas
    final antPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.38, h * 0.40), Offset(w * 0.28, h * 0.22), antPaint);
    canvas.drawLine(Offset(w * 0.62, h * 0.40), Offset(w * 0.72, h * 0.22), antPaint);

    // Eyes
    canvas.drawCircle(Offset(w * 0.40, h * 0.45), w * 0.04, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.60, h * 0.45), w * 0.04, Paint()..color = Colors.white);
  }

  void _drawIntellij(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3.5));
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFE2857), Color(0xFF000000), Color(0xFF087CFA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(r, bgPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'IJ',
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

  void _drawXcode(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3.5));
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF147EFB), Color(0xFF1B59C9)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRRect(r, bgPaint);

    final w = size.width;
    final h = size.height;

    // Hammer cross
    final toolPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.25, h * 0.75), Offset(w * 0.75, h * 0.25), toolPaint);
    canvas.drawLine(Offset(w * 0.25, h * 0.25), Offset(w * 0.75, h * 0.75), toolPaint);

    // Hammer head
    canvas.drawRect(
      Rect.fromCenter(center: Offset(w * 0.72, h * 0.28), width: w * 0.24, height: h * 0.12),
      Paint()..color = Colors.white,
    );
  }

  void _drawZed(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF18181B));

    final w = size.width;
    final h = size.height;

    // Stylized neon 'Z' ribbon
    final zPath = Path()
      ..moveTo(w * 0.25, h * 0.25)
      ..lineTo(w * 0.75, h * 0.25)
      ..lineTo(w * 0.25, h * 0.75)
      ..lineTo(w * 0.75, h * 0.75);

    canvas.drawPath(
      zPath,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawSublime(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF272822));

    final w = size.width;
    final h = size.height;

    // 3 overlapping 3D coral slabs
    final slab1 = Path()
      ..moveTo(w * 0.20, h * 0.35)
      ..lineTo(w * 0.80, h * 0.25)
      ..lineTo(w * 0.80, h * 0.40)
      ..lineTo(w * 0.20, h * 0.50)
      ..close();
    canvas.drawPath(slab1, Paint()..color = const Color(0xFFFF9800));

    final slab2 = Path()
      ..moveTo(w * 0.20, h * 0.55)
      ..lineTo(w * 0.80, h * 0.45)
      ..lineTo(w * 0.80, h * 0.60)
      ..lineTo(w * 0.20, h * 0.70)
      ..close();
    canvas.drawPath(slab2, Paint()..color = const Color(0xFFFF5722));

    final slab3 = Path()
      ..moveTo(w * 0.20, h * 0.75)
      ..lineTo(w * 0.80, h * 0.65)
      ..lineTo(w * 0.80, h * 0.80)
      ..lineTo(w * 0.20, h * 0.90)
      ..close();
    canvas.drawPath(slab3, Paint()..color = const Color(0xFFE91E63));
  }

  void _drawWebStorm(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3.5));
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00CDCD), Color(0xFF000000), Color(0xFF21D789)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(r, bgPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'WS',
        style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  void _drawPyCharm(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3.5));
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF21D789), Color(0xFF000000), Color(0xFFFCF84A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(r, bgPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'PC',
        style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  void _drawRustRover(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3.5));
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF74C00), Color(0xFF000000), Color(0xFFFF8E42)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(r, bgPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'RR',
        style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  void _drawGoLand(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3.5));
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00ADD8), Color(0xFF000000), Color(0xFF21D789)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(r, bgPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'GO',
        style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  void _drawCLion(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3.5));
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF21D789), Color(0xFF000000), Color(0xFF0091FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(r, bgPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'CL',
        style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  void _drawFleet(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3.5));
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7F52FF), Color(0xFF00E5FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(r, bgPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'FL',
        style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  void _drawTerminal(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF1E293B));

    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Prompt > _
    canvas.drawLine(Offset(w * 0.25, h * 0.35), Offset(w * 0.45, h * 0.50), p);
    canvas.drawLine(Offset(w * 0.45, h * 0.50), Offset(w * 0.25, h * 0.65), p);
    canvas.drawLine(Offset(w * 0.55, h * 0.65), Offset(w * 0.75, h * 0.65), p);
  }

  void _drawCustom(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF334155));

    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(w * 0.35, h * 0.35), Offset(w * 0.20, h * 0.50), p);
    canvas.drawLine(Offset(w * 0.20, h * 0.50), Offset(w * 0.35, h * 0.65), p);

    canvas.drawLine(Offset(w * 0.65, h * 0.35), Offset(w * 0.80, h * 0.50), p);
    canvas.drawLine(Offset(w * 0.80, h * 0.50), Offset(w * 0.65, h * 0.65), p);
  }

  @override
  bool shouldRepaint(_IdeIconPainter old) => old.editor != editor;
}
