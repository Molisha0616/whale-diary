import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/entry.dart';
import '../../models/entry_media.dart';
import '../../services/media_service.dart';
import '../widgets/voice_sheet.dart';
import '../../store/app_db.dart';

class ComposePage extends StatefulWidget {
  final DateTime day;
  const ComposePage({super.key, required this.day});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  final List<XFile> _videos = [];
  bool _saving = false;

  DateTime get _dayOnly =>
      DateTime(widget.day.year, widget.day.month, widget.day.day);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isTomorrow => _dayOnly == _today.add(const Duration(days: 1));

  bool get _isFuture => _dayOnly.isAfter(_today);

  /// 明天＝计划；今天＝记录；更远的将来＝寄语
  String get _type {
    if (_isTomorrow) return 'plan';
    if (_isFuture) return 'message';
    return 'entry';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍一张'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2000,
      );
      if (picked == null) return;
      setState(() => _photos.add(picked));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加照片失败：$e')),
      );
    }
  }

  Future<void> _startVoice() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F0F0F),
      isScrollControlled: true,
      builder: (_) => const VoiceSheet(),
    );
    if (text == null || text.isEmpty) return;
    final cur = _controller.text.trim();
    _controller.text = cur.isEmpty ? text : '$cur\n$text';
  }
  Future<void> _addVideo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('录一段（最长 15 秒）'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('从相册选'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 15),
      );
      if (picked == null) return;
      setState(() => _videos.add(picked));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加视频失败：$e')),
      );
    }
  }
  Future<void> _publish() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _photos.isEmpty && _videos.isEmpty) return;
    if (_saving) return;
    setState(() => _saving = true);

    final entryId = await AppDb.instance.insertEntry(Entry(
      day: DateFormat('yyyy-MM-dd').format(widget.day),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      body: text,
      type: _type,
    ));

    for (final x in _photos) {
      final path = await MediaService.instance.importPhoto(x.path);
      await AppDb.instance.insertMedia(EntryMedia(
        entryId: entryId,
        kind: 'photo',
        path: path,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    for (final v in _videos) {
      final path = await MediaService.instance.importFile(v.path, ext: '.mp4');
      await AppDb.instance.insertMedia(EntryMedia(
        entryId: entryId,
        kind: 'video',
        path: path,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = DateFormat('M月d日').format(widget.day);
    return Scaffold(
      appBar: AppBar(title: Text('写 $title')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  _toolButton(Icons.image_outlined, '照片', _addPhoto),
                  const SizedBox(width: 12),
                  _toolButton(Icons.videocam_outlined, '视频', _addVideo),
                  const SizedBox(width: 12),
                  _toolButton(Icons.mic_none_outlined, '语音', _startVoice),
                ],
              ),
              if (_photos.isNotEmpty)
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 10),
                    itemCount: _photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_photos[i].path),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_videos.isNotEmpty)
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 10),
                    itemCount: _videos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.play_circle_outline,
                              size: 28, color: Colors.white70),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _videos.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  decoration: InputDecoration(
                    hintText: _isTomorrow
                        ? '明天准备干什么？'
                        : (_isFuture ? '给那天留句话…' : '今天干了什么？'),
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    DateFormat('HH:mm').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _saving ? null : _publish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2BB673),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('发布', style: TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 22, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }
}



