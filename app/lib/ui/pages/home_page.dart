import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/entry.dart';
import '../../services/report_scheduler.dart';
import '../../services/reminder_service.dart';
import '../../store/app_db.dart';
import '../widgets/day_rail.dart';
import '../widgets/entry_card.dart';
import '../widgets/report_card.dart';
import 'calendar_page.dart';
import 'compose_page.dart';
import 'messages_page.dart';
import 'past_day_page.dart';
import 'record_page.dart';
import 'report_page.dart';
import 'settings_page.dart';

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
String dayKey(DateTime t) => DateFormat('yyyy-MM-dd').format(t);
String _weekdayCn(DateTime d) =>
    const ['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _selected;
  List<Entry> _entries = [];
  Map<String, List<Entry>> _plansByDay = {};
  Map<int, String> _firstPhoto = {};
  Map<String, Object?>? _dailyReport;
  int _unread = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = dateOnly(DateTime.now());
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await runPlanReminders();
    try {
      await ReportScheduler.runOnOpen();
    } catch (_) {
      // 报告补生成失败不影响打开 app
    }
    await _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final today = dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final entries = await AppDb.instance.entriesForDay(dayKey(_selected));
    final todayPlans = await AppDb.instance.plansForDay(dayKey(today));
    final tomorrowPlans = await AppDb.instance.plansForDay(dayKey(tomorrow));
    final unread = await AppDb.instance.unreadCount();
    final photos = await AppDb.instance.firstPhotoMap();
    final daily = await AppDb.instance.reportFor('daily', dayKey(_selected));
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _plansByDay = {
        dayKey(today): todayPlans,
        dayKey(tomorrow): tomorrowPlans,
      };
      _unread = unread;
      _firstPhoto = photos;
      _dailyReport = daily;
      _loading = false;
    });
  }

  Future<void> _openCompose() async {
    final today = dateOnly(DateTime.now());
    final sel = dateOnly(_selected);
    if (sel.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('过去的日期不能补写，只能在记录里追加评论'),
      ));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ComposePage(day: _selected),
    ));
    _reload();
  }

  Future<void> _openRecord(Entry e) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RecordPage(entryId: e.id!),
    ));
    await runPlanReminders();
    _reload();
  }

  bool get _isInRail {
    final today = dateOnly(DateTime.now());
    final diff = dateOnly(_selected).difference(today).inDays;
    return diff >= -5 && diff <= 1;
  }

  Future<void> _openCalendar() async {
    final picked = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(builder: (_) => CalendarPage(initial: _selected)),
    );
    if (picked != null) {
      setState(() => _selected = dateOnly(picked));
      _reload();
    }
  }

  Future<void> _openMessages() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MessagesPage()));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final days = [1, 0, -1, -2, -3, -4, -5]
        .map((d) => today.add(Duration(days: d)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 150,
        leading: Row(
          children: [
            IconButton(
              tooltip: '日历',
              icon: const Icon(Icons.calendar_today_outlined, size: 20),
              onPressed: _openCalendar,
            ),
            IconButton(
              tooltip: '消息',
              onPressed: _openMessages,
              icon: Badge(
                isLabelVisible: _unread > 0,
                label: Text('$_unread'),
                child: const Icon(Icons.notifications_none, size: 21),
              ),
            ),
            IconButton(
              tooltip: '设置',
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SettingsPage()));
                _reload();
              },
            ),
          ],
        ),
        title: Text(
          '${_selected.month}月${_selected.day}日 周${_weekdayCn(_selected)}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (!_isInRail)
            TextButton(
              onPressed: () {
                setState(() => _selected = dateOnly(DateTime.now()));
                _reload();
              },
              child: const Text('回到今天', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 108,
            child: DayRail(
              days: days,
              selected: _selected,
              today: today,
              plansByDay: _plansByDay,
              onPastToday: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PastDayPage(day: dateOnly(DateTime.now())),
                ),
              ),
              onSelect: (d) {
                setState(() => _selected = d);
                _reload();
              },
            ),
          ),
          Expanded(child: _buildFeed()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCompose,
        backgroundColor: const Color(0xFF4FA3D1),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildFeed() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final hasReport = _dailyReport != null;
    if (_entries.isEmpty && !hasReport) {
      return Center(
        child: Text(
          '这天还没写',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: _entries.length + (hasReport ? 1 : 0),
      itemBuilder: (_, i) {
        if (hasReport && i == _entries.length) {
          final body = _dailyReport!['body'] as String;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ReportCard(
              label: '日报',
              text: body,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReportPage(label: '日报', body: body),
              )),
            ),
          );
        }
        final e = _entries[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: EntryCard(
            entry: e,
            photoPath: _firstPhoto[e.id],
            onTap: () => _openRecord(e),
          ),
        );
      },
    );
  }
}










