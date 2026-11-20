import 'package:flutter/material.dart';

/// 日报/月报/年报卡片：左标签、右摘要，颜色比普通记录暗一档
class ReportCard extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback onTap;

  const ReportCard({
    super.key,
    required this.label,
    required this.text,
    required this.onTap,
  });

  String get _summary {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= 46) return flat;
    return '${flat.substring(0, 46)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0D0D0D),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
