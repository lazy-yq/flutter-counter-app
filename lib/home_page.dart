// filename: lib/home_page.dart
// 主页面 - 显示计数按钮、引导开启悬浮窗权限、状态提示

import 'package:flutter/material.dart';
import 'counter_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _count = 0;
  bool _hasOverlayPermission = false;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final count = await CounterService.instance.getCount();
    if (mounted) setState(() => _count = count);
  }

  /// 点击计数 +1
  Future<void> _increment() async {
    final newCount = await CounterService.instance.increment();
    if (mounted) setState(() => _count = newCount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('悬浮窗计数器'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const Spacer(flex: 1),

          // 说明文字
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '点击下方圆形按钮累加计数\n按 Home 键后按钮将以悬浮窗形式显示',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),

          const SizedBox(height: 40),

          // 圆形计数按钮
          GestureDetector(
            onTap: _increment,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '$_count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            '当前计数',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),

          const Spacer(flex: 1),

          // 底部提示（如权限引导）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: const Text(
              '提示：按 Home 键或返回键后\n计数器将以悬浮窗形式显示在其他应用上层',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}