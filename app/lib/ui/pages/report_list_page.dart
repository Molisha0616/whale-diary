import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/report_export_service.dart';
import '../../services/report_service.dart';
import '../../store/app_db.dart';
import 'report_page.dart';

/// 报告中心：周报／月报／年报，按状态决定「查看／生成／无／还没到」
class ReportListPage extends StatefulWidget {
  const ReportListPage({super.key});

  @override
  State<ReportListPage> createState() => _ReportListPageState();
}

enum _Kind { weekly, monthly, yearly }

class _ReportListPageState extends State<ReportListPage> {
  _Kind _kind = _Kind.weekly;
  DateTime _cursor = DateTime.now();
  String _status = '';
  String? _body;
  bool _loading = true;
  bool _busy = false;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _periodStart {
    switch (_kind) {
      case _Kind.weekly:
        return _cursor.subtract(Duration(days: _cursor.weekday - 1));
      case _Kind.monthly:
        return DateTime(_cursor.year, _cursor.month, 1);
      case _Kind.yearly:
        return DateTime(_cursor.year, 1, 1);
    }
  }

  DateTime get _periodEnd {
    switch (_kind) {
      case _Kind.weekly:
        return _periodStart.add(const Duration(days: 6));
      case _Kind.monthly:
        return DateTime(_cursor.year, _cursor.month + 1, 0);
      case _Kind.yearly:
        return DateTime(_cursor.year, 12, 31);
    }
  }

  String get _label {
    switch (_kind) {
      case _Kind.weekly:
        return '${DateFormat('M月d日').format(_periodStart)} - ${DateFormat('M月d日').format(_periodEnd)}';
      case _Kind.monthly:
        return '${_cursor.year}年${_cursor.month}月';
      case _Kind.yearly:
        return '${_cursor.year}年';
    }
  }

  String get _kindKey => switch (_kind) {
        _Kind.weekly => 'weekly',
        _Kind.monthly => 'monthly',
        _Kind.yearly => 'yearly',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final startKey = DateFormat('yyyy-MM-dd').format(_periodStart);
    final existing = await AppDb.instance.reportFor(_kindKey, startKey);
    final entries = await AppDb.instance
        .entriesBetween(startKey, DateFormat('yyyy-MM-dd').format(_periodEnd));

    String status;
    if (existing != null) {
      status = 'view';
    } else if (_periodEnd.isBefore(_today)) {
      status = entries.isEmpty ? 'none' : 'generate';
    } else if (_periodStart.isAfter(_today)) {
      status = 'future';
    } else {
      status = 'ongoing';
    }

    if (!mounted) return;
    setState(() {
      _status = status;
      _body = existing?['body'] as String?;
      _loading = false;
    });
  }

