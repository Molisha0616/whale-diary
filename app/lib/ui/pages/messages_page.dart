import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_message.dart';
import '../../store/app_db.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<AppMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AppDb.instance.markAllRead();
    final list = await AppDb.instance.messages();
    if (!mounted) return;
    setState(() {
      _messages = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _messages.isEmpty
              ? Center(
                  child: Text('还没有消息',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _tile(_messages[i]),
                ),
    );
  }

  Widget _tile(AppMessage m) {
    final kindText = switch (m.kind) {
      'plan_unconfirmed' => '计划提醒',
      'weekly' => '周报',
      'monthly' => '月报',
      'yearly' => '年报',
      'daily' => '日报',
      _ => '提醒',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                kindText,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF4FA3D1)),
              ),
              const Spacer(),
              Text(
                DateFormat('M月d日 HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(m.createdAt)),
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(m.title, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            m.body,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '—— 肥鱼',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
