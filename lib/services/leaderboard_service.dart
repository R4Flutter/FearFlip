import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'leaderboard_cache.dart';


class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.scoreSeconds,
    this.maxStage,
    this.totalTrophies,
    this.uid,
    this.displayName,
  });

  final int rank;
  final int scoreSeconds;
  final int? maxStage;
  final int? totalTrophies;
  final String? uid;
  final String? displayName;
}

class LeaderboardSnapshot {
  const LeaderboardSnapshot({
    required this.mode,
    required this.entries,
    required this.totalPlayers,
    required this.fetchedAt,
    this.myRank,
    this.myBestScoreSeconds,
    this.myMaxStage,
    this.myTotalTrophies,
  });

  final String mode;
  final List<LeaderboardEntry> entries;
  final int totalPlayers;
  final int? myRank;
  final int? myBestScoreSeconds;
  final int? myMaxStage;
  final int? myTotalTrophies;
  final DateTime fetchedAt;
}

abstract class LeaderboardService {
  Future<void> submitRun({required int scoreSeconds, required String mode});

  Future<void> upsertGlobalPanicProgress({
    required int maxStage,
    required int totalTrophies,
    /// The player's in-game display name. Provided by the caller so that
    /// guest names (stored only locally) are written to Firestore correctly.
    String? playerName,
  });

  Future<LeaderboardSnapshot> getGlobalPanicLeaderboard({int limit = 30});

  /// Emits an updated [LeaderboardSnapshot] every time the Global Panic
  /// profiles collection changes in Firestore. The stream immediately yields
  /// a cached snapshot (if one exists) so the UI never starts blank.
  Stream<LeaderboardSnapshot> globalPanicLeaderboardStream({int limit = 30});

  Future<int?> getGlobalPanicRank();

  Future<LeaderboardSnapshot> getLeaderboard({
    required String mode,
    int limit = 30,
  });
}

class StubLeaderboardService implements LeaderboardService {
  @override
  Future<void> submitRun({
    required int scoreSeconds,
    required String mode,
  }) async {
    // Intentionally no-op in local/offline mode.
  }

  @override
  Future<void> upsertGlobalPanicProgress({
    required int maxStage,
    required int totalTrophies,
    String? playerName,
  }) async {
    // Intentionally no-op in local/offline mode.
  }

