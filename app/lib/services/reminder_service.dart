import 'package:intl/intl.dart';

import '../models/app_message.dart';
import '../store/app_db.dart';

/// 每天 01:05 之后，检查前一天及更早未确认的计划，生成站内提醒（「你的提醒」）。
/// 打开 App 时兜底补生成，不依赖后台任务。
Future<int> runPlanReminders() async {
  final now = DateTime.now();
  final today = DateFormat('yyyy-MM-dd').format(now);
  final plans = await AppDb.instance.unconfirmedPlansBefore(today);

  var created = 0;
  for (final p in plans) {
    final id = p.id;
    if (id == null) continue;
    if (await AppDb.instance.hasPlanReminder(id)) continue;
    final dayText = DateFormat('M月d日').format(DateTime.parse(p.day));
    await AppDb.instance.insertMessage(AppMessage(
      createdAt: now.millisecondsSinceEpoch,
      kind: 'plan_unconfirmed',
      title: '计划没确认',
      body: '$dayText 的计划「${p.body}」还没标完成或未完成。',
      entryId: id,
    ));
    created++;
  }
  return created;
}
