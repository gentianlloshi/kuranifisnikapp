import 'package:flutter/foundation.dart';

/// Unified multi-select state for different modes (bookmarks, memorization, notes, etc.).
/// Prevents each feature from reinventing selection & bulk action wiring.
class SharedSelectionService extends ChangeNotifier {
  SelectionMode _mode = SelectionMode.none;
  final Set<String> _selected = <String>{}; // domain-specific keys (e.g., verseKey, noteId)

  SelectionMode get mode => _mode;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get active => _mode != SelectionMode.none;

  void start(SelectionMode mode, {Iterable<String>? initial}) {
    if (_mode != mode) {
      _mode = mode;
      _selected.clear();
      if (initial != null) _selected.addAll(initial);
      notifyListeners();
    }
  }

  void toggle(String key) {
    if (_mode == SelectionMode.none) return;
    if (!_selected.add(key)) _selected.remove(key);
    notifyListeners();
  }

  void addAll(Iterable<String> keys) { if (_mode == SelectionMode.none) return; _selected.addAll(keys); notifyListeners(); }
  void clearSelection() { if (_selected.isEmpty) return; _selected.clear(); notifyListeners(); }

  void end() {
    if (_mode == SelectionMode.none) return;
    _mode = SelectionMode.none;
    _selected.clear();
    notifyListeners();
  }

  bool isSelected(String key) => _selected.contains(key);
}

enum SelectionMode { none, bookmarks, memorization, notes, verses }
