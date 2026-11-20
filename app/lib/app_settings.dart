import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'store/app_db.dart';

/// 全局设置：字号倍率、背景图片路径
class AppSettings {
  AppSettings._();

  static final ValueNotifier<double> fontScale = ValueNotifier<double>(1.0);
  static final ValueNotifier<String?> bgImage = ValueNotifier<String?>(null);
  // 背景上那层暗罩的强度：极低…极高
  static final ValueNotifier<double> bgOverlay = ValueNotifier<double>(0.5);

  static Future<void> load() async {
    final s = await AppDb.instance.getSetting('font_scale');
    if (s != null) {
      final v = double.tryParse(s);
      if (v != null) fontScale.value = v;
    }
    final ov = await AppDb.instance.getSetting('bg_overlay');
    if (ov != null) {
      final v = double.tryParse(ov);
      if (v != null) bgOverlay.value = v;
    }
    final bg = await AppDb.instance.getSetting('bg_image');
    if (bg != null && File(bg).existsSync()) {
      bgImage.value = bg;
    }
  }

  static Future<void> setFontScale(double v) async {
    fontScale.value = v;
    await AppDb.instance.setSetting('font_scale', v.toString());
  }

  /// 把选中的图片复制到 App 私有目录当背景，返回新路径
  static Future<String> importBackground(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final old = bgImage.value;
    // 文件名带时间戳：避免 Flutter 按同一路径缓存旧图
    final target = p.join(docs.path,
        'background_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(sourcePath).copy(target);
    if (old != null && old != target) {
      try {
        final f = File(old);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await AppDb.instance.setSetting('bg_image', target);
    bgImage.value = target;
    return target;
  }

  static Future<void> setOverlay(double v) async {
    bgOverlay.value = v;
    await AppDb.instance.setSetting('bg_overlay', v.toString());
  }

  static Future<void> clearBackground() async {
    final cur = bgImage.value;
    if (cur != null) {
      final f = File(cur);
      if (f.existsSync()) await f.delete();
    }
    bgImage.value = null;
    await AppDb.instance.setSetting('bg_image', '');
  }
}


