// filename: lib/overlay_widget.dart
// 悬浮窗入口 - 在独立 Flutter 引擎中运行，@pragma 标记确保不被 tree-shaking 移除
// 提供圆形蓝色计数按钮，支持点击累加、长按关闭、拖拽移动

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 悬浮窗引擎入口点（必须用 @pragma 标记，防止 AOT 编译时被移除）
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayWidget(),
    ),
  );
}

/// 计数存储 Key（与 counter_service.dart 保持一致）
const String _counterKey = 'counter_value';

/// 悬浮窗圆形计数 Widget
class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  int _count = 0;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _listenToMainApp();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// 从 SharedPreferences 加载持久化计数
  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_counterKey) ?? 0;
    if (mounted) setState(() => _count = count);
  }

  /// 监听来自主应用的消息（通过 FlutterOverlayWindow.shareData 发送）
  void _listenToMainApp() {
    _subscription = FlutterOverlayWindow.overlayListener.listen((event) {
      // event 是从主应用发来的数据（JSON 字符串或 Map）
      if (event is Map && event['action'] == 'updateCount') {
        final newCount = event['count'] as int?;
        if (newCount != null && mounted) {
          setState(() => _count = newCount);
        }
      }
    });
  }

  /// 点击累加计数，同时持久化保存
  Future<void> _increment() async {
    final prefs = await SharedPreferences.getInstance();
    final newCount = (prefs.getInt(_counterKey) ?? 0) + 1;
    await prefs.setInt(_counterKey, newCount);
    if (mounted) setState(() => _count = newCount);
  }

  /// 长按弹出关闭确认对话框
  void _onLongPress() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭悬浮窗'),
        content: const Text('确定要关闭悬浮窗吗？\n关闭后需重新打开应用才能再次显示。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              FlutterOverlayWindow.closeOverlay();
            },
            child: const Text('关闭', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: _increment,
        onLongPress: _onLongPress,
        child: Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$_count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}