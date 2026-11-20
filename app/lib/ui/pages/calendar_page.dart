import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart';

import '../../store/app_db.dart';
import 'report_list_page.dart';

/// 日历页：月视图 + 节日 + 有记录打点；点日期回首页该天。
/// 右上角进「报告」中心（周报／月报／年报）。
class CalendarPage extends StatefulWidget {
  final DateTime initial;

  const CalendarPage({super.key, required this.initial});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month; // 当月 1 号
  Set<String> _daysWithEntries = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initial.year, widget.initial.month, 1);
    _load();
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    final days = await AppDb.instance.daysWithEntries(
      _month.year,
      _month.month,
    );
    if (!mounted) return;
    setState(() {
      _daysWithEntries = days.toSet();
      _loading = false;
    });
  }

  void _shift(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months, 1);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday;
    final leading = firstWeekday - 1;
    final cells = <Widget>[];

    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final hasEntry = _daysWithEntries.contains(_key(date));
      cells.add(_dayCell(date, isToday, hasEntry));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_month.year}年${_month.month}月'),
        actions: [
          IconButton(
            tooltip: '报告',
            icon: const Icon(Icons.assessment_outlined, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportListPage()),
            ),
          ),
          IconButton(
            tooltip: '上个月',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shift(-1),
          ),
          IconButton(
            tooltip: '下个月',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shift(1),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: ['一', '二', '三', '四', '五', '六', '日']
                        .map((w) => Expanded(
                              child: Center(
                                child: Text(
                                  w,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 0.8,
                      children: cells,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _dayCell(DateTime date, bool isToday, bool hasEntry) {
    final festivals = _festivals(date);
    return InkWell(
      onTap: () => Navigator.of(context).pop(date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: const Color(0xFF4FA3D1), width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                color: isToday ? const Color(0xFF4FA3D1) : Colors.white,
              ),
            ),
            const SizedBox(height: 1),
            ...festivals.take(2).map(
                  (f) => Text(
                    f,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8,
                      height: 1.15,
                      color: Color(0xFFB07CC6),
                    ),
                  ),
                ),
            if (hasEntry)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF4FA3D1),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  // 中国节日 + 劳动者/国际共运纪念日；洋节（万圣、感恩之类）不标
  static const Map<String, List<String>> _fixedFestivals = {
    '01-01': ['元旦'],
    '03-08': ['妇女节'],
    '03-12': ['植树节'],
    '05-01': ['劳动节'],
    '05-04': ['青年节'],
    '06-01': ['儿童节'],
    '07-01': ['建党节'],
    '08-01': ['建军节'],
    '09-10': ['教师节'],
    '10-01': ['国庆节'],
    '11-07': ['十月革命'],
    '12-26': ['毛主席诞辰'],
    '12-25': ['苏联解体'],
    '09-09': ['毛主席逝世'],
    '04-22': ['列宁诞辰'],
    '01-21': ['列宁逝世'],
    '12-18': ['斯大林诞辰'],
    '03-05': ['斯大林逝世'],
    '06-14': ['格瓦拉诞辰'],
    '10-09': ['格瓦拉逝世'],
  };

  List<String> _festivals(DateTime date) {
    final mmdd = '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final result = <String>[...?_fixedFestivals[mmdd]];
    try {
      final lunar = Solar.fromDate(date).getLunar();
      result.addAll(lunar.getFestivals());
      final jieQi = lunar.getJieQi();
      if (jieQi.isNotEmpty) result.add(jieQi);
    } catch (_) {
      // 节日数据不可用时不算错
    }
    return result;
  }
}

