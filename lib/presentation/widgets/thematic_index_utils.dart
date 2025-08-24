import 'package:flutter/material.dart';

/// Map a human-readable thematic category label to a representative icon.
IconData iconForThemeLabel(String label) {
  final l = label.toLowerCase();
  if (l.contains('zot') || l.contains('allah') || l.contains('besim')) return Icons.auto_awesome;
  if (l.contains('njeri') || l.contains('moral') || l.contains('sjellje')) return Icons.people_alt_outlined;
  if (l.contains('famil') || l.contains('martes') || l.contains('prind')) return Icons.family_restroom;
  if (l.contains('ekonomi') || l.contains('tregt') || l.contains('pasur')) return Icons.attach_money;
  if (l.contains('ligj') || l.contains('urdh') || l.contains('ndal')) return Icons.gavel;
  if (l.contains('histor') || l.contains('pejgamber') || l.contains('profet')) return Icons.menu_book_outlined;
  if (l.contains('namaz') || l.contains('falje') || l.contains('adhu')) return Icons.self_improvement;
  if (l.contains('durim') || l.contains('sprov') || l.contains('dhemb')) return Icons.favorite_border;
  if (l.contains('dit') && l.contains('gjykim')) return Icons.balance_outlined;
  return Icons.category;
}

/// Build a lightweight preview for a verse reference string.
/// - If single verse (e.g., "2:255"), returns the translation/arabic via [resolveTextForRef] if available.
/// - If a range (e.g., "27:60-64"), tries the first verse of range via [resolveTextForRef],
///   else returns a summary like "Ajetet 60–64".
String? buildRefPreview(
  String ref, {
  required String? Function(String verseRef) resolveTextForRef,
}) {
  final parts = ref.split(':');
  if (parts.length != 2) return null;
  final surah = int.tryParse(parts[0]);
  if (surah == null) return null;
  final versePart = parts[1];
  final rangeSep = versePart.contains('–') ? '–' : '-';
  if (versePart.contains(rangeSep)) {
    final range = versePart.split(rangeSep);
    if (range.length != 2) return null;
    final start = int.tryParse(range[0]);
    final end = int.tryParse(range[1]);
    if (start == null || end == null) return null;
    final first = resolveTextForRef('$surah:$start');
    if (first != null && first.trim().isNotEmpty) return first;
    return 'Ajetet $start–$end';
  } else {
    final ayah = int.tryParse(versePart);
    if (ayah == null) return null;
    final t = resolveTextForRef(ref);
    return t;
  }
}
