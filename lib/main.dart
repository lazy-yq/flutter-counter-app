// filename: lib/main.dart
// 应用主入口 - 权限检查、生命周期监听、悬浮窗启动/关闭、前台通知服务控制

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_page.dart';
import 'counter_service.dart';
import 'overlay_widget.dart'; // 确保 overlayMain() 不被 tree-shaking

/// MethodChannel 名称（与 MainActivity.kt 中 CHANNEL 保持一致）
const String _channelName = 'counter/foreground';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 保持对 overlayMain 的引用，防止 AOT 编译时移除
  overlayMain;
  runApp(const CounterApp());
}

/// 应用根 Widget
class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '悬浮窗计数器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const AppLifecycleManager(),
    );
  }
}

/// 应用生命周期管理器
/// - 监听前后台切换，控制悬浮窗显隐
/// - 管理前台通知服务
/// - 处理权限请求
class AppLifecycleManager extends StatefulWidget {
  const AppLifecycleManager({super.key});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  final MethodChannel _channel = const MethodChannel(_channelName);
  bool _isOverlayShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 注册来自 Android 原生层的消息（通知栏关闭按钮等）
    _channel.setMethodCallHandler(_handleNativeCall);

    // 启动后检查权限
    _requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 处理 Native 层 MethodCall（通知栏关闭按钮）
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onCloseFromNotification') {
      await _closeOverlayWindow();
    }
    return null;
  }

  /// 应用生命周期回调：进入后台 -> 显示悬浮窗，回到前台 -> 隐藏悬浮窗
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      _showOverlayWindow();
    } else if (state == AppLifecycleState.resumed) {
      _hideOverlayWindow();
    }
  }

  /// 按需请求通知权限和悬浮窗权限
  Future<void> _requestPermissions() async {
    // Android 13+ 通知权限
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) {
      await Permission.notification.request();
    }

    // 检查悬浮窗权限
    final hasOverlayPerm = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasOverlayPerm && mounted) {
      _showPermissionDialog();
    }
  }

  /// 权限引导对话框
  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('需要悬浮窗权限'),
        content: const Text(
          '为了在后台显示计数器悬浮窗，需要授予\n"显示在其他应用上层"的权限。\n\n'
          '点击"去设置"后，请找到本应用并开启该权限。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              FlutterOverlayWindow.requestPermission();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  /// 显示悬浮窗 + 前台通知
  Future<void> _showOverlayWindow() async {
    if (_isOverlayShowing) return;

    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasPermission) {
      if (mounted) _showPermissionDialog();
      return;
    }

    try {
      final count = await CounterService.instance.getCount();

      // 启动悬浮窗（enableDrag: true 支持拖拽移动）
      final result = await FlutterOverlayWindow.showOverlay(
        height: 120,
        width: 120,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.focusPointer | OverlayFlag.defaultSkip,
        enableDrag: true,
        overlayTitle: '计数器悬浮窗',
        overlayContent: '当前计数: $count',
      );

      if (result ?? false) {
        _isOverlayShowing = true;
        // 将当前计数同步给悬浮窗（跨 isolate 通信）
        await FlutterOverlayWindow.shareData(
          {'action': 'updateCount', 'count': count},
        );
        // 启动前台通知服务
        await _startForegroundService(count);
      }
    } catch (e) {
      debugPrint('显示悬浮窗失败: $e');
    }
  }

  /// 隐藏悬浮窗（应用回到前台）
  Future<void> _hideOverlayWindow() async {
    if (!_isOverlayShowing) return;

    try {
      await FlutterOverlayWindow.closeOverlay();
      _isOverlayShowing = false;
      await _stopForegroundService();

      // 刷新主页计数（悬浮窗可能在后台修改了计数）
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('关闭悬浮窗失败: $e');
    }
  }

  /// 通知栏关闭按钮触发
  Future<void> _closeOverlayWindow() async {
    _isOverlayShowing = false;
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  /// 启动前台通知服务
  Future<void> _startForegroundService(int count) async {
    try {
      await _channel.invokeMethod('startForeground', {'count': count});
    } catch (e) {
      debugPrint('启动前台服务失败: $e');
    }
  }

  /// 停止前台通知服务
  Future<void> _stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForeground');
    } catch (e) {
      debugPrint('停止前台服务失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}