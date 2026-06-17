import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _countersKey = 'counters_list';
const String _activeCounterKey = 'active_counter_id';

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

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  String? _counterId;
  String _counterName = '';
  int _count = 0;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadActiveCounter();
    _listenToMainApp();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeCounterKey);
    if (activeId == null) return;

    final data = prefs.getString(_countersKey);
    if (data == null) return;

    final list = json.decode(data) as List<dynamic>;
    final found = (list).map((e) => e as Map<String, dynamic>).where((c) => c['id'] == activeId);

    if (found.isNotEmpty && mounted) {
      setState(() {
        _counterId = activeId;
        _counterName = found.first['name'] as String? ?? '';
        _count = found.first['count'] as int? ?? 0;
      });
    }
  }

  void _listenToMainApp() {
    _subscription = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && event['action'] == 'updateActiveCounter' && mounted) {
        setState(() {
          _counterId = event['id'] as String?;
          _counterName = event['name'] as String? ?? _counterName;
          _count = event['count'] as int? ?? _count;
        });
      }
    });
  }

  Future<void> _increment() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_countersKey);
    if (data == null || _counterId == null) return;

    final list = json.decode(data) as List<dynamic>;
    final counters = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final idx = counters.indexWhere((c) => c['id'] == _counterId);

    if (idx != -1) {
      final newCount = (counters[idx]['count'] as int? ?? 0) + 1;
      counters[idx]['count'] = newCount;
      await prefs.setString(_countersKey, json.encode(counters));
      if (mounted) setState(() => _count = newCount);
    }
  }

  Future<void> _closeOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeCounterKey);
    await FlutterOverlayWindow.closeOverlay();
  }

  void _onLongPress() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭悬浮球'),
        content: const Text('确定要关闭悬浮球吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _closeOverlay(); },
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
        onDoubleTap: _closeOverlay,
        onLongPress: _onLongPress,
        child: Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE53935),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_counterName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      _counterName,
                      style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  '$_count',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
