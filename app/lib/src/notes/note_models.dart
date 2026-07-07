import 'package:flutter/material.dart';

class NotePreview {
  const NotePreview({
    required this.id,
    required this.title,
    required this.body,
    required this.mood,
    required this.reminderLabel,
    this.checklistItems = const [],
    this.pinned = false,
    this.recurring = false,
  });

  final String id;
  final String title;
  final String body;
  final ColorMood mood;
  final String reminderLabel;
  final List<ChecklistItemPreview> checklistItems;
  final bool pinned;
  final bool recurring;
}

class ChecklistItemPreview {
  const ChecklistItemPreview(this.text, {this.done = false});

  final String text;
  final bool done;
}

class MoodColors {
  const MoodColors({
    required this.background,
    required this.foreground,
    required this.accent,
  });

  final Color background;
  final Color foreground;
  final Color accent;
}

enum ColorMood {
  clear,
  focus,
  urgent,
  routine,
  errand;

  MoodColors resolve(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    return switch (this) {
      ColorMood.clear => MoodColors(
          background: dark ? const Color(0xFF20252A) : const Color(0xFFF6F7F4),
          foreground: dark ? const Color(0xFFE6E8E2) : const Color(0xFF202326),
          accent: const Color(0xFF5A8F82),
        ),
      ColorMood.focus => MoodColors(
          background: dark ? const Color(0xFF1D2C30) : const Color(0xFFE8F2ED),
          foreground: dark ? const Color(0xFFE3F0ED) : const Color(0xFF1F3435),
          accent: const Color(0xFF2E7D74),
        ),
      ColorMood.urgent => MoodColors(
          background: dark ? const Color(0xFF3B2526) : const Color(0xFFFFE8E3),
          foreground: dark ? const Color(0xFFF8E4DF) : const Color(0xFF3F2420),
          accent: const Color(0xFFC64E3C),
        ),
      ColorMood.routine => MoodColors(
          background: dark ? const Color(0xFF2C273A) : const Color(0xFFF0EBFF),
          foreground: dark ? const Color(0xFFEAE4FA) : const Color(0xFF30294A),
          accent: const Color(0xFF7453B6),
        ),
      ColorMood.errand => MoodColors(
          background: dark ? const Color(0xFF303123) : const Color(0xFFFFF3C8),
          foreground: dark ? const Color(0xFFF1ECCD) : const Color(0xFF383514),
          accent: const Color(0xFF90731B),
        ),
    };
  }

  static ColorMood fromName(String name) {
    return ColorMood.values.firstWhere(
      (mood) => mood.name == name,
      orElse: () => ColorMood.clear,
    );
  }
}

const sampleNotes = [
  NotePreview(
    id: 'sample-monthly-filter-order',
    title: 'Monthly filter order',
    body: 'Check furnace and fridge filter sizes before reordering.',
    mood: ColorMood.routine,
    reminderLabel: 'Repeats monthly',
    recurring: true,
    pinned: true,
  ),
  NotePreview(
    id: 'sample-trip-packing',
    title: 'Trip packing',
    body: '',
    mood: ColorMood.errand,
    reminderLabel: 'Tomorrow 8:00 AM',
    checklistItems: [
      ChecklistItemPreview('Chargers', done: true),
      ChecklistItemPreview('Medication'),
      ChecklistItemPreview('Boarding passes'),
    ],
  ),
];
