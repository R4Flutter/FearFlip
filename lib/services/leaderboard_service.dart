import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  });

  Future<LeaderboardSnapshot> getGlobalPanicLeaderboard({int limit = 20});

  Future<int?> getGlobalPanicRank();

  Future<LeaderboardSnapshot> getLeaderboard({
    required String mode,
    int limit = 20,
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
  }) async {
    // Intentionally no-op in local/offline mode.
  }

  @override
  Future<LeaderboardSnapshot> getGlobalPanicLeaderboard({
    int limit = 20,
  }) async {
    return LeaderboardSnapshot(
      mode: 'global_panic',
      entries: const <LeaderboardEntry>[],
      totalPlayers: 0,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Future<int?> getGlobalPanicRank() async {
    return null;
  }

  @override
  Future<LeaderboardSnapshot> getLeaderboard({
    required String mode,
    int limit = 20,
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
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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
    final displayName = _bestDisplayName(user);
    final now = FieldValue.serverTimestamp();

    try {
      await _firestore
          .collection('leaderboards')
          .doc(safeMode)
          .collection('scores')
          .add({
            'uid': uid,
            'displayName': displayName,
            'scoreSeconds': safeScore,
            'mode': safeMode,
            'createdAt': now,
          });

      if (uid != null) {
        final bestRef = _firestore
            .collection('leaderboards')
            .doc(safeMode)
            .collection('best')
            .doc(uid);

        await _firestore.runTransaction((txn) async {
          final existing = await txn.get(bestRef);
          final previous = existing.data()?['scoreSeconds'];
          final previousScore = previous is num ? previous.toInt() : -1;
          if (!existing.exists || safeScore > previousScore) {
            txn.set(bestRef, <String, Object?>{
              'uid': uid,
              'displayName': displayName,
              'scoreSeconds': safeScore,
              'mode': safeMode,
              'updatedAt': now,
            }, SetOptions(merge: true));
          }
        });

        await _firestore
            .collection('runs')
            .doc(uid)
            .collection('sessions')
            .add({
              'scoreSeconds': safeScore,
              'mode': safeMode,
              'displayName': displayName,
              'createdAt': now,
              'clientTimestampMs': DateTime.now().millisecondsSinceEpoch,
            });
      }
    } catch (_) {
      // Keep gameplay crash-safe if backend is unavailable.
    }
  }

  @override
  Future<LeaderboardSnapshot> getLeaderboard({
    required String mode,
    int limit = 20,
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
    } catch (_) {
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
  }) async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      return;
    }

    final safeStage = maxStage.clamp(1, 9999).toInt();
    final safeTrophies = totalTrophies.clamp(0, 9999999).toInt();
    final displayName = _bestDisplayName(user);
    final now = FieldValue.serverTimestamp();
    final profileRef = _globalPanicProfiles().doc(uid);

    try {
      await _firestore.runTransaction((txn) async {
        final existing = await txn.get(profileRef);
        final previous = existing.data();
        final previousStage = (previous?['maxStage'] as num?)?.toInt() ?? 1;
        final previousTrophies =
            (previous?['totalTrophies'] as num?)?.toInt() ?? 0;

        final resolvedStage = previousStage > safeStage
            ? previousStage
            : safeStage;
        final resolvedTrophies = previousTrophies > safeTrophies
            ? previousTrophies
            : safeTrophies;

        txn.set(profileRef, <String, Object?>{
          'uid': uid,
          'displayName': displayName,
          'maxStage': resolvedStage,
          'totalTrophies': resolvedTrophies,
          'updatedAt': now,
        }, SetOptions(merge: true));
      });
    } catch (_) {
      // Keep gameplay crash-safe if backend is unavailable.
    }
  }

  @override
  Future<LeaderboardSnapshot> getGlobalPanicLeaderboard({
    int limit = 20,
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
    } catch (_) {
      // Fallback when composite index is missing: query by stage only, then
      // apply trophies tie-breaker client-side.
      try {
        topQuery = await profiles
            .orderBy('maxStage', descending: true)
            .limit(safeLimit * 3)
            .get();
      } catch (_) {
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
          } catch (_) {
            sameStageLowerTrophyCount = 0;
          }

          myRank = higherStageCount + sameStageLowerTrophyCount + 1;
        }
      }

      return LeaderboardSnapshot(
        mode: 'global_panic',
        entries: entries,
        totalPlayers: totalPlayers,
        myRank: myRank,
        myMaxStage: myStage,
        myTotalTrophies: myTrophies,
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
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
      } catch (_) {
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
      } catch (_) {
        // If this indexed query is unavailable, fall back to stage-only rank.
        return higherStageCount + 1;
      }
    } catch (_) {
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
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    final display = user.displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return display;
    }
    if (user.isAnonymous) {
      return 'Guest';
    }
    return 'Player';
  }
}
