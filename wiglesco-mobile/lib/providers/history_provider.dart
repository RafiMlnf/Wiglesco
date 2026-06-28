import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/history_item.dart';

const String _boxName = 'history';
const int _maxItems = 20;

class HistoryNotifier extends StateNotifier<List<HistoryItem>> {
  HistoryNotifier() : super([]) {
    _load();
  }

  Box<HistoryItem>? _box;

  void _load() {
    _box = Hive.box<HistoryItem>(_boxName);
    state = _box!.values.toList().reversed.toList();
  }

  Future<void> addItem(HistoryItem item) async {
    _box ??= Hive.box<HistoryItem>(_boxName);
    await _box!.put(item.id, item);

    // Keep only last N items
    final keys = _box!.keys.toList();
    if (keys.length > _maxItems) {
      final toRemove = keys.take(keys.length - _maxItems).toList();
      await _box!.deleteAll(toRemove);
    }

    state = _box!.values.toList().reversed.toList();
  }

  Future<void> removeItem(String id) async {
    _box ??= Hive.box<HistoryItem>(_boxName);
    await _box!.delete(id);
    state = _box!.values.toList().reversed.toList();
  }

  Future<void> clearAll() async {
    _box ??= Hive.box<HistoryItem>(_boxName);
    await _box!.clear();
    state = [];
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryItem>>(
  (_) => HistoryNotifier(),
);
