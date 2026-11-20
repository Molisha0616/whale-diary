import 'package:flutter/material.dart';

import '../../services/asr_service.dart';

/// 语音输入弹层：本地转写，实时显示，点「完成」把文字带回发布页
class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key});

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> {
  final List<String> _finals = [];
  String _partial = '';
  String _status = '正在加载模型，第一次会久一点…';
  bool _started = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    AsrService.onPartial = (t) {
      if (!mounted) return;
      setState(() => _partial = t);
    };
    AsrService.onFinal = (t) {
      if (!mounted) return;
      setState(() {
        _finals.add(_clean(t));
        _partial = '';
      });
    };
    AsrService.onError = (e) {
      if (!mounted) return;
      setState(() => _status = '出错了：$e');
    };

    if (!await AsrService.hasModel()) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '还没有导入语音模型，先去设置里导入';
      });
      return;
    }
    final ok = await AsrService.init();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _loading = false;
        _status = '模型加载失败';
      });
      return;
    }
    final started = await AsrService.start();
    if (!mounted) return;
    setState(() {
      _started = started;
      _loading = false;
      _status = started ? '正在听，说完点「完成」' : '没有麦克风权限';
    });
  }

  static String _clean(String s) {
    var t = s.replaceAllMapped(
      RegExp(r'([\\u4e00-\\u9fff])\\s+(?=[\\u4e00-\\u9fff])'),
      (m) => m[1] ?? '',
    );
    t = t.replaceAll(RegExp(r'\\s+'), ' ').trim();
    return t;
  }

  Future<void> _finish() async {
    await AsrService.stop();
    final tail = _partial.isEmpty ? '' : _clean(_partial);
    final text = [..._finals, if (tail.isNotEmpty) tail].join('，');
    if (!mounted) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final text = [..._finals, _partial].where((s) => s.isNotEmpty).join('，');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Text(
              _status,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 90),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                text.isEmpty ? '……' : text,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await AsrService.stop();
                      if (mounted) Navigator.of(context).pop('');
                    },
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _started ? _finish : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2BB673),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