  void _shift(int delta) {
    setState(() {
      switch (_kind) {
        case _Kind.weekly:
          _cursor = _cursor.add(Duration(days: 7 * delta));
          break;
        case _Kind.monthly:
          _cursor = DateTime(_cursor.year, _cursor.month + delta, 1);
          break;
        case _Kind.yearly:
          _cursor = DateTime(_cursor.year + delta, 1, 1);
          break;
      }
    });
    _load();
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    ReportResult r;
    switch (_kind) {
      case _Kind.weekly:
        r = await ReportService.instance.generateWeekly(_periodStart);
        break;
      case _Kind.monthly:
        r = await ReportService.instance
            .generateMonthly(_periodStart.year, _periodStart.month);
        break;
      case _Kind.yearly:
        r = await ReportService.instance.generateYearly(_periodStart.year);
        break;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.body)));
      return;
    }
    await _load();
    if (!mounted) return;
    _open();
  }

  void _open() {
    if (_body == null) return;
    final title = switch (_kind) {
      _Kind.weekly => '周报',
      _Kind.monthly => '月报',
      _Kind.yearly => '年报',
    };
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportPage(label: title, body: _body!)),
    );
  }

  Future<void> _export() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final earliestStr = await AppDb.instance.earliestDay();
    final minDate = earliestStr == null
        ? DateTime.now().subtract(const Duration(days: 365))
        : DateTime.parse(earliestStr);
    var start = DateTime(now.year, now.month, 1);
    if (start.isBefore(minDate)) start = minDate;
    if (start.isAfter(today)) start = today;
    var end = today;
    final kinds = <String>{'daily', 'weekly', 'monthly', 'yearly'};
    List<ReportPlanItem> plan = [];
    var planning = false;

    Future<void> refreshPlan(StateSetter setLocal) async {
      planning = true;
      setLocal(() {});
      plan = await ReportExportService.plan(start, end, kinds);
      planning = false;
      setLocal(() {});
    }

    try {
      plan = await ReportExportService.plan(start, end, kinds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('统计失败：')));
      }
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final included = plan.where((i) => i.included).toList();
          final excluded = plan.where((i) => !i.included).toList();
          return AlertDialog(
            backgroundColor: const Color(0xFF141414),
            title: const Text('导出报告'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('开始日期'),
                      subtitle: Text(
                          DateFormat('yyyy年M月d日').format(start)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: start,
                          firstDate: minDate,
                          lastDate: today,
                        );
                        if (picked != null) {
                          start = picked;
                          await refreshPlan(setLocal);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('结束日期'),
                      subtitle: Text(DateFormat('yyyy年M月d日').format(end)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: end,
                          firstDate: minDate,
                          lastDate: today,
                        );
                        if (picked != null) {
                          end = picked;
                          await refreshPlan(setLocal);
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (key, label) in [
                          ('daily', '日报'),
                          ('weekly', '周报'),
                          ('monthly', '月报'),
                          ('yearly', '年报'),
                        ])
                          FilterChip(
                            label: Text(label),
                            selected: kinds.contains(key),
                            onSelected: (v) {
                              if (v) {
                                kinds.add(key);
                              } else {
                                kinds.remove(key);
                              }
                              refreshPlan(setLocal);
                            },
                          ),
                      ],
                    ),
                    if (end.isBefore(start))
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('结束日期不能早于开始日期',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFEB5757))),
                      ),
                    const SizedBox(height: 10),
                    if (planning)
                      const Text('正在统计…',
                          style: TextStyle(fontSize: 12))
                    else ..._planLines(included, excluded),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: end.isBefore(start) || included.isEmpty
                    ? null
                    : () async {
                        Navigator.of(ctx).pop();
                        final file = await ReportExportService.export(
                            start, end, plan);
                        if (!mounted) return;
                        await Share.shareXFiles([XFile(file.path)],
                            text: '鲸鱼日记报告导出');
                      },
                child: Text('导出 ${included.length} 篇'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _planLines(
      List<ReportPlanItem> included, List<ReportPlanItem> excluded) {
    final lines = <Widget>[];
    if (included.isEmpty) {
      lines.add(const Text('这段时间里没有可导出的报告',
          style: TextStyle(fontSize: 12)));
    } else {
      lines.add(const Text('将包含：',
          style: TextStyle(fontSize: 12, color: Color(0xFF6FCF97))));
      for (final it in included) {
        lines.add(Text(
          '· ${it.kindName} ${it.label}（覆盖 ${it.overlapDays}/${it.totalDays} 天）',
          style: const TextStyle(fontSize: 12, height: 1.5),
        ));
      }
    }
    if (excluded.isNotEmpty) {
      lines.add(const SizedBox(height: 6));
      lines.add(const Text('未包含：',
          style: TextStyle(fontSize: 12, color: Color(0xFFEB5757))));
      for (final it in excluded) {
        lines.add(Text(
          '· ${it.kindName} ${it.label}（覆盖 ${it.overlapDays}/${it.totalDays} 天，不足 2/3）',
          style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.45)),
        ));
      }
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('报告'),
        actions: [
          IconButton(
            tooltip: '导出报告',
            icon: const Icon(Icons.ios_share_outlined, size: 20),
            onPressed: _export,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SegmentedButton<_Kind>(
            segments: const [
              ButtonSegment(value: _Kind.weekly, label: Text('周报')),
              ButtonSegment(value: _Kind.monthly, label: Text('月报')),
              ButtonSegment(value: _Kind.yearly, label: Text('年报')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) {
              setState(() => _kind = s.first);
              _load();
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Text(_label, style: const TextStyle(fontSize: 15)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(1),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [_statusCard()],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final text = switch (_status) {
      'view' => '查看$_kindLabel',
      'generate' => '这期有记录但还没生成，点这里补生成',
      'none' => '无',
      'future' => '$_kindLongLabel还未到来，继续努力',
      _ => '$_kindLongLabel还没过完，继续努力',
    };
    final canAct = _status == 'view' || _status == 'generate';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 12),
          if (canAct)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : (_status == 'view' ? _open : _generate),
              icon: Icon(
                _status == 'view'
                    ? Icons.description_outlined
                    : Icons.add_circle_outline,
                size: 18,
              ),
              label: Text(_busy
                  ? '生成中…'
                  : (_status == 'view' ? '查看$_kindLabel' : '生成$_kindLabel')),
            ),
          if (_status == 'view' && _body != null) ...[
            const SizedBox(height: 12),
            Text(
              _summary(_body!),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _summary(String body) {
    final flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= 60 ? flat : '${flat.substring(0, 60)}…';
  }

  String get _kindLabel => switch (_kind) {
        _Kind.weekly => '周报',
        _Kind.monthly => '月报',
        _Kind.yearly => '年报',
      };

  String get _kindLongLabel => switch (_kind) {
        _Kind.weekly => '这一周',
        _Kind.monthly => '这个月',
        _Kind.yearly => '这一年',
      };
}



