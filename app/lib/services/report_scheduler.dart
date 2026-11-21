import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../store/app_db.dart';
import 'report_service.dart';

/// 打开 App 时补生成漏掉的报告：日报（次日 01:05）、周报（周一 01:05）、
/// 月报（次月 1 号 01:05）、年报（次年 1 月 1 日后）。
/// 不做后台常驻，HyperOS 也杀不掉它。
class ReportScheduler {
  ReportScheduler._();

  static String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static Future<void> runOnOpen() async {
    const secure = FlutterSecureStorage();
    final apiKey = await secure.read(key: 'api_key');
    if (apiKey == null || apiKey.isEmpty) return; // 没配 key 就不折腾

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 日报：最近两天，过了次日 01:05 就检查一次。
    // 没生成过 → 生成；生成过但那天又添了记录（指纹变了）→ 重生成。
    for (var i = 1; i <= 2; i++) {
      final day = today.subtract(Duration(days: i));
      final readyAt = day.add(const Duration(days: 1, hours: 1, minutes: 5));
      if (now.isBefore(readyAt)) continue;
      final key = _key(day);
      final existing = await AppDb.instance.reportFor('daily', key);
      final sig = await AppDb.instance.daySignature(key);
      final lastSig = await AppDb.instance.getSetting('sig:daily:$key');
      // 老版本生成的日报没有指纹，也当作过期，重新生成一次
      final stale = existing != null && (lastSig == null || lastSig != sig);
      if (existing == null || stale) {
        await ReportService.instance.generateDaily(day);
      }
    }

    // 周报：上周一 ~ 上周日，本周一 01:05 后可生成
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final lastMonday = monday.subtract(const Duration(days: 7));
    final weeklyReady = monday.add(const Duration(hours: 1, minutes: 5));
    if (!now.isBefore(weeklyReady)) {
      final existing = await AppDb.instance.reportFor('weekly', _key(lastMonday));
      if (existing == null) {
        await ReportService.instance.generateWeekly(lastMonday);
      }
    }

    // 月报：上个月，本月 1 号 01:05 后可生成
    final firstThisMonth = DateTime(now.year, now.month, 1);
    final monthlyReady = firstThisMonth.add(const Duration(hours: 1, minutes: 5));
    if (!now.isBefore(monthlyReady)) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final existing =
          await AppDb.instance.reportFor('monthly', _key(lastMonth));
      if (existing == null) {
        await ReportService.instance
            .generateMonthly(lastMonth.year, lastMonth.month);
      }
    }

    // 年报：去年，今年 1 月 1 日后可生成
    final lastYear = now.year - 1;
    final existing = await AppDb.instance.reportFor('yearly', '$lastYear-01-01');
    if (existing == null) {
      await ReportService.instance.generateYearly(lastYear);
    }
  }
}
