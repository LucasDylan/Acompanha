import 'package:flutter/material.dart';

/// A kind of meeting a host offers. The API stores [slug]; the app shows
/// [label].
class MeetingCategory {
  const MeetingCategory(this.slug, this.label, this.icon, this.description);

  final String slug;
  final String label;
  final IconData icon;

  /// One line saying what this kind of meeting is.
  final String description;
}

const meetingCategories = <MeetingCategory>[
  MeetingCategory('coffee', 'Café', Icons.coffee_rounded,
      'Um papo tomando um café.'),
  MeetingCategory('networking', 'Networking', Icons.hub_rounded,
      'Trocar ideias e contatos na sua área.'),
  MeetingCategory('mentorship', 'Mentoria', Icons.school_rounded,
      'Conselhos de carreira com quem já passou por isso.'),
  MeetingCategory('language', 'Idiomas', Icons.translate_rounded,
      'Praticar conversação em outro idioma.'),
  MeetingCategory('travel', 'Viagem', Icons.luggage_rounded,
      'Roteiros pela cidade com quem conhece.'),
  MeetingCategory('social', 'Social', Icons.celebration_rounded,
      'Eventos, shows e passeios pela cidade.'),
  MeetingCategory('workout', 'Treino', Icons.fitness_center_rounded,
      'Treinar junto, com orientação.'),
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

String? categoryDescription(String slug) => _find(slug)?.description;
