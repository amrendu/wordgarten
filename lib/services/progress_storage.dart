import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

abstract class ProgressStorage {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
  Future<void> close();
}

class LocalProgressStorage implements ProgressStorage {
  Database? _db;
  SharedPreferences? _preferences;
  static const _key = 'wortgarten.progress.v1';
  Future<void> _open() async {
    if (kIsWeb) {
      _preferences ??= await SharedPreferences.getInstance();
    } else {
      _db ??= await openDatabase(
        path.join(await getDatabasesPath(), 'wortgarten.db'),
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE progress (id INTEGER PRIMARY KEY, payload TEXT NOT NULL)',
        ),
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    await _open();
    String? raw;
    if (kIsWeb) {
      raw = _preferences!.getString(_key);
    } else {
      final rows = await _db!.query(
        'progress',
        where: 'id = ?',
        whereArgs: [1],
      );
      if (rows.isNotEmpty) raw = rows.first['payload'] as String;
    }
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> value) async {
    await _open();
    final payload = jsonEncode(value);
    if (kIsWeb) {
      if (!await _preferences!.setString(_key, payload)) {
        throw StateError('Could not save progress');
      }
    } else {
      await _db!.insert('progress', {
        'id': 1,
        'payload': payload,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<void> close() async => _db?.close();
}

class MemoryProgressStorage implements ProgressStorage {
  Map<String, dynamic>? value;
  @override
  Future<Map<String, dynamic>?> read() async => value;
  @override
  Future<void> write(Map<String, dynamic> data) async =>
      value = jsonDecode(jsonEncode(data));
  @override
  Future<void> close() async {}
}
