import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const String _countersKey = 'counters_list';
const String _activeCounterKey = 'active_counter_id';
const _uuid = Uuid();

class Counter {
  final String id;
  String name;
  int count;

  Counter({required this.id, required this.name, this.count = 0});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'count': count,
      };

  factory Counter.fromJson(Map<String, dynamic> json) => Counter(
        id: json['id'] as String,
        name: json['name'] as String,
        count: json['count'] as int? ?? 0,
      );
}

class CounterService {
  CounterService._();
  static final CounterService _instance = CounterService._();
  static CounterService get instance => _instance;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Counter>> getCounters() async {
    final prefs = await _prefs;
    final data = prefs.getString(_countersKey);
    if (data == null) return [];
    final list = json.decode(data) as List<dynamic>;
    return list.map((e) => Counter.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveCounters(List<Counter> counters) async {
    final prefs = await _prefs;
    final data = json.encode(counters.map((c) => c.toJson()).toList());
    await prefs.setString(_countersKey, data);
  }

  Future<Counter> addCounter(String name) async {
    final counters = await getCounters();
    final counter = Counter(id: _uuid.v4(), name: name);
    counters.add(counter);
    await _saveCounters(counters);
    return counter;
  }

  Future<void> updateCounterName(String id, String name) async {
    final counters = await getCounters();
    final idx = counters.indexWhere((c) => c.id == id);
    if (idx != -1) {
      counters[idx].name = name;
      await _saveCounters(counters);
    }
  }

  Future<void> deleteCounter(String id) async {
    final counters = await getCounters();
    counters.removeWhere((c) => c.id == id);
    await _saveCounters(counters);
    // 如果删除的是活跃计数器，清除活跃标记
    final activeId = await getActiveCounterId();
    if (activeId == id) {
      await setActiveCounterId(null);
    }
  }

  Future<Counter?> incrementCounter(String id) async {
    final counters = await getCounters();
    final idx = counters.indexWhere((c) => c.id == id);
    if (idx == -1) return null;
    counters[idx].count++;
    await _saveCounters(counters);
    return counters[idx];
  }

  Future<void> resetCounter(String id) async {
    final counters = await getCounters();
    final idx = counters.indexWhere((c) => c.id == id);
    if (idx != -1) {
      counters[idx].count = 0;
      await _saveCounters(counters);
    }
  }

  Future<Counter?> getCounter(String id) async {
    final counters = await getCounters();
    try {
      return counters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---- 活跃计数器（PiP 模式） ----

  Future<void> setActiveCounterId(String? id) async {
    final prefs = await _prefs;
    if (id == null) {
      await prefs.remove(_activeCounterKey);
    } else {
      await prefs.setString(_activeCounterKey, id);
    }
  }

  Future<String?> getActiveCounterId() async {
    final prefs = await _prefs;
    return prefs.getString(_activeCounterKey);
  }

  Future<Counter?> getActiveCounter() async {
    final id = await getActiveCounterId();
    if (id == null) return null;
    return getCounter(id);
  }
}