  @override
  Future<LeaderboardSnapshot> getGlobalPanicLeaderboard({
    int limit = 30,
  }) async {
    // StubLeaderboardService intentionally returns empty data.
    // Dummy names only existed for UI preview; with a real Firebase project
    // the FirestoreLeaderboardService is always used in production.
    return LeaderboardSnapshot(
      mode: 'global_panic',
      entries: const <LeaderboardEntry>[],
      totalPlayers: 0,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Stream<LeaderboardSnapshot> globalPanicLeaderboardStream({
    int limit = 30,
  }) {
    return Stream.fromFuture(getGlobalPanicLeaderboard(limit: limit));
  }

  @override
  Future<int?> getGlobalPanicRank() async {
    return null;
  }

  @override
  Future<LeaderboardSnapshot> getLeaderboard({
    required String mode,
    int limit = 30,
  }) async {
    final safeMode = _sanitizeMode(mode);
    return LeaderboardSnapshot(
      mode: safeMode,
      entries: const <LeaderboardEntry>[],
      totalPlayers: 0,
      fetchedAt: DateTime.now(),
    );
  }

  String _sanitizeMode(String mode) {
    final normalized = mode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'normal';
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  }
}

class FirestoreLeaderboardService implements LeaderboardService {
  FirestoreLeaderboardService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LeaderboardCache? cache,
      FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
      _cache = cache ?? LeaderboardCache(),
      _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LeaderboardCache _cache;
    final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> _globalPanicProfiles() {
    return _firestore
        .collection('leaderboards')
        .doc('global_panic')
        .collection('profiles');
  }

  @override
  Future<void> submitRun({
    required int scoreSeconds,
    required String mode,
  }) async {
    final safeMode = _sanitizeMode(mode);
    final safeScore = scoreSeconds.clamp(0, 60 * 60 * 24).toInt();
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      debugPrint('[LeaderboardService] submitRun skipped (no auth user).');
      return;
    }
    final displayName = _bestDisplayName(user);
    try {
      final callable = _functions.httpsCallable(
        'submitScore',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      await callable.call(<String, Object?>{
        'scoreSeconds': safeScore,
        'mode': safeMode,
        'displayName': displayName,
        'clientTimestampMs': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (error, stackTrace) {
      await _reportFailure(
        reason: 'leaderboard_submit_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'mode': safeMode,
          'score_seconds': safeScore,
          'has_uid': true,
        },
      );
      // Keep gameplay crash-safe if backend is unavailable.
    }
  }

  @override
  Future<LeaderboardSnapshot> getLeaderboard({
    required String mode,
    int limit = 30,
  }) async {
    final safeMode = _sanitizeMode(mode);
    final safeLimit = limit.clamp(1, 100).toInt();
    final user = _auth.currentUser;
    final uid = user?.uid;
    final bestCollection = _firestore
        .collection('leaderboards')
        .doc(safeMode)
        .collection('best');

    try {
      final topQuery = await bestCollection
          .orderBy('scoreSeconds', descending: true)
          .limit(safeLimit)
          .get();

      final entries = <LeaderboardEntry>[];
      for (var i = 0; i < topQuery.docs.length; i++) {
        final data = topQuery.docs[i].data();
        final score = (data['scoreSeconds'] as num?)?.toInt() ?? 0;
        final rowUid = data['uid'] as String?;
        final rowName = data['displayName'] as String?;
        entries.add(
          LeaderboardEntry(
            rank: i + 1,
            scoreSeconds: score,
            uid: rowUid,
            displayName: rowName,
          ),
        );
      }

      final totalPlayers = (await bestCollection.count().get()).count ?? 0;

      int? myBestScore;
      int? myRank;
      if (uid != null) {
        final myDoc = await bestCollection.doc(uid).get();
        if (myDoc.exists) {
          myBestScore = (myDoc.data()?['scoreSeconds'] as num?)?.toInt();
          if (myBestScore != null) {
            final betterCount = await bestCollection
                .where('scoreSeconds', isGreaterThan: myBestScore)
                .count()
                .get();
            myRank = (betterCount.count ?? 0) + 1;
          }
        }
      }

      return LeaderboardSnapshot(
        mode: safeMode,
        entries: entries,
        totalPlayers: totalPlayers,
        myRank: myRank,
        myBestScoreSeconds: myBestScore,
        fetchedAt: DateTime.now(),
      );
    } catch (error, stackTrace) {
      await _reportFailure(
        reason: 'leaderboard_fetch_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'mode': safeMode,
          'limit': safeLimit,
          'has_uid': uid != null,
        },
      );
      return LeaderboardSnapshot(
        mode: safeMode,
        entries: const <LeaderboardEntry>[],
        totalPlayers: 0,
        fetchedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> upsertGlobalPanicProgress({
    required int maxStage,
    required int totalTrophies,
    String? playerName,
  }) async {
    final user = _auth.currentUser;
    final uid = user?.uid;

    // Guests who completed anonymous sign-in still get a uid.
    // Pure offline guests (no network at all) have no uid — skip quietly;
    // their progress is still tracked locally by AppFlowProvider.
    if (uid == null) {
      debugPrint('[LeaderboardService] upsertGlobalPanicProgress: no uid — skipping (pure offline guest).');
      return;
    }

    final safeStage = maxStage.clamp(1, 9999).toInt();
    final safeTrophies = totalTrophies.clamp(0, 9999999).toInt();

    // Prefer the caller-supplied name (in-game name chosen by the player)
    // so guests appear with their actual chosen name, not 'Guest'.
    final displayName = (playerName?.trim().isNotEmpty ?? false)
        ? playerName!.trim()
        : _bestDisplayName(user);

    try {
      // Server-authoritative write. The upsertGlobalPanicProgress function
      // does the monotonic (never-regress) resolution and range clamp; the
      // profiles collection is no longer client-writable (firestore.rules).
      final callable = _functions.httpsCallable(
        'upsertGlobalPanicProgress',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      await callable.call(<String, Object?>{
        'maxStage': safeStage,
        'totalTrophies': safeTrophies,
        'displayName': displayName,
      });
    } catch (error, stackTrace) {
      await _reportFailure(
        reason: 'global_panic_upsert_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'max_stage': safeStage,
          'total_trophies': safeTrophies,
          'uid': uid,
        },
      );
      // Keep gameplay crash-safe if backend is unavailable.
    }
  }

  // ── Stream API ─────────────────────────────────────────────────────────────

  @override
  Stream<LeaderboardSnapshot> globalPanicLeaderboardStream({int limit = 30}) {
    final safeLimit = limit.clamp(1, 100).toInt();
    final profiles = _globalPanicProfiles();

    // Seed the stream with the cached snapshot first so the UI is never blank
    // while waiting for Firestore.
    Future<LeaderboardSnapshot?> seedFuture() => _cache.load('global_panic');

    final firestoreStream = profiles
        .orderBy('maxStage', descending: true)
        .orderBy('totalTrophies', descending: false)
        .limit(safeLimit)
        .snapshots()
        .asyncMap((snap) => _mapProfileSnapshot(snap, safeLimit));

    return () async* {
      final cached = await seedFuture();
      if (cached != null) {
        yield cached;
      }
      yield* firestoreStream;
    }();
  }

  Future<LeaderboardSnapshot> _mapProfileSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
    int safeLimit,
  ) async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    final profiles = _globalPanicProfiles();

    final docs = snap.docs.toList(growable: false);
    final ranked = docs.map((d) => d.data()).toList(growable: false)
      ..sort((a, b) {
        final stageA = (a['maxStage'] as num?)?.toInt() ?? 1;
        final stageB = (b['maxStage'] as num?)?.toInt() ?? 1;
        if (stageA != stageB) {
          return stageB.compareTo(stageA);
        }
        final trophiesA = (a['totalTrophies'] as num?)?.toInt() ?? 0;
        final trophiesB = (b['totalTrophies'] as num?)?.toInt() ?? 0;
        return trophiesA.compareTo(trophiesB);
      });

    final top = ranked.take(safeLimit).toList(growable: false);
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < top.length; i++) {
      final data = top[i];
      entries.add(
        LeaderboardEntry(
          rank: i + 1,
          scoreSeconds: 0,
          maxStage: (data['maxStage'] as num?)?.toInt() ?? 1,
          totalTrophies: (data['totalTrophies'] as num?)?.toInt() ?? 0,
          uid: data['uid'] as String?,
          displayName: data['displayName'] as String?,
        ),
      );
    }

    int totalPlayers = 0;
    try {
      totalPlayers = (await profiles.count().get()).count ?? 0;
    } catch (error, stackTrace) {
      await _reportFailure(
        reason: 'global_panic_total_players_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'limit': safeLimit},
      );
    }

    int? myRank;
    int? myStage;
    int? myTrophies;
    if (uid != null) {
      try {
        final myDoc = await profiles.doc(uid).get();
        if (myDoc.exists) {
          final data = myDoc.data();
          myStage = (data?['maxStage'] as num?)?.toInt() ?? 1;
          myTrophies = (data?['totalTrophies'] as num?)?.toInt() ?? 0;
          final higherStageCount =
              (await profiles
                      .where('maxStage', isGreaterThan: myStage)
                      .count()
                      .get())
                  .count ??
              0;
          var sameStageLowerTrophyCount = 0;
          try {
            sameStageLowerTrophyCount =
                (await profiles
                        .where('maxStage', isEqualTo: myStage)
                        .where('totalTrophies', isLessThan: myTrophies)
                        .count()
                        .get())
                    .count ??
                0;
          } catch (error, stackTrace) {
            sameStageLowerTrophyCount = 0;
            await _reportFailure(
              reason: 'global_panic_same_stage_query_failed',
              error: error,
              stackTrace: stackTrace,
              context: <String, Object?>{
                'uid': uid,
                'max_stage': myStage,
                'total_trophies': myTrophies,
              },
            );
          }
          myRank = higherStageCount + sameStageLowerTrophyCount + 1;
        }
      } catch (error, stackTrace) {
        await _reportFailure(
          reason: 'global_panic_rank_lookup_failed',
          error: error,
          stackTrace: stackTrace,
          context: <String, Object?>{'uid': uid},
        );
      }
    }

    final snapshot = LeaderboardSnapshot(
      mode: 'global_panic',
      entries: entries,
      totalPlayers: totalPlayers,
      myRank: myRank,
      myMaxStage: myStage,
      myTotalTrophies: myTrophies,
      fetchedAt: DateTime.now(),
    );

    // Persist successful fetch for offline use.
    unawaited(_cache.save(snapshot));
    return snapshot;
  }

  // ── Future API ─────────────────────────────────────────────────────────────

  @override
  Future<LeaderboardSnapshot> getGlobalPanicLeaderboard({
    int limit = 30,
  }) async {
    final safeLimit = limit.clamp(1, 100).toInt();
    final user = _auth.currentUser;
    final uid = user?.uid;
    final profiles = _globalPanicProfiles();

    QuerySnapshot<Map<String, dynamic>>? topQuery;
    try {
      topQuery = await profiles
          .orderBy('maxStage', descending: true)
          .orderBy('totalTrophies', descending: false)
          .limit(safeLimit)
          .get();
    } catch (error, stackTrace) {
      await _reportFailure(
        reason: 'global_panic_index_missing',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'limit': safeLimit},
      );
      // Fallback when composite index is missing: query by stage only, then
      // apply trophies tie-breaker client-side.
      try {
        topQuery = await profiles
            .orderBy('maxStage', descending: true)
            .limit(safeLimit * 3)
            .get();
      } catch (fallbackError, fallbackStackTrace) {
        await _reportFailure(
          reason: 'global_panic_fallback_query_failed',
          error: fallbackError,
          stackTrace: fallbackStackTrace,
          context: <String, Object?>{'limit': safeLimit},
        );
        topQuery = null;
      }
    }

    try {
      final docs = topQuery?.docs.toList(growable: false) ?? const [];
      final ranked = docs.map((d) => d.data()).toList(growable: false)
        ..sort((a, b) {
          final stageA = (a['maxStage'] as num?)?.toInt() ?? 1;
          final stageB = (b['maxStage'] as num?)?.toInt() ?? 1;
          if (stageA != stageB) {
            return stageB.compareTo(stageA);
          }
          final trophiesA = (a['totalTrophies'] as num?)?.toInt() ?? 0;
          final trophiesB = (b['totalTrophies'] as num?)?.toInt() ?? 0;
          return trophiesA.compareTo(trophiesB);
        });

      final top = ranked.take(safeLimit).toList(growable: false);
      final entries = <LeaderboardEntry>[];
      for (var i = 0; i < top.length; i++) {
        final data = top[i];
        entries.add(
          LeaderboardEntry(
            rank: i + 1,
            scoreSeconds: 0,
            maxStage: (data['maxStage'] as num?)?.toInt() ?? 1,
            totalTrophies: (data['totalTrophies'] as num?)?.toInt() ?? 0,
            uid: data['uid'] as String?,
            displayName: data['displayName'] as String?,
          ),
        );
      }

      final totalPlayers = (await profiles.count().get()).count ?? 0;


      int? myRank;
      int? myStage;
      int? myTrophies;
      if (uid != null) {
        final myDoc = await profiles.doc(uid).get();
        if (myDoc.exists) {
          final data = myDoc.data();
          myStage = (data?['maxStage'] as num?)?.toInt() ?? 1;
          myTrophies = (data?['totalTrophies'] as num?)?.toInt() ?? 0;

          final higherStageCount =
              (await profiles
                      .where('maxStage', isGreaterThan: myStage)
                      .count()
                      .get())
                  .count ??
              0;

          var sameStageLowerTrophyCount = 0;
          try {
            sameStageLowerTrophyCount =
                (await profiles
                        .where('maxStage', isEqualTo: myStage)
                        .where('totalTrophies', isLessThan: myTrophies)
                        .count()
                        .get())
                    .count ??
                0;
          } catch (error, stackTrace) {
            sameStageLowerTrophyCount = 0;
            await _reportFailure(
              reason: 'global_panic_same_stage_query_failed',
              error: error,
              stackTrace: stackTrace,
              context: <String, Object?>{
                'uid': uid,
                'max_stage': myStage,
                'total_trophies': myTrophies,
              },
            );
          }

          myRank = higherStageCount + sameStageLowerTrophyCount + 1;
        }
      }

      final result = LeaderboardSnapshot(
        mode: 'global_panic',
        entries: entries,
        totalPlayers: totalPlayers,
        myRank: myRank,
        myMaxStage: myStage,
        myTotalTrophies: myTrophies,
        fetchedAt: DateTime.now(),
      );
      // Cache the complete snapshot (including myRank) for offline use.
      unawaited(_cache.save(result));
      return result;
    } catch (error, stackTrace) {
      await _reportFailure(
        reason: 'global_panic_fetch_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'limit': safeLimit, 'has_uid': uid != null},
      );

      // Try the disk cache before showing empty/dummy data.
      final cached = await _cache.load('global_panic');
      if (cached != null) {
        return cached;
      }

      return LeaderboardSnapshot(
        mode: 'global_panic',
        entries: const <LeaderboardEntry>[],
        totalPlayers: 0,
        fetchedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<int?> getGlobalPanicRank() async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      return null;
    }

    final profiles = _globalPanicProfiles();

    try {
      final myDoc = await profiles.doc(uid).get();
      if (!myDoc.exists) {
        return null;
      }

      final data = myDoc.data();
      final myStage = (data?['maxStage'] as num?)?.toInt() ?? 1;
      final myTrophies = (data?['totalTrophies'] as num?)?.toInt() ?? 0;

      final totalPlayers = (await profiles.count().get()).count ?? 0;
      if (totalPlayers <= 1) {
        return 1;
      }

      var higherStageCount = 0;
      try {
        higherStageCount =
            (await profiles
                    .where('maxStage', isGreaterThan: myStage)
                    .count()
                    .get())
                .count ??
            0;
      } catch (error, stackTrace) {
        await _reportFailure(
          reason: 'global_panic_rank_stage_query_failed',
          error: error,
          stackTrace: stackTrace,
          context: <String, Object?>{'uid': uid},
        );
        return 1;
      }

      try {
        final sameStageLowerTrophyCount =
            (await profiles
                    .where('maxStage', isEqualTo: myStage)
                    .where('totalTrophies', isLessThan: myTrophies)
                    .count()
                    .get())
                .count ??
            0;
        return higherStageCount + sameStageLowerTrophyCount + 1;
      } catch (error, stackTrace) {
        await _reportFailure(
          reason: 'global_panic_rank_trophy_query_failed',
          error: error,
          stackTrace: stackTrace,
          context: <String, Object?>{
            'uid': uid,
            'max_stage': myStage,
            'total_trophies': myTrophies,
          },
        );
        // If this indexed query is unavailable, fall back to stage-only rank.
        return higherStageCount + 1;
      }
    } catch (error, stackTrace) {
      await _reportFailure(
        reason: 'global_panic_rank_failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'uid': uid},
      );
      return null;
    }
  }

  String _sanitizeMode(String mode) {
    final normalized = mode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'normal';
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  }

  String _bestDisplayName(User? user) {
    if (user == null) {
      return 'Guest';
    }
    final display = user.displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return display;
    }
    final uid = user.uid.trim();
    if (uid.isNotEmpty) {
      final suffix = uid.length > 6 ? uid.substring(uid.length - 6) : uid;
      return 'Player-$suffix';
    }
    if (user.isAnonymous) {
      return 'Guest';
    }
    return 'Player';
  }

  Future<void> _reportFailure({
    required String reason,
    required Object error,
    required StackTrace stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    final message = StringBuffer(reason);
    if (context.isNotEmpty) {
      final details = context.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join(', ');
      message.write(' | $details');
    }

    try {
      await FirebaseCrashlytics.instance.log(message.toString());
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: false,
      );
    } catch (reportError, reportStackTrace) {
      if (kDebugMode) {
        debugPrint(
          '${message.toString()} | report_error=$reportError\n$reportStackTrace',
        );
      }
    }
  }
}
