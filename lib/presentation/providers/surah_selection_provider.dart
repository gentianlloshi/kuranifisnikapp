import 'package:flutter/material.dart';

class SurahSelectionProvider extends ChangeNotifier {
  bool _selectionMode = false;
  final Set<int> _selected = <int>{};

  bool get selectionMode => _selectionMode;
  List<int> get selectedIds => _selected.toList(growable: false);
  int get count => _selected.length;
  bool isSelected(int surahNumber) => _selected.contains(surahNumber);

  void enterWith(int surahNumber) {
    if (!_selectionMode) {
      _selectionMode = true;
    }
    _selected.add(surahNumber);
    notifyListeners();
  }

  void toggle(int surahNumber) {
    if (!_selectionMode) {
      enterWith(surahNumber);
      return;
    }
    if (_selected.remove(surahNumber)) {
      if (_selected.isEmpty) {
        _selectionMode = false;
      }
    } else {
      _selected.add(surahNumber);
    }
    notifyListeners();
  }

  void clear() {
    if (_selected.isEmpty && !_selectionMode) return;
    _selected.clear();
    _selectionMode = false;
    notifyListeners();
  }

  void selectAll(Iterable<int> ids) {
    _selectionMode = true;
    _selected
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }
}
