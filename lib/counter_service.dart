// filename: lib/counter_service.dart
// 计数服务 - 基于 SharedPreferences 的本地数据持久化，单例模式

import 'package:shared_preferences/shared_preferences.dart';

/// 计数存储 Key
const String _counterKey = 'counter_value';

class CounterService {
  CounterService._();

  static final CounterService _instance = CounterService._();

  /// 获取单例实例
  static CounterService get instance => _instance;

  /// 获取持久化存储的计数值
  ///
  /// 返回当前计数，首次使用时默认为 0
  Future<int> getCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_counterKey) ?? 0;
  }

  /// 累加计数（+1）并持久化保存
  ///
  /// 返回累加后的新值
  Future<int> increment() async {
    final prefs = await SharedPreferences.getInstance();
    final newCount = (prefs.getInt(_counterKey) ?? 0) + 1;
    await prefs.setInt(_counterKey, newCount);
    return newCount;
  }

  /// 设置计数值为指定值
  Future<void> setCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_counterKey, count);
  }

  /// 重置计数为 0
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_counterKey, 0);
  }
}