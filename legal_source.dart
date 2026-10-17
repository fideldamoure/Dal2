import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/decision.dart';

/// واجهة موحّدة لمصدر النصوص القانونية، فيمكنك التبديل بين المحلي والسحابي.
abstract class LegalSource {
  Future<void> init();
  Future<List<LegalText>> search(String query, {int limit = 10});
  Future<LegalText?> byId(String id);
}

/// قاعدة SQLite على الهاتف. تُحمَّل من assets/legal/seed.json عند أول تشغيل،
/// ويمكن استيراد نصوص إضافية لاحقًا عبر [importTexts].
class LocalLegalSource implements LegalSource {
  Database? _db;

  @override
  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'legal.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE legal_texts(
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          reference TEXT,
          article_no TEXT,
          body TEXT
        )''');
    });
    final count = Sqflite.firstIntValue(
        await _db!.rawQuery('SELECT COUNT(*) FROM legal_texts'));
    if (count == 0) {
      final seed = jsonDecode(await rootBundle.loadString('assets/legal/seed.json'))
          as List<dynamic>;
      await importTexts(
          seed.map((e) => LegalText.fromJson(e as Map<String, dynamic>)).toList());
    }
  }

  Future<void> importTexts(List<LegalText> texts) async {
    final batch = _db!.batch();
    for (final t in texts) {
      batch.insert('legal_texts', t.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<LegalText>> search(String query, {int limit = 10}) async {
    final q = '%$query%';
    final rows = await _db!.query('legal_texts',
        where: 'title LIKE ? OR body LIKE ? OR reference LIKE ?',
        whereArgs: [q, q, q],
        limit: limit);
    return rows.map(LegalText.fromJson).toList();
  }

  @override
  Future<LegalText?> byId(String id) async {
    final rows =
        await _db!.query('legal_texts', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : LegalText.fromJson(rows.first);
  }
}

/// مصدر سحابي عبر واجهة REST (مثلًا Supabase/PostgREST على جدول legal_texts).
/// يُضبط الرابط والمفتاح من شاشة الإعدادات، فلا يُخزَّن أي سر في المستودع.
class CloudLegalSource implements LegalSource {
  final String baseUrl; // مثال: https://xxxx.supabase.co/rest/v1
  final String apiKey;

  CloudLegalSource({required this.baseUrl, required this.apiKey});

  Map<String, String> get _headers =>
      {'apikey': apiKey, 'Authorization': 'Bearer $apiKey'};

  @override
  Future<void> init() async {}

  @override
  Future<List<LegalText>> search(String query, {int limit = 10}) async {
    final uri = Uri.parse('$baseUrl/legal_texts').replace(queryParameters: {
      'or': '(title.ilike.*$query*,body.ilike.*$query*)',
      'limit': '$limit',
    });
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('فشل الاتصال بالقاعدة السحابية (${res.statusCode})');
    }
    return (jsonDecode(res.body) as List)
        .map((e) => LegalText.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LegalText?> byId(String id) async {
    final uri = Uri.parse('$baseUrl/legal_texts')
        .replace(queryParameters: {'id': 'eq.$id', 'limit': '1'});
    final res = await http.get(uri, headers: _headers);
    final list = jsonDecode(res.body) as List;
    return list.isEmpty
        ? null
        : LegalText.fromJson(list.first as Map<String, dynamic>);
  }
}
