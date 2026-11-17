import 'package:flutter/material.dart';

class NoteColorTheme {
  final String label;
  final Color accent;
  final Color darkSurface;
  final Color lightSurface;

  const NoteColorTheme({
    required this.label,
    required this.accent,
    required this.darkSurface,
    required this.lightSurface,
  });

  Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
}

const List<NoteColorTheme> kNoteColorThemes = [
  NoteColorTheme(
    label: 'Purple',
    accent: Color(0xFF8B5CF6),
    darkSurface: Color(0xFF261D3A),
    lightSurface: Color(0xFFF3E8FF),
  ),
  NoteColorTheme(
    label: 'Blue',
    accent: Color(0xFF3B82F6),
    darkSurface: Color(0xFF1B283E),
    lightSurface: Color(0xFFEFF6FF),
  ),
  NoteColorTheme(
    label: 'Teal',
    accent: Color(0xFF14B8A6),
    darkSurface: Color(0xFF132F2B),
    lightSurface: Color(0xFFF0FDFA),
  ),
  NoteColorTheme(
    label: 'Green',
    accent: Color(0xFF22C55E),
    darkSurface: Color(0xFF16321F),
    lightSurface: Color(0xFFF0FDF4),
  ),
  NoteColorTheme(
    label: 'Amber',
    accent: Color(0xFFF59E0B),
    darkSurface: Color(0xFF362B17),
    lightSurface: Color(0xFFFFFBEB),
  ),
  NoteColorTheme(
    label: 'Coral',
    accent: Color(0xFFF97316),
    darkSurface: Color(0xFF382317),
    lightSurface: Color(0xFFFFF7ED),
  ),
  NoteColorTheme(
    label: 'Rose',
    accent: Color(0xFFF43F5E),
    darkSurface: Color(0xFF381921),
    lightSurface: Color(0xFFFFF1F2),
  ),
  NoteColorTheme(
    label: 'Plum',
    accent: Color(0xFFA855F7),
    darkSurface: Color(0xFF301B3A),
    lightSurface: Color(0xFFFAF5FF),
  ),
  NoteColorTheme(
    label: 'Slate',
    accent: Color(0xFF64748B),
    darkSurface: Color(0xFF242730),
    lightSurface: Color(0xFFF8FAFC),
  ),
];

NoteColorTheme? getThemeForColor(Color? color) {
  if (color == null) return null;
  for (final t in kNoteColorThemes) {
    if (t.accent.value == color.value) return t;
  }
  return null;
}
