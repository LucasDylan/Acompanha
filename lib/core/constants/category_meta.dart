import 'package:flutter/material.dart';

/// A kind of meeting a host offers. The API stores [slug]; the app shows
/// [label].
class MeetingCategory {
  const MeetingCategory(this.slug, this.label, this.icon);

  final String slug;
  final String label;
  final IconData icon;
}

const meetingCategories = <MeetingCategory>[
  MeetingCategory('coffee', 'Café', Icons.coffee_rounded),
  MeetingCategory('networking', 'Networking', Icons.hub_rounded),
  MeetingCategory('mentorship', 'Mentoria', Icons.school_rounded),
  MeetingCategory('language', 'Idiomas', Icons.translate_rounded),
  MeetingCategory('travel', 'Viagem', Icons.luggage_rounded),
  MeetingCategory('social', 'Social', Icons.celebration_rounded),
  MeetingCategory('workout', 'Treino', Icons.fitness_center_rounded),
];

MeetingCategory? _find(String slug) {
  for (final c in meetingCategories) {
    if (c.slug == slug) return c;
  }
  return null;
}

String categoryLabel(String slug) => _find(slug)?.label ?? slug;

IconData categoryIcon(String slug) =>
    _find(slug)?.icon ?? Icons.local_activity_rounded;
