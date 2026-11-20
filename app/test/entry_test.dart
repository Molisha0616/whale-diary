import 'package:flutter_test/flutter_test.dart';
import 'package:whale_diary/models/entry.dart';

void main() {
  test('Entry map round-trip', () {
    const e = Entry(day: '2026-11-19', createdAt: 1000, body: 'test');
    final m = e.toMap();
    final back = Entry.fromMap({...m, 'id': 1});
    expect(back.day, '2026-11-19');
    expect(back.body, 'test');
    expect(back.type, 'entry');
  });
}
