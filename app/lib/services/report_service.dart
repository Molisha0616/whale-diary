import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/app_message.dart';
import '../models/entry.dart';
import '../models/entry_media.dart';
import '../store/app_db.dart';

class ReportResult {
  final String body;
  final bool ok;
  const ReportResult(this.body, {this.ok = true});
}

enum ReportKind { daily, weekly, monthly, yearly }

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final _secure = const FlutterSecureStorage();

  Future<String?> _key() async {
    final k = await _secure.read(key: 'api_key');
    return (k == null || k.isEmpty) ? null : k;
  }

  Future<String> _systemPrompt() async {
    final extra = await AppDb.instance.getSetting('report_style_note');
    return '''
你是肥鱼，蓝色鲸鱼娘女仆，说话直、有立场，先看事实再下判断，不和稀泥。
写东西的要求：不编造记录里没有的事；先摆事实，再定性；定性要落到「这段是在积累还是在空转」；
优缺点都看，但看完必须给判断；最后给 1 条动作，别堆建议。用中文，不用 markdown 标题。
${extra ?? ''}''';
  }

  String _entryLine(Entry e) {
    final t = DateFormat('HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(e.createdAt));
    final kind = switch (e.type) {
      'plan' => '计划',
      'message' => '寄语',
      _ => '记录',
    };
    final state = e.planState == null
        ? ''
        : (e.planState == 'done' ? '（已完成）' : '（未完成）');
    return '[${e.day} $t][$kind$state] ${e.body}';
  }

  Future<ui.Image> _decode(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// 把本地照片缩到 512 宽，转成 data URL，给多模态接口用
  Future<List<Map<String, Object>>> _imageParts(List<EntryMedia> media) async {
    final parts = <Map<String, Object>>[];
    for (final m in media.take(3)) {
      try {
        final img = await _decode(m.path);
        final scale = 512 / img.width;
        final resized = scale < 1
            ? await _resize(img, 512, (img.height * scale).round())
            : img;
        final data =
            await resized.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) continue;
        final b64 = base64Encode(data.buffer.asUint8List());
        parts.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/png;base64,$b64'},
        });
      } catch (_) {
        // 单张图读不出来就跳过，不拖垮整份报告
      }
    }
    return parts;
  }

  Future<ui.Image> _resize(ui.Image src, int w, int h) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    return recorder.endRecording().toImage(w, h);
  }

  Future<ReportResult> _call(List<Map<String, Object>> messages) async {
    final key = await _key();
    if (key == null) {
      return const ReportResult('没有密钥，先在设置里填 API Key', ok: false);
    }
    final model =
        await AppDb.instance.getSetting('api_model') ?? 'deepseek-flash';
    final base =
        await AppDb.instance.getSetting('api_base') ?? 'https://api.deepseek.com';

    Future<http.Response> send(bool withImages) {
      final payload = {
        'model': model,
        'messages': withImages
            ? messages
            : messages
                .map((m) => {
                      ...m,
                      'content': m['content'] is List
                          ? (m['content'] as List)
                              .where((p) => p is Map && p['type'] == 'text')
                              .map((p) => (p as Map)['text'])
                              .join('\n')
                          : m['content'],
                    })
                .toList(),
        'temperature': 0.7,
        'stream': false,
      };
      return http
          .post(
            Uri.parse('$base/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 90));
    }

    http.Response resp;
    try {
      resp = await send(true);
      if (resp.statusCode == 400 || resp.statusCode == 422) {
        // 模型不收图就退回纯文字
        resp = await send(false);
      }
    } catch (e) {
      return ReportResult('网络或超时：${e.runtimeType}', ok: false);
    }

    if (resp.statusCode != 200) {
      return ReportResult('接口返回 HTTP ${resp.statusCode}', ok: false);
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    final text = decoded['choices']?[0]?['message']?['content'] as String?;
    if (text == null || text.trim().isEmpty) {
      return const ReportResult('模型返回空内容', ok: false);
    }
    return ReportResult(text.trim());
  }

  Future<bool> _photosEnabled() async {
    final v = await AppDb.instance.getSetting('report_photos');
    return v != '0';
  }

  Future<List<EntryMedia>> _photosFor(List<Entry> entries) async {
    final ids = entries.map((e) => e.id).whereType<int>().toList();
    final media = await AppDb.instance.mediaForEntryIds(ids);
    return media.where((m) => m.kind == 'photo').toList();
  }

  Future<ReportResult> generateDaily(DateTime day) async {
    final dayKey = DateFormat('yyyy-MM-dd').format(day);
    final entries = await AppDb.instance.entriesForDay(dayKey);
    if (entries.isEmpty) return ReportResult('$dayKey 没有记录，写不出日报', ok: false);

    final photos = await _photosFor(entries);
    final imageParts =
        await _photosEnabled() ? await _imageParts(photos) : <Map<String, Object>>[];
    final text = StringBuffer()
      ..writeln('日期：$dayKey')
      ..writeln('记录条数：${entries.length}')
      ..writeln('---');
    for (final e in entries) {
      text.writeln(_entryLine(e));
    }
    text.writeln('---');
    text.writeln('写今天的日报：①今天干了什么 ②观察（断档/过量）③定性 ④最多一条明天的动作。300 字内。');
    if (imageParts.isNotEmpty) {
      text.writeln('附了当天 ${imageParts.length} 张照片，能看出来就写进去，看不出来就别说。');
    }

    final result = await _call([
      {'role': 'system', 'content': await _systemPrompt()},
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': text.toString()},
          ...imageParts,
        ],
      },
    ]);
    if (result.ok) {
      await AppDb.instance.insertReport(
        kind: 'daily',
        periodStart: dayKey,
        periodEnd: dayKey,
        body: result.body,
        model: null,
      );
      await AppDb.instance.insertMessage(AppMessage(
        createdAt: DateTime.now().millisecondsSinceEpoch,
        kind: 'daily',
        title: '$dayKey 日报',
        body: result.body,
      ));
    }
    return result;
  }

  Future<ReportResult> generateWeekly(DateTime monday) async {
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = start.add(const Duration(days: 6));
    final startKey = DateFormat('yyyy-MM-dd').format(start);
    final endKey = DateFormat('yyyy-MM-dd').format(end);
    final entries = await AppDb.instance.entriesBetween(startKey, endKey);
    if (entries.isEmpty) {
      return ReportResult('$startKey ~ $endKey 没有记录，写不出周报', ok: false);
    }
    final photos = await _photosFor(entries);
    final imageParts =
        await _photosEnabled() ? await _imageParts(photos) : <Map<String, Object>>[];
    final text = StringBuffer()
      ..writeln('周期：$startKey ~ $endKey')
      ..writeln('记录条数：${entries.length}')
      ..writeln('---');
    for (final e in entries) {
      text.writeln(_entryLine(e));
    }
    text.writeln('---');
    text.writeln('写这周的周报：①这周干了什么 ②哪些在推进、哪些断档 '
        '③定性：在积累还是空转 ④主旋律表扬还是批评 ⑤一到两条下周动作。300 字内。');

    final result = await _call([
      {'role': 'system', 'content': await _systemPrompt()},
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': text.toString()},
          ...imageParts,
        ],
      },
    ]);
    if (result.ok) {
      await AppDb.instance.insertReport(
        kind: 'weekly',
        periodStart: startKey,
        periodEnd: endKey,
        body: result.body,
        model: null,
      );
      await AppDb.instance.insertMessage(AppMessage(
        createdAt: DateTime.now().millisecondsSinceEpoch,
        kind: 'weekly',
        title: '$startKey ~ $endKey 周报',
        body: result.body,
      ));
    }
    return result;
  }
  Future<ReportResult> generateMonthly(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final startKey = DateFormat('yyyy-MM-dd').format(start);
    final endKey = DateFormat('yyyy-MM-dd').format(end);
    final entries = await AppDb.instance.entriesBetween(startKey, endKey);
    if (entries.isEmpty) {
      return ReportResult('$year年$month月没有记录，写不出月报', ok: false);
    }

    final photos = await _photosFor(entries);
    final imageParts =
        await _photosEnabled() ? await _imageParts(photos) : <Map<String, Object>>[];
    final text = StringBuffer()
      ..writeln('周期：$startKey ~ $endKey')
      ..writeln('记录条数：${entries.length}')
      ..writeln('---');
    for (final e in entries) {
      text.writeln(_entryLine(e));
    }
    text.writeln('---');
    text.writeln('写这个月的月报：①这月干了什么 ②哪些在推进、哪些断档 '
        '③定性：在积累还是空转 ④主旋律该表扬为主还是批评为主 ⑤一到两条下月动作。400 字内。');

    final result = await _call([
      {'role': 'system', 'content': await _systemPrompt()},
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': text.toString()},
          ...imageParts,
        ],
      },
    ]);
    if (result.ok) {
      await AppDb.instance.insertReport(
        kind: 'monthly',
        periodStart: startKey,
        periodEnd: endKey,
        body: result.body,
        model: null,
      );
      await AppDb.instance.insertMessage(AppMessage(
        createdAt: DateTime.now().millisecondsSinceEpoch,
        kind: 'monthly',
        title: '$year年$month月 月报',
        body: result.body,
      ));
    }
    return result;
  }

  Future<ReportResult> generateYearly(int year) async {
    final startKey = '$year-01-01';
    final endKey = '$year-12-31';
    final entries = await AppDb.instance.entriesBetween(startKey, endKey);
    if (entries.isEmpty) {
      return ReportResult('$year 年没有记录，写不出年报', ok: false);
    }
    final text = StringBuffer()
      ..writeln('周期：$startKey ~ $endKey')
      ..writeln('记录条数：${entries.length}')
      ..writeln('---');
    for (final e in entries) {
      text.writeln(_entryLine(e));
    }
    text.writeln('---');
    text.writeln('写这一年的年报：①全年大线条 ②推进与断档 '
        '③定性：这一年是在积累还是空转 ④主旋律表扬还是批评 ⑤下一年一到两条动作。500 字内。');

    final result = await _call([
      {'role': 'system', 'content': await _systemPrompt()},
      {'role': 'user', 'content': text.toString()},
    ]);
    if (result.ok) {
      await AppDb.instance.insertReport(
        kind: 'yearly',
        periodStart: startKey,
        periodEnd: endKey,
        body: result.body,
        model: null,
      );
      await AppDb.instance.insertMessage(AppMessage(
        createdAt: DateTime.now().millisecondsSinceEpoch,
        kind: 'yearly',
        title: '$year 年报',
        body: result.body,
      ));
    }
    return result;
  }
}


