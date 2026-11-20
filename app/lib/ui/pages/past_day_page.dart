import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/entry.dart';
import '../../models/entry_media.dart';
import '../../store/app_db.dart';
import 'record_page.dart';

/// 往年今日：历年同月同日的记录，先汇总、再按年列明细
class PastDayPage extends StatefulWidget {
  final DateTime day;

  const PastDayPage({super.key, required this.day});

  @override
  State<PastDayPage> createState() => _PastDayPageState();
}

class _PastDayPageState extends State<PastDayPage> {
  List<Entry> _entries = [];
  Map<int, List<EntryMedia>> _media = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AppDb.instance
        .entriesOnThisDay(widget.day.month, widget.day.day);
    final ids = list.map((e) => e.id).whereType<int>().toList();
    final media = await AppDb.instance.mediaForEntryIds(ids);
    final grouped = <int, List<EntryMedia>>{};
    for (final m in media) {
      grouped.putIfAbsent(m.entryId, () => []).add(m);
    }
    if (!mounted) return;
    setState(() {
      _entries = list;
      _media = grouped;
      _loading = false;
    });
  }

  Map<int, List<Entry>> get _byYear {
    final map = <int, List<Entry>>{};
    for (final e in _entries) {
      final year = int.parse(e.day.substring(0, 4));
      map.putIfAbsent(year, () => []).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final years = _byYear;
    final photoCount = _media.values
        .expand((l) => l)
        .where((m) => m.kind == 'photo')
        .length;

    return Scaffold(
      appBar: AppBar(title: Text('往年今日 · ${widget.day.month}月${widget.day.day}日')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _entries.isEmpty
              ? Center(
                  child: Text(
                    '往年这天还没写过东西',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '共 ${years.length} 年 · ${_entries.length} 条记录 · $photoCount 张照片',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (years.keys.toList()..sort((a, b) => b - a))
                                .map((y) => '$y年（${years[y]!.length}条）')
                                .join('　'),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final year in years.keys.toList()..sort((a, b) => b - a))
                      _yearBlock(year, years[year]!),
                  ],
                ),
    );
  }

  Widget _yearBlock(int year, List<Entry> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text('$year 年',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF4FA3D1))),
        ),
        ...list.map((e) {
          final media = _media[e.id] ?? const [];
          final time = DateFormat('HH:mm')
              .format(DateTime.fromMillisecondsSinceEpoch(e.createdAt));
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RecordPage(entryId: e.id!))),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(time,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.body.isEmpty ? '（无文字）' : e.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                      if (media.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('${media.length}图',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.4))),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

