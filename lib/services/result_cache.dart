import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/detection_result.dart';

/// Persists detection results keyed by asset id so re-scans only process new
/// or changed photos. Entries are invalidated when an asset's modified
/// timestamp changes.
class ResultCache {
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'pixelproof_cache_v2.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE results (
            asset_id TEXT PRIMARY KEY,
            modified_at INTEGER NOT NULL,
            verdict TEXT NOT NULL,
            ai_probability REAL NOT NULL,
            confidence REAL NOT NULL,
            deciding_signal TEXT NOT NULL,
            reason TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  /// Returns a cached result if present and still valid for [modifiedAt].
  Future<DetectionResult?> get(String assetId, int modifiedAt) async {
    final db = await _open();
    final rows = await db.query(
      'results',
      where: 'asset_id = ? AND modified_at = ?',
      whereArgs: [assetId, modifiedAt],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return DetectionResult(
      verdict: Verdict.values.byName(r['verdict'] as String),
      aiProbability: (r['ai_probability'] as num).toDouble(),
      confidence: (r['confidence'] as num).toDouble(),
      decidingSignal:
          DetectionSignal.values.byName(r['deciding_signal'] as String),
      reason: r['reason'] as String,
    );
  }

  /// Stores or replaces a result.
  Future<void> put(
    String assetId,
    int modifiedAt,
    DetectionResult result,
  ) async {
    final db = await _open();
    await db.insert(
      'results',
      {
        'asset_id': assetId,
        'modified_at': modifiedAt,
        'verdict': result.verdict.name,
        'ai_probability': result.aiProbability,
        'confidence': result.confidence,
        'deciding_signal': result.decidingSignal.name,
        'reason': result.reason,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Clears all cached results.
  Future<void> clear() async {
    final db = await _open();
    await db.delete('results');
  }
}
