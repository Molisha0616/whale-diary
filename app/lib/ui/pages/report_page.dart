import 'package:flutter/material.dart';

class ReportPage extends StatelessWidget {
  final String label;
  final String body;

  const ReportPage({super.key, required this.label, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(label, style: const TextStyle(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          SelectableText(
            body,
            style: const TextStyle(fontSize: 15, height: 1.8),
          ),
        ],
      ),
    );
  }
}
