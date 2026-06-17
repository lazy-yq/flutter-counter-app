import 'package:flutter/material.dart';
import 'counter_service.dart';

class HomePage extends StatefulWidget {
  final void Function(Counter counter)? onEnterPipMode;

  const HomePage({super.key, this.onEnterPipMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Counter> _counters = [];

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
    final updated = await CounterService.instance.incrementCounter(counter.id);
    if (updated != null && mounted) {
      setState(() {
        final idx = _counters.indexWhere((c) => c.id == updated.id);
        if (idx != -1) _counters[idx] = updated;
      });
    }
  }

  void _enterPipMode(Counter counter) {
    widget.onEnterPipMode?.call(counter);
  }

  Future<void> _addCounter() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增计数器'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入计数器名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final counter = await CounterService.instance.addCounter(result);
      if (mounted) setState(() => _counters.add(counter));
    }
  }

  Future<void> _showCounterOptions(Counter counter) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _renameCounter(counter);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('归零'),
              onTap: () {
                Navigator.pop(ctx);
                _resetCounter(counter);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_in_picture),
              title: const Text('进入悬浮球模式'),
              onTap: () {
                Navigator.pop(ctx);
                _enterPipMode(counter);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteCounter(counter);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameCounter(Counter counter) async {
    final nameController = TextEditingController(text: counter.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名计数器'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入新名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await CounterService.instance.updateCounterName(counter.id, result);
      if (mounted) {
        setState(() {
          final idx = _counters.indexWhere((c) => c.id == counter.id);
          if (idx != -1) _counters[idx].name = result;
        });
      }
    }
  }

  Future<void> _resetCounter(Counter counter) async {
    await CounterService.instance.resetCounter(counter.id);
    if (mounted) {
      setState(() {
        final idx = _counters.indexWhere((c) => c.id == counter.id);
        if (idx != -1) _counters[idx].count = 0;
      });
    }
  }

  Future<void> _deleteCounter(Counter counter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除计数器'),
        content: Text('确定要删除"${counter.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CounterService.instance.deleteCounter(counter.id);
      if (mounted) setState(() => _counters.removeWhere((c) => c.id == counter.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('计数器'),
        centerTitle: true,
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCounter,
        backgroundColor: const Color(0xFF6C5CE7),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _counters.isEmpty ? _buildEmptyState(theme) : _buildCounterList(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '还没有计数器',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角 + 按钮创建',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _counters.length,
      itemBuilder: (ctx, index) => _buildCounterCard(_counters[index], theme),
    );
  }

  Widget _buildCounterCard(Counter counter, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _increment(counter),
        onDoubleTap: () => _enterPipMode(counter),
        onLongPress: () => _showCounterOptions(counter),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 计数器图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_circle, color: Color(0xFF6C5CE7), size: 28),
              ),
              const SizedBox(width: 16),
              // 名称与提示
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      counter.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '双击进入悬浮球模式',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              // 计数显示
              Text(
                '${counter.count}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C5CE7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
