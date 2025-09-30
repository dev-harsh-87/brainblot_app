import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';

class ProgramProgressService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ProgramProgressService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Marks a program day as completed and updates progress
  Future<void> completeProgramDay(String programId, int dayNumber) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    print('✅ Completing program day: $programId, day $dayNumber');

    final batch = _firestore.batch();

    // Update active program progress
    final activeProgramRef = _firestore
        .collection('active_programs')
        .doc(userId);

    // Get current active program
    final activeDoc = await activeProgramRef.get();
    if (!activeDoc.exists) {
      throw Exception('No active program found');
    }

    final activeData = activeDoc.data()!;
    final currentDay = activeData['currentDay'] as int;
    final completedDays = List<int>.from((activeData['completedDays'] as List<dynamic>?) ?? <dynamic>[]);

    // Add day to completed days if not already completed
    if (!completedDays.contains(dayNumber)) {
      completedDays.add(dayNumber);
      completedDays.sort();
    }

    // Update current day to next incomplete day or stay at current if completing out of order
    int nextDay = currentDay;
    if (dayNumber == currentDay) {
      // Find next incomplete day
      final program = await _getProgram(programId);
      if (program != null) {
        for (int i = currentDay + 1; i <= program.totalDays; i++) {
          if (!completedDays.contains(i)) {
            nextDay = i;
            break;
          }
        }
        // If all days are completed, set to total days + 1 to indicate completion
        if (completedDays.length == program.totalDays) {
          nextDay = program.totalDays + 1;
        }
      }
    }

    // Update active program
    batch.update(activeProgramRef, {
      'currentDay': nextDay,
      'completedDays': completedDays,
      'lastCompletedAt': DateTime.now().toIso8601String(),
      'progressPercentage': _calculateProgressPercentage(completedDays.length, activeData['totalDays'] as int? ?? 1),
    });

    // Record day completion in progress collection
    final progressRef = _firestore
        .collection('program_progress')
        .doc(userId)
        .collection('completions')
        .doc('${programId}_day_$dayNumber');

    batch.set(progressRef, {
      'programId': programId,
      'dayNumber': dayNumber,
      'completedAt': DateTime.now().toIso8601String(),
      'userId': userId,
    });

    await batch.commit();
    print('🎉 Program day $dayNumber completed successfully');

    // Check if program is fully completed
    final program = await _getProgram(programId);
    if (program != null && completedDays.length >= program.totalDays) {
      await _completeProgram(programId, userId);
    }
  }

  /// Gets the current progress for an active program
  Future<ProgramProgress?> getProgramProgress(String programId) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final activeDoc = await _firestore
          .collection('active_programs')
          .doc(userId)
          .get();

      if (!activeDoc.exists) return null;

      final data = activeDoc.data()!;
      if (data['programId'] != programId) return null;

      final completedDays = List<int>.from((data['completedDays'] as List<dynamic>?) ?? <dynamic>[]);
      final currentDay = data['currentDay'] as int;
      final totalDays = data['totalDays'] as int;
      final startedAt = DateTime.parse(data['startedAt'] as String);

      return ProgramProgress(
        programId: programId,
        currentDay: currentDay,
        completedDays: completedDays,
        totalDays: totalDays,
        startedAt: startedAt,
        progressPercentage: _calculateProgressPercentage(completedDays.length, totalDays),
        lastCompletedAt: data['lastCompletedAt'] != null 
            ? DateTime.parse(data['lastCompletedAt'] as String)
            : null,
      );
    } catch (e) {
      print('❌ Error getting program progress: $e');
      return null;
    }
  }

  /// Watches program progress for real-time updates
  Stream<ProgramProgress?> watchProgramProgress(String programId) {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('active_programs')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;

      final data = doc.data()!;
      if (data['programId'] != programId) return null;

      final completedDays = List<int>.from((data['completedDays'] as List<dynamic>?) ?? <dynamic>[]);
      final currentDay = data['currentDay'] as int;
      final totalDays = data['totalDays'] as int;
      final startedAt = DateTime.parse(data['startedAt'] as String);

      return ProgramProgress(
        programId: programId,
        currentDay: currentDay,
        completedDays: completedDays,
        totalDays: totalDays,
        startedAt: startedAt,
        progressPercentage: _calculateProgressPercentage(completedDays.length, totalDays),
        lastCompletedAt: data['lastCompletedAt'] != null 
            ? DateTime.parse(data['lastCompletedAt'] as String)
            : null,
      );
    });
  }

  /// Gets completion statistics for a user
  Future<ProgramStats> getProgramStats() async {
    final userId = _currentUserId;
    if (userId == null) {
      return ProgramStats(
        totalProgramsStarted: 0,
        totalProgramsCompleted: 0,
        totalDaysCompleted: 0,
        currentStreak: 0,
        longestStreak: 0,
      );
    }

    try {
      // Get completed programs count
      final completedSnapshot = await _firestore
          .collection('completed_programs')
          .doc(userId)
          .collection('programs')
          .get();

      // Get total days completed
      final progressSnapshot = await _firestore
          .collection('program_progress')
          .doc(userId)
          .collection('completions')
          .get();

      // Get active programs (started but not completed)
      final activeDoc = await _firestore
          .collection('active_programs')
          .doc(userId)
          .get();

      final hasActiveProgram = activeDoc.exists;
      final totalStarted = completedSnapshot.docs.length + (hasActiveProgram ? 1 : 0);

      // Calculate streaks based on completion dates
      final streaks = await _calculateStreaks(userId);

      return ProgramStats(
        totalProgramsStarted: totalStarted,
        totalProgramsCompleted: completedSnapshot.docs.length,
        totalDaysCompleted: progressSnapshot.docs.length,
        currentStreak: streaks['current'] ?? 0,
        longestStreak: streaks['longest'] ?? 0,
      );
    } catch (e) {
      print('❌ Error getting program stats: $e');
      return ProgramStats(
        totalProgramsStarted: 0,
        totalProgramsCompleted: 0,
        totalDaysCompleted: 0,
        currentStreak: 0,
        longestStreak: 0,
      );
    }
  }

  /// Resets program progress (for testing or restart)
  Future<void> resetProgramProgress(String programId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final batch = _firestore.batch();

    // Reset active program to day 1
    final activeProgramRef = _firestore
        .collection('active_programs')
        .doc(userId);

    batch.update(activeProgramRef, {
      'currentDay': 1,
      'completedDays': [],
      'lastCompletedAt': null,
      'progressPercentage': 0.0,
    });

    // Delete all progress records for this program
    final progressQuery = await _firestore
        .collection('program_progress')
        .doc(userId)
        .collection('completions')
        .where('programId', isEqualTo: programId)
        .get();

    for (final doc in progressQuery.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    print('🔄 Program progress reset for $programId');
  }

  // Private helper methods

  Future<Program?> _getProgram(String programId) async {
    try {
      final doc = await _firestore
          .collection('programs')
          .doc(programId)
          .get();
      
      if (doc.exists) {
        return Program.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Error getting program: $e');
      return null;
    }
  }

  Future<void> _completeProgram(String programId, String userId) async {
    print('🏆 Completing entire program: $programId');

    final batch = _firestore.batch();

    // Remove from active programs
    final activeProgramRef = _firestore
        .collection('active_programs')
        .doc(userId);
    batch.delete(activeProgramRef);

    // Add to completed programs
    final completedRef = _firestore
        .collection('completed_programs')
        .doc(userId)
        .collection('programs')
        .doc(programId);

    batch.set(completedRef, {
      'programId': programId,
      'completedAt': DateTime.now().toIso8601String(),
      'userId': userId,
    });

    await batch.commit();
    print('🎉 Program completed and moved to completed programs!');
  }

  double _calculateProgressPercentage(int completedDays, int totalDays) {
    if (totalDays == 0) return 0.0;
    return (completedDays / totalDays * 100).clamp(0.0, 100.0);
  }

  Future<Map<String, int>> _calculateStreaks(String userId) async {
    try {
      final completions = await _firestore
          .collection('program_progress')
          .doc(userId)
          .collection('completions')
          .orderBy('completedAt', descending: true)
          .get();

      if (completions.docs.isEmpty) {
        return {'current': 0, 'longest': 0};
      }

      final dates = completions.docs
          .map((doc) => DateTime.parse(doc.data()['completedAt'] as String))
          .map((date) => DateTime(date.year, date.month, date.day))
          .toSet()
          .toList();

      dates.sort((a, b) => b.compareTo(a)); // Most recent first

      int currentStreak = 0;
      int longestStreak = 0;
      int tempStreak = 0;

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      for (int i = 0; i < dates.length; i++) {
        final date = dates[i];
        
        if (i == 0) {
          // Check if most recent completion was today or yesterday
          final daysDiff = todayDate.difference(date).inDays;
          if (daysDiff <= 1) {
            currentStreak = 1;
            tempStreak = 1;
          }
        } else {
          final prevDate = dates[i - 1];
          final daysDiff = prevDate.difference(date).inDays;
          
          if (daysDiff == 1) {
            tempStreak++;
            if (i == 1 || currentStreak > 0) {
              currentStreak = tempStreak;
            }
          } else {
            tempStreak = 1;
            if (currentStreak == 0) break; // No current streak
          }
        }
        
        longestStreak = longestStreak > tempStreak ? longestStreak : tempStreak;
      }

      return {'current': currentStreak, 'longest': longestStreak};
    } catch (e) {
      print('❌ Error calculating streaks: $e');
      return {'current': 0, 'longest': 0};
    }
  }
}

/// Data class for program progress
class ProgramProgress {
  final String programId;
  final int currentDay;
  final List<int> completedDays;
  final int totalDays;
  final DateTime startedAt;
  final double progressPercentage;
  final DateTime? lastCompletedAt;

  ProgramProgress({
    required this.programId,
    required this.currentDay,
    required this.completedDays,
    required this.totalDays,
    required this.startedAt,
    required this.progressPercentage,
    this.lastCompletedAt,
  });

  bool get isCompleted => completedDays.length >= totalDays;
  bool isDayCompleted(int dayNumber) => completedDays.contains(dayNumber);
  int get remainingDays => totalDays - completedDays.length;
  Duration get timeActive => DateTime.now().difference(startedAt);
}

/// Data class for program statistics
class ProgramStats {
  final int totalProgramsStarted;
  final int totalProgramsCompleted;
  final int totalDaysCompleted;
  final int currentStreak;
  final int longestStreak;

  ProgramStats({
    required this.totalProgramsStarted,
    required this.totalProgramsCompleted,
    required this.totalDaysCompleted,
    required this.currentStreak,
    required this.longestStreak,
  });

  double get completionRate {
    if (totalProgramsStarted == 0) return 0.0;
    return (totalProgramsCompleted / totalProgramsStarted * 100).clamp(0.0, 100.0);
  }
}
