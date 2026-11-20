import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../store/app_db.dart';

/// 本地语音转文字（Vosk，全程离线）。
/// 模型由用户导入（大模型），不打包进 APK。
class AsrService {
  static const _channel = MethodChannel('whale_diary/asr');
  static const _settingKey = 'asr_model_dir';

  static bool _ready = false;
  static String? _modelPath;

  static void Function(String partial)? onPartial;
  static void Function(String finalText)? onFinal;
  static void Function(String error)? onError;

  static bool isModelDir(String path) =>
      File(p.join(path, 'am', 'final.mdl')).existsSync();

  static String? _findModelDir(String root, {int depth = 2}) {
    if (isModelDir(root)) return root;
    if (depth <= 0) return null;
    final dir = Directory(root);
    if (!dir.existsSync()) return null;
    for (final item in dir.listSync()) {
      if (item is! Directory) continue;
      final found = _findModelDir(item.path, depth: depth - 1);
      if (found != null) return found;
    }
    return null;
  }

  static Future<String?> _resolveModelPath() async {
    final imported = await AppDb.instance.getSetting(_settingKey);
    if (imported != null && imported.isNotEmpty && isModelDir(imported)) {
      return imported;
    }
    return null;
  }

  static Future<bool> hasModel() async => await _resolveModelPath() != null;

  static Future<bool> init() async {
    if (_ready) return true;
    try {
      _modelPath ??= await _resolveModelPath();
      final path = _modelPath;
      if (path == null) return false;

      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'partial':
            onPartial?.call(call.arguments as String);
            break;
          case 'final':
            onFinal?.call(call.arguments as String);
            break;
          case 'error':
            onError?.call(call.arguments as String);
            break;
        }
        return null;
      });
      final ok = await _channel.invokeMethod<bool>('init', {'path': path});
      _ready = ok ?? false;
      return _ready;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> start() async {
    final perm =
        await _channel.invokeMethod<bool>('ensurePermission') ?? false;
    if (!perm) return false;
    await init();
    await _channel.invokeMethod('start');
    return true;
  }

  static Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }

  static Future<void> release() async {
    try {
      await _channel.invokeMethod('release');
    } catch (_) {}
    _ready = false;
    _modelPath = null;
  }

  /// 解压用户选的模型 zip，找到模型目录并设为当前模型
  static Future<String?> importZip(String zipPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final dest = p.join(docs.path, 'models',
        DateTime.now().millisecondsSinceEpoch.toString());
    Directory(dest).createSync(recursive: true);
    final ok = await _channel.invokeMethod<bool>('unzip', {
      'zipPath': zipPath,
      'destDir': dest,
    });
    // 解压完就把选择器缓存里的 zip 删掉，1.2G 一份很占地方
    try {
      final tmp = await getTemporaryDirectory();
      if (p.isWithin(p.normalize(tmp.path), p.normalize(zipPath))) {
        final f = File(zipPath);
        if (f.existsSync()) f.deleteSync();
      }
    } catch (_) {}
    if (ok != true) return null;
    final modelDir = _findModelDir(dest);
    if (modelDir == null) return null;
    await AppDb.instance.setSetting(_settingKey, modelDir);
    await release();
    await cleanupOldModels();
    // 最后校验一次：清理后模型还在，才算导入成功
    if (await currentModelName() == null) return null;
    return modelDir;
  }

  /// 清掉导入过的旧模型目录，只留当前在用的那份（一次导入约 2GB，重复导入会爆仓）
  static Future<int> cleanupOldModels() async {
    final docs = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(docs.path, 'models'));
    if (!modelsDir.existsSync()) return 0;

    final current = p.normalize(await AppDb.instance.getSetting(_settingKey) ?? '');
    var freed = 0;
    for (final item in modelsDir.listSync()) {
      if (item is! Directory) continue;
      final childPath = p.normalize(item.path);
      // 当前模型可能就在这一层，也可能在这一层的子目录里（导入的 zip 常带根目录）
      final keep = current.isNotEmpty &&
          (current == childPath || p.isWithin(childPath, current));
      if (keep) continue;
      try {
        item.deleteSync(recursive: true);
        freed++;
      } catch (_) {}
    }

    // 早期版本用的内置小模型目录
    final legacy = Directory(p.join(docs.path, 'vosk-model-small-cn-0.22'));
    if (legacy.existsSync()) {
      try {
        legacy.deleteSync(recursive: true);
        freed++;
      } catch (_) {}
    }

    // 文件选择器会把选中的 zip 复制进缓存，1.2G 一份，一并清掉
    try {
      final tmp = await getTemporaryDirectory();
      for (final f in tmp.listSync(recursive: true).whereType<File>()) {
        if (p.extension(f.path).toLowerCase() == '.zip' &&
            f.lengthSync() > 50 * 1024 * 1024) {
          f.deleteSync();
          freed++;
        }
      }
    } catch (_) {}
    return freed;
  }

  static Future<String?> currentModelName() async {
    final path = await _resolveModelPath();
    if (path == null) return null;
    return p.basename(path);
  }
}







