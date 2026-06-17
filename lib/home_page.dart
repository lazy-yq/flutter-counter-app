import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'counter_service.dart';

class HomePage extends StatefulWidget {
  final void Function(Counter counter)? onEnterPipMode;
  const HomePage({super.key, this.onEnterPipMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Counter> _counters = [];
  String? _swipedCardId;

  @override
  void initState() {
    super.initState();
    _loadCounters();
  }

  Future<void> _loadCounters() async {
    final counters = await CounterService.instance.getCounters();
    if (mounted) setState(() => _counters = counters);
  }

  Future<void> _increment(Counter counter) async {
    if (_swipedCardId == counter.id) {
      setState(() => _swipedCardId = null);
      return;
    }
    final updated = await CounterService.instance.incrementCounter(counter.id);
    if (updated != null && mounted) {
      setState(() {
        final idx = _counters.indexWhere((c) => c.id == updated.id);
        if (idx != -1) _counters[idx] = updated;
      });
    }
  }

  Future<void> _addCounter() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增计数器'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入计数器名称', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('创建')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final counter = await CounterService.instance.addCounter(name);
      if (mounted) setState(() => _counters.add(counter));
    }
  }

  Future<void> _showOptions(Counter counter) async {
    setState(() => _swipedCardId = null);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () { Navigator.pop(ctx); _renameCounter(counter); },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('归零'),
              onTap: () { Navigator.pop(ctx); _resetCounter(counter); },
            ),
            ListTile(
              leading: const Icon(Icons.picture_in_picture),
              title: const Text('进入悬浮球模式'),
              onTap: () { Navigator.pop(ctx); widget.onEnterPipMode?.call(counter); },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); _deleteCounter(counter); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameCounter(Counter counter) async {
    final ctrl = TextEditingController(text: counter.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名计数器'),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: '输入新名称', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await CounterService.instance.updateCounterName(counter.id, name);
      if (mounted) setState(() => _counters.firstWhere((c) => c.id == counter.id).name = name);
    }
  }

  Future<void> _resetCounter(Counter counter) async {
    await CounterService.instance.resetCounter(counter.id);
    if (mounted) setState(() {
      _swipedCardId = null;
      final idx = _counters.indexWhere((c) => c.id == counter.id);
      if (idx != -1) _counters[idx].count = 0;
    });
  }

  Future<void> _deleteCounter(Counter counter) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除计数器'),
        content: Text('确定要删除"${counter.name}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await CounterService.instance.deleteCounter(counter.id);
      if (mounted) setState(() { _swipedCardId = null; _counters.removeWhere((c) => c.id == counter.id); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('计数器'),
          centerTitle: true,
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addCounter,
          backgroundColor: const Color(0xFFE53935),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: _counters.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('还没有计数器', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Text('点击右下角 + 按钮创建', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _counters.length,
                itemBuilder: (ctx, index) => _buildCard(_counters[index]),
              ),
      ),
    );
  }

  Widget _buildCard(Counter counter) {
    final isOpen = _swipedCardId == counter.id;
    const double actionsWidth = 160;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 88,
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    const Spacer(),
                    _actionBtn(Icons.restart_alt, '重置', Colors.orange, () => _resetCounter(counter)),
                    _actionBtn(Icons.delete, '删除', Colors.red, () => _deleteCounter(counter)),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _increment(counter),
                onDoubleTap: () {
                  if (isOpen) {
                    setState(() => _swipedCardId = null);
                  } else {
                    widget.onEnterPipMode?.call(counter);
                  }
                },
                onLongPress: () => _showOptions(counter),
                onHorizontalDragEnd: (d) {
                  if (d.primaryVelocity != null && d.primaryVelocity! < -400) {
                    setState(() => _swipedCardId = counter.id);
                  } else if (d.primaryVelocity != null && d.primaryVelocity! > 400) {
                    setState(() => _swipedCardId = null);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(isOpen ? -actionsWidth : 0, 0, 0),
                  child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_circle, color: Color(0xFFE53935), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(counter.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  isOpen ? '已展开操作按钮' : '左滑操作 | 双击悬浮球',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ),
                          Text('${counter.count}',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFFE53935)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        color: color,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
