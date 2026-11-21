import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/entry.dart';

class EntryCard extends StatelessWidget {
  final Entry entry;
  final String? photoPath;
  final VoidCallback onTap;

  const EntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
    );
    final isPlan = entry.type == 'plan';
    final isMessage = entry.type == 'message';

    return Material(
      color: const Color(0xFF141414),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  if (isPlan) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25405A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('计划',
                          style: TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ],
                  if (isMessage) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC0392B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('寄语',
                          style: TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ],
                  if (entry.planState != null) ...[
                    const SizedBox(width: 6),
                    Icon(
                      entry.planState == 'done'
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      size: 14,
                      color: entry.planState == 'done'
                          ? const Color(0xFF6FCF97)
                          : const Color(0xFFEB5757),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photoPath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(photoPath!),
                        width: 56,
                        height: 56,
                        cacheWidth: 168,
                        cacheHeight: 168,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(Icons.broken_image_outlined, size: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      entry.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

