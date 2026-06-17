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
        colorSchemeSeed: const Color(0xFF6C5CE7),
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
      await _closeOverlayWindow();
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
      await _closeOverlayWindow();
    }
    if (mounted) setState(() {});
  }

  Future<void> _requestPermissions() async {
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) {
      await Permission.notification.request();
    }

    final hasOverlayPerm = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasOverlayPerm && mounted) {
      _showPermissionDialog();
    }
  }

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

  /// 进入悬浮球 PiP 模式
  Future<void> _enterPipMode(Counter counter) async {
    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasPermission) {
      if (mounted) _showPermissionDialog();
      return;
    }

    await CounterService.instance.setActiveCounterId(counter.id);

    try {
      if (_isOverlayShowing) {
        // 悬浮窗已显示，只更新数据
        await _updateOverlayCounter(counter);
      } else {
        // 首次创建悬浮窗——使用 defaultMode 不拦截系统手势
        await FlutterOverlayWindow.showOverlay(
          height: 130,
          width: 130,
          alignment: OverlayAlignment.center,
          flag: OverlayFlag.defaultMode,
          enableDrag: true,
          overlayTitle: counter.name,
          overlayContent: '${counter.count}',
        );
        _isOverlayShowing = true;
        await _startForegroundService(counter);
      }

      // 同步计数器数据
      await _updateOverlayCounter(counter);

      // 最小化应用
      await _minimizeApp();
    } catch (e) {
      debugPrint('进入悬浮球模式失败: $e');
    }
  }

  Future<void> _updateOverlayCounter(Counter counter) async {
    await FlutterOverlayWindow.shareData({
      'action': 'updateActiveCounter',
      'id': counter.id,
      'name': counter.name,
      'count': counter.count,
    });
  }

  Future<void> _minimizeApp() async {
    try {
      await _channel.invokeMethod('moveTaskToBack');
    } catch (e) {
      debugPrint('最小化应用失败: $e');
    }
  }

  Future<void> _closeOverlayWindow() async {
    _isOverlayShowing = false;
    await CounterService.instance.setActiveCounterId(null);
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
    try {
      await _stopForegroundService();
    } catch (_) {}
  }

  Future<void> _startForegroundService(Counter counter) async {
    try {
      await _channel.invokeMethod('startForeground', {
        'count': counter.count,
        'name': counter.name,
      });
    } catch (e) {
      debugPrint('启动前台服务失败: $e');
    }
  }

  Future<void> _stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForeground');
    } catch (e) {
      debugPrint('停止前台服务失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomePage(onEnterPipMode: _enterPipMode);
  }
}
