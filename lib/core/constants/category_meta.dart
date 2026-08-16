import 'package:flutter/material.dart';

/// Maps a meeting category label (Portuguese or legacy English data) to a
/// representative icon, so category cards never fall back to a generic glyph.
IconData categoryIcon(String category) {
  final c = _normalize(category);
  if (c.contains('cafe') || c.contains('coffee')) return Icons.coffee_rounded;
  if (c.contains('network')) return Icons.hub_rounded;
  if (c.contains('mentor')) return Icons.school_rounded;
  if (c.contains('idioma') || c.contains('language')) {
    return Icons.translate_rounded;
  }
  if (c.contains('viagem') || c.contains('travel')) return Icons.luggage_rounded;
  if (c.contains('social') || c.contains('casual')) {
    return Icons.celebration_rounded;
  }
  if (c.contains('evento') || c.contains('event')) {
    return Icons.local_activity_rounded;
  }
  return Icons.local_activity_rounded;
}

String _normalize(String s) {
  s = s.toLowerCase().trim();
  const map = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'ê': 'e',
    'í': 'i',
    'ó': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ç': 'c',
  };
  map.forEach((k, v) => s = s.replaceAll(k, v));
  return s;
}
