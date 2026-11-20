import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/entry.dart';

class DayRail extends StatelessWidget {
  final List<DateTime> days;
  final DateTime selected;
  final DateTime today;
  final Map<String, List<Entry>> plansByDay;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPastToday;

  const DayRail({
    super.key,
    required this.days,
    required this.selected,
    required this.today,
    required this.plansByDay,
    required this.onSelect,
    required this.onPastToday,
  });

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _label(DateTime d) {
    final diff = d.difference(today).inDays;
    if (diff == 1) return '明天';
    if (diff == 0) return '今天';
    if (diff == -1) return '昨天';
    return '${d.month}月${d.day}日';
  }

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF1C1C1C))),
      ),
      child: Column(
        children: [
          ...days.map((d) {
            final isSel = _same(d, selected);
            final showPlans = _same(d, today) ||
                _same(d, today.add(const Duration(days: 1)));
            return Expanded(
              flex: isSel ? 7 : 4,
              child: _cell(d, isSel, showPlans, plansByDay[_key(d)] ?? const []),
            );
          }),
          const Divider(height: 1, color: Color(0xFF1C1C1C)),
          InkWell(
            onTap: onPastToday,
            child: SizedBox(
              height: 46,
              child: Center(
                child: Text(
                  '往年今日',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(DateTime d, bool isSel, bool showPlans, List<Entry> plans) {
    return InkWell(
      onTap: () => onSelect(d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF1B3A4B) : Colors.transparent,
          border: Border(
            left: BorderSide(
              width: 2,
              color: isSel ? const Color(0xFF4FA3D1) : Colors.transparent,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment:
              showPlans ? MainAxisAlignment.start : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showPlans) const SizedBox(height: 8),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: isSel ? 15 : 13,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                color: isSel ? Colors.white : Colors.white.withValues(alpha: 0.55),
              ),
              child: Text(_label(d), textAlign: TextAlign.center),
            ),
            if (showPlans)
              Expanded(
                child: plans.isEmpty
                    ? Center(
                        child: Text('无',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.25))),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        itemCount: plans.length,
                        itemBuilder: (_, i) => _planRow(plans[i]),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  /// 计划只做文本播报，不当链接、不跳转。
  Widget _planRow(Entry p) {
    final (icon, color, stateText) = switch (p.planState) {
      'done' => ('✓', const Color(0xFF6FCF97), '已完成'),
      'undone' => ('✗', const Color(0xFFEB5757), '未完成'),
      _ => ('·', Colors.white.withValues(alpha: 0.35), '未确认'),
    };
    return Semantics(
      label: '计划，${p.body}，$stateText',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon,
                style: TextStyle(fontSize: 10, height: 1.3, color: color)),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                p.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

