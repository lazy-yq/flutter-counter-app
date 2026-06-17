import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_page.dart';
import 'counter_service.dart';
import 'overlay_widget.dart';

const String _channelName = 'counter/foreground';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  overlayMain;
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '悬浮窗计数器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFE53935),
        useMaterial3: true,
      ),
      home: const AppLifecycleManager(),
    );
  }
}

class AppLifecycleManager extends StatefulWidget {
  const AppLifecycleManager({super.key});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  final MethodChannel _channel = const MethodChannel(_channelName);
  bool _isOverlayShowing = false;
  // 防止多次创建悬浮窗的锁
  bool _isCreatingOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleNativeCall);
    _requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onCloseFromNotification') {
      await _closeOverlay();
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    if (_isOverlayShowing) {
      await _closeOverlay();
    }
    if (mounted) setState(() {});
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
    if (!await FlutterOverlayWindow.isPermissionGranted() && mounted) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('需要悬浮窗权限'),
        content: const Text('为了在后台显示计数器悬浮窗，需要授予\n"显示在其他应用上层"的权限。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('稍后再说')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); FlutterOverlayWindow.requestPermission(); },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  /// 双击卡片进入 PiP 模式
  Future<void> _enterPipMode(Counter counter) async {
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      if (mounted) _showPermissionDialog();
      return;
    }

    await CounterService.instance.setActiveCounterId(counter.id);

    // 如果悬浮窗已显示，只切换计数器
    if (_isOverlayShowing) {
      await _updateOverlayData(counter);
      return;
    }

    // 先创建悬浮窗，再最小化
    await _showOverlay(counter);
    // 短暂延迟确保悬浮窗引擎完全启动后再最小化
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      await _channel.invokeMethod('moveTaskToBack');
    } catch (_) {}
  }

  Future<void> _showOverlay(Counter counter) async {
    if (_isOverlayShowing || _isCreatingOverlay) return;
    _isCreatingOverlay = true;
    try {
      await FlutterOverlayWindow.showOverlay(
        height: 130,
        width: 130,
        alignment: OverlayAlignment.center,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,
        overlayTitle: counter.name,
        overlayContent: '${counter.count}',
      );
      _isOverlayShowing = true;
      await _updateOverlayData(counter);
      await _startForegroundService(counter);
    } catch (e) {
      debugPrint('显示悬浮窗失败: $e');
    } finally {
      _isCreatingOverlay = false;
    }
  }

  Future<void> _updateOverlayData(Counter counter) async {
    try {
      await FlutterOverlayWindow.shareData({
        'action': 'updateActiveCounter',
        'id': counter.id,
        'name': counter.name,
        'count': counter.count,
      });
    } catch (_) {}
  }

  Future<void> _closeOverlay() async {
    _isOverlayShowing = false;
    await CounterService.instance.setActiveCounterId(null);
    try { await FlutterOverlayWindow.closeOverlay(); } catch (_) {}
    try { await _stopForegroundService(); } catch (_) {}
  }

  Future<void> _startForegroundService(Counter counter) async {
    try {
      await _channel.invokeMethod('startForeground', {
        'count': counter.count,
        'name': counter.name,
      });
    } catch (_) {}
  }

  Future<void> _stopForegroundService() async {
    try { await _channel.invokeMethod('stopForeground'); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return HomePage(onEnterPipMode: _enterPipMode);
  }
}
