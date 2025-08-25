import 'package:flutter/material.dart';

enum SelectionMode { none, verses, bookmarks, memorization }

class SelectionService extends ChangeNotifier {
  SelectionMode _mode = SelectionMode.none;
  final Set<String> _selected = <String>{};
  SelectionMode get mode => _mode;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get isActive => _mode != SelectionMode.none;

  void start(SelectionMode mode) {
    if (_mode == mode) return; 
    _mode = mode; 
    _selected.clear();
    notifyListeners();
  }
  void toggle(String key) {
    if (_mode == SelectionMode.none) return; 
    if (!_selected.add(key)) _selected.remove(key);
    if (_selected.isEmpty) { _mode = SelectionMode.none; }
    notifyListeners();
  }
  void clear() { if (_selected.isEmpty && _mode == SelectionMode.none) return; _selected.clear(); _mode = SelectionMode.none; notifyListeners(); }
  bool contains(String key) => _selected.contains(key);
}
