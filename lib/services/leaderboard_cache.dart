import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'error_reporter.dart';
import 'leaderboard_service.dart';

/// Persists the last-fetched [LeaderboardSnapshot] to [SharedPreferences] so
/// that an offline or failed fetch still shows meaningful data.
///
/// The cache is keyed per [mode] so separate leaderboard modes don't collide.
/// Serialisation is intentionally simple JSON — no additional dependencies.
class LeaderboardCache {
  static const String _keyPrefix = 'leaderboard_cache_v1_';

  String _key(String mode) => '$_keyPrefix$mode';

  // ── Write ──────────────────────────────────────────────────────────────────

  Future<void> save(LeaderboardSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _snapshotToMap(snapshot);
      await prefs.setString(_key(snapshot.mode), jsonEncode(map));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[LeaderboardCache] save failed: $error');
      }
      // Non-fatal — worst case the cache is stale.
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<LeaderboardSnapshot?> load(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(mode));
      if (raw == null) {
        return null;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _snapshotFromMap(map);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[LeaderboardCache] load failed: $error');
      }
      return null;
    }
  }

  // ── Clear ──────────────────────────────────────────────────────────────────

  Future<void> clear(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(mode));
    } catch (error, stackTrace) {
      ErrorReporter.report(
        reason: 'leaderboard_cache_clear_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'mode': mode},
      );
    }
  }

  // ── Serialisation helpers ──────────────────────────────────────────────────

  Map<String, dynamic> _snapshotToMap(LeaderboardSnapshot s) {
    return <String, dynamic>{
      'mode': s.mode,
      'totalPlayers': s.totalPlayers,
      'myRank': s.myRank,
      'myBestScoreSeconds': s.myBestScoreSeconds,
      'myMaxStage': s.myMaxStage,
      'myTotalTrophies': s.myTotalTrophies,
      'fetchedAt': s.fetchedAt.millisecondsSinceEpoch,
      'entries': s.entries.map(_entryToMap).toList(),
    };
  }

  Map<String, dynamic> _entryToMap(LeaderboardEntry e) {
    return <String, dynamic>{
      'rank': e.rank,
      'scoreSeconds': e.scoreSeconds,
      'maxStage': e.maxStage,
      'totalTrophies': e.totalTrophies,
      'uid': e.uid,
      'displayName': e.displayName,
    };
  }

  LeaderboardSnapshot _snapshotFromMap(Map<String, dynamic> map) {
    final rawEntries = map['entries'] as List<dynamic>? ?? const [];
    final entries = rawEntries
        .whereType<Map<String, dynamic>>()
        .map(_entryFromMap)
        .toList(growable: false);

    return LeaderboardSnapshot(
      mode: (map['mode'] as String?) ?? 'global_panic',
      totalPlayers: (map['totalPlayers'] as num?)?.toInt() ?? 0,
      myRank: (map['myRank'] as num?)?.toInt(),
      myBestScoreSeconds: (map['myBestScoreSeconds'] as num?)?.toInt(),
      myMaxStage: (map['myMaxStage'] as num?)?.toInt(),
      myTotalTrophies: (map['myTotalTrophies'] as num?)?.toInt(),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['fetchedAt'] as num?)?.toInt() ?? 0,
      ),
      entries: entries,
    );
  }

  LeaderboardEntry _entryFromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      scoreSeconds: (map['scoreSeconds'] as num?)?.toInt() ?? 0,
      maxStage: (map['maxStage'] as num?)?.toInt(),
      totalTrophies: (map['totalTrophies'] as num?)?.toInt(),
      uid: map['uid'] as String?,
      displayName: map['displayName'] as String?,
    );
  }
}
