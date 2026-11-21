import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_settings.dart';
import '../../services/asr_service.dart';
import '../../services/backup_service.dart';
import '../../services/restore_service.dart';
import '../../services/report_service.dart';
import '../../store/app_db.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _secure = const FlutterSecureStorage();
  final _keyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController(text: 'deepseek-flash');
  final _baseCtrl = TextEditingController(text: 'https://api.deepseek.com');
  final _picker = ImagePicker();

  bool _hasKey = false;
  bool _generating = false;
  bool _photosInReport = true;
  String? _modelName;
  bool _importing = false;
  bool _backingUp = false;
  bool _restoring = false;
  bool _cleaning = false;
  String _testResult = '';
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    _baseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await _secure.read(key: 'api_key');
    final model = await AppDb.instance.getSetting('api_model');
    final base = await AppDb.instance.getSetting('api_base');
    final photos = await AppDb.instance.getSetting('report_photos');
    final modelName = await AsrService.currentModelName();
    if (!mounted) return;
    setState(() {
      _hasKey = key != null && key.isNotEmpty;
      if (model != null && model.isNotEmpty) _modelCtrl.text = model;
      if (base != null && base.isNotEmpty) _baseCtrl.text = base;
      _photosInReport = photos != '0';
      _modelName = modelName;
    });
  }

  Future<void> _saveKey() async {
    final v = _keyCtrl.text.trim();
    if (v.isEmpty) return;
    await _secure.write(key: 'api_key', value: v);
    _keyCtrl.clear();
    setState(() => _hasKey = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('密钥已保存到系统 KeyStore')));
  }

  Future<void> _clearKey() async {
    await _secure.delete(key: 'api_key');
    setState(() {
      _hasKey = false;
      _testResult = '';
    });
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = '测试中…';
    });
    final key = await _secure.read(key: 'api_key') ?? _keyCtrl.text.trim();
    final base = _baseCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    await AppDb.instance.setSetting('api_model', model);
    await AppDb.instance.setSetting('api_base', base);
    if (key.isEmpty) {
      setState(() {
        _testing = false;
        _testResult = '没有密钥，先填一个再测';
      });
      return;
    }
    try {
      final resp = await http
          .get(Uri.parse('$base/models'),
              headers: {'Authorization': 'Bearer $key'})
          .timeout(const Duration(seconds: 12));
      setState(() {
        _testing = false;
        _testResult = resp.statusCode == 200
            ? '连接成功（HTTP 200，模型 $model）'
            : '连接失败：HTTP ${resp.statusCode}';
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testResult = '连接失败：${e.runtimeType}';
      });
    }
  }

  Future<void> _pickBackground() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (picked == null) return;
    await AppSettings.importBackground(picked.path);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _section('外观'),
          _fontRow(),
          const SizedBox(height: 16),
          _bgRow(),
          if (AppSettings.bgImage.value != null) ...[
            const SizedBox(height: 12),
            _section('背景明暗'),
            const SizedBox(height: 6),
            _overlayRow(),
          ],
          const SizedBox(height: 24),
          _section('语音模型（离线转写）'),
          const SizedBox(height: 6),
          Text(
            _modelName == null ? '未导入' : '当前：$_modelName',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '导入官方大模型 vosk-model-cn-0.22.zip（约 1.3GB），解压后占 2GB 左右，'
            '导入时别退出，几分钟。',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _importing ? null : _importModel,
            icon: const Icon(Icons.memory_outlined, size: 18),
            label: Text(_importing ? '导入中…' : '导入语音模型（.zip）'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cleaning ? null : _cleanupStorage,
            icon: const Icon(Icons.cleaning_services_outlined, size: 18),
            label: Text(_cleaning ? '清理中…' : '清理旧模型与缓存'),
          ),
          const SizedBox(height: 24),
          _section('API（日报／周报／月报／年报用）'),
          const SizedBox(height: 8),
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _hasKey ? '密钥已保存（输入新的可替换）' : '填入 API Key',
              hintText: 'sk-…',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _saveKey,
                  child: const Text('保存密钥'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _hasKey ? _clearKey : null,
                  child: const Text('清空密钥'),
                ),
              ),
            ],
          ),
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: '模型名（官方：deepseek-flash / deepseek-v4-pro）',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _baseCtrl,
            decoration: const InputDecoration(
              labelText: '接口地址',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _testing ? null : _test,
                child: Text(_testing ? '测试中…' : '测试连接'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _testResult,
                  style: TextStyle(
                    fontSize: 12,
                    color: _testResult.startsWith('连接成功')
                        ? const Color(0xFF6FCF97)
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('报告附图（512px 缩略图）'),
            subtitle: Text(
              '关掉后报告只发文字，照片不出手机',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            value: _photosInReport,
            onChanged: (v) async {
              setState(() => _photosInReport = v);
              await AppDb.instance.setSetting('report_photos', v ? '1' : '0');
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _generating ? null : _generatePreview,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(_generating ? '生成中…' : '立即生成今天的日报（预览）'),
          ),
          const SizedBox(height: 24),
          _section('备份'),
          const SizedBox(height: 6),
          Text(
            '导出会把文字、照片、评论、报告打成一个 zip；密钥和语音模型不进备份。',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _backingUp ? null : _exportBackup,
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: Text(_backingUp ? '打包中…' : '导出备份（.zip）'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _restoring ? null : _restoreBackup,
            icon: const Icon(Icons.settings_backup_restore, size: 18),
            label: Text(_restoring ? '恢复中…' : '从备份恢复（.zip）'),
          ),
          const SizedBox(height: 24),
          _section('关于'),
          const SizedBox(height: 6),
          Text(
            '鲸鱼日记 1.1.0 · 全本地存储，照片在 App 私有目录，密钥在系统 KeyStore。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('覆盖本机数据？'),
        content: const Text('恢复会用备份里的内容替换现在这台手机上的记录、照片、评论和报告。做了就回不去，建议先导出一份当前的。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('覆盖恢复'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _restoring = true);
    try {
      final msg = await RestoreService.restore(path);
      if (!mounted) return;
      setState(() => _restoring = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoring = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    }
  }
  Future<void> _exportBackup() async {
    setState(() => _backingUp = true);
    try {
      final file = await BackupService.create();
      if (!mounted) return;
      setState(() => _backingUp = false);
      await Share.shareXFiles([XFile(file.path)], text: '鲸鱼日记备份');
    } catch (e) {
      if (!mounted) return;
      setState(() => _backingUp = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }
  Future<void> _cleanupStorage() async {
    setState(() => _cleaning = true);
    final freed = await AsrService.cleanupOldModels();
    final name = await AsrService.currentModelName();
    if (!mounted) return;
    setState(() {
      _cleaning = false;
      _modelName = name;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('清理完成，删掉 $freed 项')),
    );
  }
  Future<void> _importModel() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() => _importing = true);
    final dir = await AsrService.importZip(path);
    if (!mounted) return;
    setState(() => _importing = false);
    if (dir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导入失败：zip 里没找到 am/final.mdl')),
      );
      return;
    }
    final name = await AsrService.currentModelName();
    if (!mounted) return;
    setState(() => _modelName = name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(name == null ? '导入完成但目录校验失败，请再试一次' : '模型已导入：$name'),
      ),
    );
  }
  Future<void> _generatePreview() async {
    if (_generating) return;
    setState(() => _generating = true);
    ReportResult r;
    try {
      r = await ReportService.instance.generateDaily(DateTime.now());
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('生成失败：$e')));
      return;
    }
    if (!mounted) return;
    setState(() => _generating = false);
    if (!r.ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.body)));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('今天的日报（预览）'),
        content: SingleChildScrollView(
          child: SelectableText(r.body,
              style: const TextStyle(fontSize: 14, height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
  Widget _section(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      );

  Widget _fontRow() {
    return ValueListenableBuilder<double>(
      valueListenable: AppSettings.fontScale,
      builder: (context, current, _) => Wrap(
        spacing: 8,
        children: [
          for (final (label, v) in [('小', 1.0), ('中', 1.12), ('大', 1.26)])
            ChoiceChip(
              label: Text(label),
              selected: (current - v).abs() < 0.01,
              onSelected: (_) => AppSettings.setFontScale(v),
            ),
        ],
      ),
    );
  }

  Widget _overlayRow() {
    const options = [
      ('极低', 0.2),
      ('低', 0.35),
      ('中', 0.5),
      ('高', 0.65),
      ('极高', 0.8),
    ];
    return ValueListenableBuilder<double>(
      valueListenable: AppSettings.bgOverlay,
      builder: (context, current, _) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, v) in options)
            ChoiceChip(
              label: Text(label),
              selected: (current - v).abs() < 0.01,
              onSelected: (_) => AppSettings.setOverlay(v),
            ),
        ],
      ),
    );
  }

  Widget _bgRow() {
    final bg = AppSettings.bgImage.value;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: bg == null
              ? Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xFF1C1C1C),
                  child: const Icon(Icons.image_outlined, size: 20),
                )
              : Image.file(File(bg),
                  width: 64,
                  height: 64,
                  cacheWidth: 192,
                  cacheHeight: 192,
                  fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        TextButton(onPressed: _pickBackground, child: const Text('选择背景')),
        TextButton(
          onPressed: bg == null
              ? null
              : () async {
                  await AppSettings.clearBackground();
                  setState(() {});
                },
          child: const Text('移除'),
        ),
      ],
    );
  }
}













