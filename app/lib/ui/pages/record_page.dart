import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/entry.dart';
import '../../models/entry_comment.dart';
import '../../models/entry_media.dart';
import '../../store/app_db.dart';
import 'video_page.dart';

class RecordPage extends StatefulWidget {
  final int entryId;
  const RecordPage({super.key, required this.entryId});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  Entry? _entry;
  List<EntryComment> _comments = [];
  final _input = TextEditingController();
  List<EntryMedia> _media = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final e = await AppDb.instance.entryById(widget.entryId);
    final cs = await AppDb.instance.commentsForEntry(widget.entryId);
    final ms = await AppDb.instance.mediaForEntry(widget.entryId);
    if (!mounted) return;
    setState(() {
      _entry = e;
      _comments = cs;
      _media = ms;
      _loading = false;
    });
  }

  Future<void> _sendComment() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await AppDb.instance.insertComment(EntryComment(
      entryId: widget.entryId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      body: text,
    ));
    _input.clear();
    FocusScope.of(context).unfocus();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('记录')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      if (_entry != null) ...[
                        Text(
                          DateFormat('yyyy年M月d日 HH:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(
                                _entry!.createdAt),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_media.isNotEmpty) ...[
                          _mediaStrip(),
                          const SizedBox(height: 12),
                        ],
                        SelectableText(
                          _entry!.body,
                          style: const TextStyle(fontSize: 16, height: 1.6),
                        ),
                        if (_entry!.type == 'plan')
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _planMark(),
                          ),
                      ],
                      const SizedBox(height: 20),
                      Divider(color: Colors.white.withOpacity(0.08)),
                      const SizedBox(height: 12),
                      if (_comments.isEmpty)
                        Text(
                          '还没有评论',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ..._comments.map(_commentTile),
                    ],
                  ),
                ),
                _inputBar(),
              ],
            ),
    );
  }

  Widget _planMark() {
    final applied = _entry!.planState != null;
    final day = DateTime.parse(_entry!.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final canMark = !day.isAfter(today); // 只有今天（含更早未确认的补标）才能确认

    if (!canMark) {
      return Text(
        '到了那天再确认',
        style: TextStyle(
          fontSize: 13,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      );
    }

    return Row(
      children: [
        if (!applied) ...[
          OutlinedButton.icon(
            onPressed: () => _mark('done'),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('完成'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6FCF97),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _mark('undone'),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('未完成'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEB5757),
            ),
          ),
        ] else
          Text(
            _entry!.planState == 'done' ? '已标记：完成' : '已标记：未完成',
            style: TextStyle(
              fontSize: 13,
              color: _entry!.planState == 'done'
                  ? const Color(0xFF6FCF97)
                  : const Color(0xFFEB5757),
            ),
          ),
      ],
    );
  }

  Future<void> _mark(String state) async {
    await AppDb.instance.setPlanState(_entry!.id!, state);
    _load();
  }

  Widget _commentTile(EntryComment c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('yyyy年M月d日 HH:mm').format(
                DateTime.fromMillisecondsSinceEpoch(c.createdAt)),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.35),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(c.body, style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1C1C1C))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => _sendComment(),
                decoration: InputDecoration(
                  hintText: '补一句…',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF161616),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ),
            IconButton(
              onPressed: _sendComment,
              icon: const Icon(Icons.send, size: 20),
              color: const Color(0xFF4FA3D1),
            ),
          ],
        ),
      ),
    );
  }
  Widget _mediaStrip() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = _media[i];
          final isVideo = m.kind == 'video';
          return GestureDetector(
            onTap: () {
              if (isVideo) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VideoPage(path: m.path),
                ));
              } else {
                _openViewer(i);
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isVideo
                  ? Container(
                      width: 96,
                      height: 96,
                      color: const Color(0xFF1C1C1C),
                      child: const Icon(Icons.play_circle_outline,
                          size: 28, color: Colors.white70),
                    )
                  : Image.file(
                      File(m.path),
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 96,
                        height: 96,
                        color: const Color(0xFF1C1C1C),
                        child: const Icon(Icons.broken_image_outlined,
                            size: 16, color: Colors.white24),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  void _openViewer(int index) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _PhotoViewer(
        paths: _media.map((e) => e.path).toList(),
        initial: index,
      ),
    ));
  }
}
class _PhotoViewer extends StatefulWidget {
  final List<String> paths;
  final int initial;

  const _PhotoViewer({required this.paths, required this.initial});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initial;
    _ctrl = PageController(initialPage: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.paths.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.file(File(widget.paths[i]), fit: BoxFit.contain),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          if (widget.paths.length > 1)
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Text(
                '${_index + 1} / ${widget.paths.length}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
        ],
      ),
    );
  }
}



