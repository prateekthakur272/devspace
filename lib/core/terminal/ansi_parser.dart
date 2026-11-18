import 'package:flutter/material.dart';
import 'package:devspace/theme/theme.dart';

/// Lightweight, robust parser for ANSI escape sequences in terminal output.
/// Supports 16 standard ANSI colors, 256-color palette, 24-bit TrueColor RGB,
/// background highlights, bold, dim, italic, underline, and strikethrough.
class AnsiParser {
  AnsiParser._();

  static final RegExp _ansiRegex = RegExp(r'\x1B\[([0-9;]*)m');
  static final RegExp _stripNonColorAnsi = RegExp(r'\x1B\[[0-9;?]*[a-ln-zA-LN-Z]|\r');

  /// Parses [rawText] containing ANSI escape sequences into rich [TextSpan]s.
  static List<TextSpan> parse(String rawText, Pal p, {double fontSize = 12.0}) {
    if (rawText.isEmpty) return const [];

    // Strip non-color control sequences (like cursor positioning or clearing)
    final text = rawText.replaceAll(_stripNonColorAnsi, '');

    final defaultStyle = TextStyle(
      fontFamily: 'Menlo, Monaco, "Courier New", monospace',
      fontSize: fontSize,
      height: 1.45,
      color: p.text,
    );

    final spans = <TextSpan>[];
    final matches = _ansiRegex.allMatches(text);

    if (matches.isEmpty) {
      return _smartColorizePlainText(text, defaultStyle, p);
    }

    int lastIndex = 0;
    Color currentColor = p.text;
    Color? currentBgColor;
    FontWeight currentWeight = FontWeight.normal;
    FontStyle currentFontStyle = FontStyle.normal;
    TextDecoration currentDecoration = TextDecoration.none;
    bool isDim = false;
    bool isInverse = false;

    for (final match in matches) {
      if (match.start > lastIndex) {
        final segment = text.substring(lastIndex, match.start);
        spans.add(_createSpan(
          segment: segment,
          defaultStyle: defaultStyle,
          fgColor: currentColor,
          bgColor: currentBgColor,
          weight: currentWeight,
          fontStyle: currentFontStyle,
          decoration: currentDecoration,
          isDim: isDim,
          isInverse: isInverse,
          p: p,
        ));
      }

      final rawCodes = match.group(1)?.split(';') ?? [];
      final codes = rawCodes.map((s) => int.tryParse(s.trim())).toList();

      if (codes.isEmpty || codes.contains(0) || rawCodes.contains('')) {
        currentColor = p.text;
        currentBgColor = null;
        currentWeight = FontWeight.normal;
        currentFontStyle = FontStyle.normal;
        currentDecoration = TextDecoration.none;
        isDim = false;
        isInverse = false;
      }

      int i = 0;
      while (i < codes.length) {
        final code = codes[i];
        if (code == null) {
          i++;
          continue;
        }

        switch (code) {
          case 0:
            currentColor = p.text;
            currentBgColor = null;
            currentWeight = FontWeight.normal;
            currentFontStyle = FontStyle.normal;
            currentDecoration = TextDecoration.none;
            isDim = false;
            isInverse = false;
            break;
          case 1:
            currentWeight = FontWeight.bold;
            break;
          case 2:
            isDim = true;
            break;
          case 3:
            currentFontStyle = FontStyle.italic;
            break;
          case 4:
            currentDecoration = TextDecoration.underline;
            break;
          case 7:
            isInverse = true;
            break;
          case 9:
            currentDecoration = TextDecoration.lineThrough;
            break;
          case 22:
            currentWeight = FontWeight.normal;
            isDim = false;
            break;
          case 23:
            currentFontStyle = FontStyle.normal;
            break;
          case 24:
            currentDecoration = TextDecoration.none;
            break;
          case 27:
            isInverse = false;
            break;
          case 29:
            currentDecoration = TextDecoration.none;
            break;

          // Standard foreground colors (30-37, 39)
          case 30:
            currentColor = p.dark ? const Color(0xFF484F58) : const Color(0xFF24292F);
            break;
          case 31:
            currentColor = p.err;
            break;
          case 32:
            currentColor = p.ok;
            break;
          case 33:
            currentColor = p.warn;
            break;
          case 34:
            currentColor = p.accent;
            break;
          case 35:
            currentColor = const Color(0xFFBC8CFF);
            break;
          case 36:
            currentColor = const Color(0xFF39C5BB);
            break;
          case 37:
            currentColor = p.dark ? Colors.white70 : Colors.black87;
            break;
          case 38:
            // Extended 256 colors or 24-bit TrueColor RGB
            if (i + 2 < codes.length && codes[i + 1] == 5) {
              final colorIdx = codes[i + 2];
              if (colorIdx != null) currentColor = parse256Color(colorIdx, p);
              i += 2;
            } else if (i + 4 < codes.length && codes[i + 1] == 2) {
              final r = codes[i + 2] ?? 0;
              final g = codes[i + 3] ?? 0;
              final b = codes[i + 4] ?? 0;
              currentColor = Color.fromARGB(255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
              i += 4;
            }
            break;
          case 39:
            currentColor = p.text;
            break;

          // Standard background colors (40-47, 49)
          case 40:
            currentBgColor = p.dark ? const Color(0xFF16181D) : const Color(0xFF24292F);
            break;
          case 41:
            currentBgColor = p.err.withOpacity(0.22);
            break;
          case 42:
            currentBgColor = p.ok.withOpacity(0.22);
            break;
          case 43:
            currentBgColor = p.warn.withOpacity(0.22);
            break;
          case 44:
            currentBgColor = p.accent.withOpacity(0.22);
            break;
          case 45:
            currentBgColor = const Color(0xFFBC8CFF).withOpacity(0.22);
            break;
          case 46:
            currentBgColor = const Color(0xFF39C5BB).withOpacity(0.22);
            break;
          case 47:
            currentBgColor = p.dark ? Colors.white24 : Colors.black12;
            break;
          case 48:
            // Extended background colors (256 or TrueColor)
            if (i + 2 < codes.length && codes[i + 1] == 5) {
              final colorIdx = codes[i + 2];
              if (colorIdx != null) currentBgColor = parse256Color(colorIdx, p);
              i += 2;
            } else if (i + 4 < codes.length && codes[i + 1] == 2) {
              final r = codes[i + 2] ?? 0;
              final g = codes[i + 3] ?? 0;
              final b = codes[i + 4] ?? 0;
              currentBgColor = Color.fromARGB(255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
              i += 4;
            }
            break;
          case 49:
            currentBgColor = null;
            break;

          // High intensity foreground colors (90-97)
          case 90:
            currentColor = p.muted;
            break;
          case 91:
            currentColor = const Color(0xFFFF7B72);
            break;
          case 92:
            currentColor = const Color(0xFF7EE787);
            break;
          case 93:
            currentColor = const Color(0xFFFFA657);
            break;
          case 94:
            currentColor = const Color(0xFF79C0FF);
            break;
          case 95:
            currentColor = const Color(0xFFD2A8FF);
            break;
          case 96:
            currentColor = const Color(0xFFA5D6FF);
            break;
          case 97:
            currentColor = Colors.white;
            break;

          // High intensity background colors (100-107)
          case 100:
            currentBgColor = p.muted.withOpacity(0.3);
            break;
          case 101:
            currentBgColor = const Color(0xFFFF7B72).withOpacity(0.25);
            break;
          case 102:
            currentBgColor = const Color(0xFF7EE787).withOpacity(0.25);
            break;
          case 103:
            currentBgColor = const Color(0xFFFFA657).withOpacity(0.25);
            break;
          case 104:
            currentBgColor = const Color(0xFF79C0FF).withOpacity(0.25);
            break;
          case 105:
            currentBgColor = const Color(0xFFD2A8FF).withOpacity(0.25);
            break;
          case 106:
            currentBgColor = const Color(0xFFA5D6FF).withOpacity(0.25);
            break;
          case 107:
            currentBgColor = Colors.white30;
            break;
        }
        i++;
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final segment = text.substring(lastIndex);
      spans.add(_createSpan(
        segment: segment,
        defaultStyle: defaultStyle,
        fgColor: currentColor,
        bgColor: currentBgColor,
        weight: currentWeight,
        fontStyle: currentFontStyle,
        decoration: currentDecoration,
        isDim: isDim,
        isInverse: isInverse,
        p: p,
      ));
    }

    return spans;
  }

  static TextSpan _createSpan({
    required String segment,
    required TextStyle defaultStyle,
    required Color fgColor,
    required Color? bgColor,
    required FontWeight weight,
    required FontStyle fontStyle,
    required TextDecoration decoration,
    required bool isDim,
    required bool isInverse,
    required Pal p,
  }) {
    Color effectiveFg = fgColor;
    Color? effectiveBg = bgColor;

    if (isInverse) {
      final temp = effectiveFg;
      effectiveFg = effectiveBg ?? (p.dark ? Colors.black : Colors.white);
      effectiveBg = temp;
    }

    if (isDim) {
      effectiveFg = effectiveFg.withOpacity(0.55);
    }

    return TextSpan(
      text: segment,
      style: defaultStyle.copyWith(
        color: effectiveFg,
        backgroundColor: effectiveBg,
        fontWeight: weight,
        fontStyle: fontStyle,
        decoration: decoration,
      ),
    );
  }

  /// Converts standard 256-color palette index to a [Color].
  static Color parse256Color(int index, Pal p) {
    if (index < 0 || index > 255) return p.text;
    if (index == 0) return p.dark ? const Color(0xFF1E222A) : const Color(0xFF24292F);
    if (index == 1) return p.err;
    if (index == 2) return p.ok;
    if (index == 3) return p.warn;
    if (index == 4) return p.accent;
    if (index == 5) return const Color(0xFFBC8CFF);
    if (index == 6) return const Color(0xFF39C5BB);
    if (index == 7) return p.dark ? Colors.white70 : Colors.black87;
    if (index == 8) return p.muted;
    if (index == 9) return const Color(0xFFFF7B72);
    if (index == 10) return const Color(0xFF7EE787);
    if (index == 11) return const Color(0xFFFFA657);
    if (index == 12) return const Color(0xFF79C0FF);
    if (index == 13) return const Color(0xFFD2A8FF);
    if (index == 14) return const Color(0xFFA5D6FF);
    if (index == 15) return Colors.white;

    // 16..231: 6x6x6 color cube
    if (index <= 231) {
      final cubeIndex = index - 16;
      final rIndex = cubeIndex ~/ 36;
      final gIndex = (cubeIndex % 36) ~/ 6;
      final bIndex = cubeIndex % 6;
      final r = rIndex == 0 ? 0 : 55 + rIndex * 40;
      final g = gIndex == 0 ? 0 : 55 + gIndex * 40;
      final b = bIndex == 0 ? 0 : 55 + bIndex * 40;
      return Color.fromARGB(255, r, g, b);
    }

    // 232..255: grayscale ramp
    final gray = 8 + (index - 232) * 10;
    return Color.fromARGB(255, gray, gray, gray);
  }

  static final RegExp _syntaxRegex = RegExp(
    r'(https?://[^\s]+|localhost:[0-9]+)' // 1: URL
    r'|(\b(?:PASS|PASSED|SUCCESS|OK|DONE|Passed)\b|✓|\[OK\])' // 2: Success
    r'|(\b(?:FAIL|FAILED|ERROR|FATAL|EXCEPTION|Failed)\b|✗|\[ERR\])' // 3: Error
    r'|(\b(?:WARN|WARNING|CAUTION|Warning)\b|⚠|\[WARN\])' // 4: Warning
    r'|(\b(?:modified|new file|deleted|renamed|both modified):)' // 5: Git status label
    r'|(\b(?:On branch|Your branch is up to date with|Changes to be committed|Changes not staged for commit|Untracked files):\b)' // 6: Git section header
    r'|([a-zA-Z0-9_\-\./]+\.[a-zA-Z0-9_]+:\d+(?::\d+)?)' // 7: File path with line/col
    r'|(\b(?:true|false|null)\b)' // 8: Booleans / null
    r'|(\b\d+(?:\.\d+)?(?:ms|s|m|MB|KB|GB|B|%)\b)' // 9: Measurements & timings
    r'|(\s--?[a-zA-Z0-9\-]+)' // 10: CLI flags
  );

  /// Formats plain text outputs using intelligent developer syntax highlighting.
  static List<TextSpan> _smartColorizePlainText(
    String text,
    TextStyle defaultStyle,
    Pal p,
  ) {
    if (text.isEmpty) return const [];

    // 1. Git diff addition line: starts with "+" (and not "+++")
    if (text.startsWith('+') && !text.startsWith('+++')) {
      return [
        TextSpan(
          text: text,
          style: defaultStyle.copyWith(
            color: p.ok,
            backgroundColor: p.ok.withOpacity(0.12),
            fontWeight: FontWeight.w500,
          ),
        ),
      ];
    }

    // 2. Git diff deletion line: starts with "-" (and not "---")
    if (text.startsWith('-') && !text.startsWith('---')) {
      return [
        TextSpan(
          text: text,
          style: defaultStyle.copyWith(
            color: p.err,
            backgroundColor: p.err.withOpacity(0.12),
            fontWeight: FontWeight.w500,
          ),
        ),
      ];
    }

    // 3. Diff hunk header: @@ -1,4 +1,5 @@
    if (text.startsWith('@@') && text.contains('@@', 2)) {
      return [
        TextSpan(
          text: text,
          style: defaultStyle.copyWith(
            color: const Color(0xFF38BDF8),
            backgroundColor: const Color(0xFF38BDF8).withOpacity(0.1),
            fontWeight: FontWeight.w600,
          ),
        ),
      ];
    }

    // 4. Section dividers / ASCII table lines
    if (RegExp(r'^[-=─═─]{4,}$').hasMatch(text.trim())) {
      return [
        TextSpan(
          text: text,
          style: defaultStyle.copyWith(
            color: p.muted.withOpacity(0.4),
          ),
        ),
      ];
    }

    // 5. Token-based formatting (URLs, keywords, file paths, numbers, flags)
    final matches = _syntaxRegex.allMatches(text);
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: defaultStyle)];
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: defaultStyle,
        ));
      }

      final matchedText = match.group(0)!;

      // Group 1: URL
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: matchedText,
          style: defaultStyle.copyWith(
            color: const Color(0xFF60A5FA),
            decoration: TextDecoration.underline,
          ),
        ));
      }
      // Group 2: Success
      else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: matchedText,
          style: defaultStyle.copyWith(
            color: p.ok,
            fontWeight: FontWeight.bold,
          ),
        ));
      }
      // Group 3: Error
      else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: matchedText,
          style: defaultStyle.copyWith(
            color: p.err,
            fontWeight: FontWeight.bold,
          ),
        ));
      }
      // Group 4: Warning
      else if (match.group(4) != null) {
        spans.add(TextSpan(
          text: matchedText,
          style: defaultStyle.copyWith(
            color: p.warn,
            fontWeight: FontWeight.bold,
          ),
        ));
      }
      // Group 5: Git status label
      else if (match.group(5) != null) {
        final color = matchedText.contains('modified')
            ? p.warn
            : (matchedText.contains('deleted') ? p.err : p.ok);
        spans.add(TextSpan(
          text: matchedText,
          style: defaultStyle.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ));
      }
      // Group 6: Git section header
      else if (match.group(6) != null) {
        spans.add(TextSpan(
          text: matchedText,
          style: defaultStyle.copyWith(
            color: const Color(0xFFC084FC),
            fontWeight: FontWeight.w700,
          ),
        ));
      }
      // Group 7: File path with line number (lib/main.dart:45:12)
      else if (match.group(7) != null) {
        final colonIdx = matchedText.indexOf(':');
        if (colonIdx != -1) {
          final filePath = matchedText.substring(0, colonIdx);
          final lineInfo = matchedText.substring(colonIdx);
          spans.add(TextSpan(
            text: filePath,
            style: defaultStyle.copyWith(
              color: const Color(0xFF38BDF8),
              fontWeight: FontWeight.w500,
            ),
          ));
          spans.add(TextSpan(
            text: lineInfo,
            style: defaultStyle.copyWith(
              color: p.warn,
              fontWeight: FontWeight.w600,
            ),
          ));
        } else {
          spans.add(TextSpan(
            text: matchedText,
            style: defaultStyle.copyWith(
              color: const Color(0xFF38BDF8),
              fontWeight: FontWeight.w500,
            ),
          ));
        }
      }
      // Group 8: Booleans / null
      else if (match.group(8) != null) {
        spans.add(TextSpan(
          text: matchedText,
          style: defaultStyle.copyWith(
            color: const Color(0xFFBC8CFF),
            fontWeight: FontWeight.w600,
          ),
        ));
      }
      // Group 9: Measurements & timings
      else if (match.group(9) != null) {
        spans.add(TextSpan(
          text: matchedText,
          style: defaultStyle.copyWith(
            color: const Color(0xFF2DD4BF),
            fontWeight: FontWeight.w500,
          ),
        ));
      }
      // Group 10: CLI flags
      else if (match.group(10) != null) {
        spans.add(TextSpan(
          text: matchedText,
          style: defaultStyle.copyWith(
            color: const Color(0xFFC084FC),
            fontWeight: FontWeight.w500,
          ),
        ));
      } else {
        spans.add(TextSpan(text: matchedText, style: defaultStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: defaultStyle,
      ));
    }

    return spans;
  }
}
