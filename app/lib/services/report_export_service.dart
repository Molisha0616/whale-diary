import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../store/app_db.dart';

/// 一条报告在导出计划里的状态
class ReportPlanItem {
  final String kind; // daily/weekly/monthly/yearly
  final String periodStart;
  final String periodEnd;
  final String body;
  final int overlapDays;
  final int totalDays;
  final bool included;

  const ReportPlanItem({
    required this.kind,
    required this.periodStart,
    required this.periodEnd,
    required this.body,
    required this.overlapDays,
    required this.totalDays,
    required this.included,
  });

  double get coverage => totalDays == 0 ? 0 : overlapDays / totalDays;

  String get kindName => switch (kind) {
        'weekly' => '周报',
        'monthly' => '月报',
        'yearly' => '年报',
        _ => '日报',
      };

  String get label {
    switch (kind) {
      case 'weekly':
      case 'daily':
        return '$periodStart ~ $periodEnd';
      case 'monthly':
        return '${periodStart.substring(0, 4)}年${int.parse(periodStart.substring(5, 7))}月';
      case 'yearly':
        return '${periodStart.substring(0, 4)}年';
    }
    return periodStart;
  }
}

/// 按「完整包含」或「覆盖 ≥ 2/3」挑报告，并打包成 年/月/周/日 分目录的 zip
class ReportExportService {
  ReportExportService._();

  static const _threshold = 2 / 3;

  static Future<List<ReportPlanItem>> plan(
    DateTime start,
    DateTime end,
    Set<String> kinds,
  ) async {
    // sqflite 返回的是不可变列表，排序前先拷贝一份
    final rows = List<Map<String, Object?>>.from(
        await AppDb.instance.allReports());
    // 同一周期可能生成过多次（比如手动预览），只留最新那份
    rows.sort((a, b) =>
        (b['generated_at'] as int).compareTo(a['generated_at'] as int));
    final seen = <String>{};
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final items = <ReportPlanItem>[];
    for (final r in rows) {
      final kind = r['kind'] as String;
      if (!kinds.contains(kind)) continue;
      final dedupeKey = '$kind|${r['period_start']}';
      if (!seen.add(dedupeKey)) continue;
      final ps = DateTime.parse(r['period_start'] as String);
      final pe = DateTime.parse(r['period_end'] as String);
      final totalDays = pe.difference(ps).inDays + 1;
      final from = ps.isAfter(s) ? ps : s;
      final to = pe.isBefore(e) ? pe : e;
      final overlap = to.difference(from).inDays + 1;
      final clamped = overlap.clamp(0, totalDays);
      final coverage = totalDays == 0 ? 0.0 : clamped / totalDays;
      final included =
          kind == 'daily' ? clamped == totalDays : coverage >= _threshold;
      items.add(ReportPlanItem(
        kind: kind,
        periodStart: r['period_start'] as String,
        periodEnd: r['period_end'] as String,
        body: r['body'] as String,
        overlapDays: clamped,
        totalDays: totalDays,
        included: included,
      ));
    }
    items.sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return items;
  }

  static Future<File> export(
    DateTime start,
    DateTime end,
    List<ReportPlanItem> items,
  ) async {
    final included = items.where((i) => i.included).toList();
    final tmp = await getTemporaryDirectory();
    final name =
        '鲸鱼日记-报告-${DateFormat('yyyyMMdd').format(start)}至${DateFormat('yyyyMMdd').format(end)}.zip';
    final file = File(p.join(tmp.path, name));
    final encoder = ZipFileEncoder();
    encoder.create(file.path);

    for (final it in included) {
      final folder = _folderOf(it);
      final fileName = _fileNameOf(it);
      final content = utf8.encode('${it.kindName} · ${it.label}\n\n${it.body}\n');
      encoder.addArchiveFile(
        ArchiveFile('$folder/$fileName', content.length, content),
      );
    }
    if (included.isEmpty) {
      final note = utf8.encode('所选区间内没有符合条件的报告。\n');
      encoder.addArchiveFile(ArchiveFile('说明.txt', note.length, note));
    }
    await encoder.close();
    return file;
  }

  static String _folderOf(ReportPlanItem it) {
    switch (it.kind) {
      case 'yearly':
        return '年/${it.periodStart.substring(0, 4)}';
      case 'monthly':
        return '月/${it.periodStart.substring(0, 7)}';
      case 'weekly':
        final d = DateTime.parse(it.periodStart);
        return '周/${d.year}-W${_weekOfYear(d)}';
      default:
        return '日/${it.periodStart}';
    }
  }

  static String _fileNameOf(ReportPlanItem it) {
    switch (it.kind) {
      case 'yearly':
        return '年报-${it.periodStart.substring(0, 4)}.md';
      case 'monthly':
        return '月报-${it.periodStart.substring(0, 7)}.md';
      case 'weekly':
        return '周报-${it.periodStart}至${it.periodEnd}.md';
      default:
        return '日报-${it.periodStart}.md';
    }
  }

  static String _weekOfYear(DateTime d) {
    final dayOfYear = int.parse(DateFormat('D').format(d));
    final week = ((dayOfYear - d.weekday + 10) / 7).floor();
    return week.clamp(1, 53).toString().padLeft(2, '0');
  }
}



