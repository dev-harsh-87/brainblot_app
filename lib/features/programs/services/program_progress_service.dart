import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/programs/domain/program.dart';
import 'package:spark_app/core/utils/app_logger.dart';

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

    AppLogger.info('Completing program day: $programId, day $dayNumber');

    final batch = _firestore.batch();

    // Update program progress (unified collection)
    // Find the active program progress document
    final progressQuery = await _firestore
        .collection('program_progress')
        .where('userId', isEqualTo: userId)
        .where('programId', isEqualTo: programId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (progressQuery.docs.isEmpty) {
      throw Exception('No active program found');
    }

    final progressDoc = progressQuery.docs.first;
    final activeProgramRef = progressDoc.reference;
    final activeDoc = progressDoc;
    if (!activeDoc.exists) {
      throw Exception('No active program found');
    }

    final activeData = activeDoc.data();
    final currentDay = (activeData['currentDay'] as int?) ?? 1;
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
        for (int i = currentDay + 1; i <= program.durationDays; i++) {
          if (!completedDays.contains(i)) {
            nextDay = i;
            break;
          }
        }
        // If all days are completed, set to total days + 1 to indicate completion
        if (completedDays.length == program.durationDays) {
          nextDay = program.durationDays + 1;
        }
      }
    }

    final completionTime = DateTime.now();
    
    // Update active program in program_progress collection
    batch.update(activeProgramRef, {
      'currentDay': nextDay,
      'completedDays': completedDays,
      'lastCompletedAt': completionTime.toIso8601String(),
      'progressPercentage': _calculateProgressPercentage(completedDays.length, activeData['totalDays'] as int? ?? 1),
      'dayCompletionTimes.${dayNumber}': completionTime.toIso8601String(),
    });

    // IMPORTANT: Also update the active_programs collection that the BLoC watches
    final activeProgramDocRef = _firestore
        .collection('active_programs')
        .doc(userId);
    
    // Use set instead of update to ensure the document exists
    batch.set(activeProgramDocRef, {
      'currentDay': nextDay,
      'programId': programId,
      'startedAt': activeData['startedAt'] ?? DateTime.now().toIso8601String(),
      'userId': userId,
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

    try {
      await batch.commit();
      AppLogger.info('Program day $dayNumber completed successfully. Next day: $nextDay');
    } catch (e) {
      AppLogger.error('Failed to commit program day completion batch', error: e);
      throw Exception('Failed to complete program day: $e');
    }

    // Check if program is fully completed
    final program = await _getProgram(programId);
    if (program != null && completedDays.length >= program.durationDays) {
      await _completeProgram(programId, userId);
    }
  }

  /// Gets the current progress for an active program
  Future<ProgramProgress?> getProgramProgress(String programId) async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final progressQuery = await _firestore
          .collection('program_progress')
          .where('userId', isEqualTo: userId)
          .where('programId', isEqualTo: programId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (progressQuery.docs.isEmpty) return null;

      final data = progressQuery.docs.first.data();

      final completedDays = List<int>.from((data['completedDays'] as List<dynamic>?) ?? <dynamic>[]);
      final currentDay = (data['currentDay'] as int?) ?? 1;
      final totalDays = (data['totalDays'] as int?) ?? (data['durationDays'] as int?) ?? 30;
      final startedAt = data['startedAt'] != null 
          ? DateTime.parse(data['startedAt'] as String)
          : DateTime.now();

      // Parse day completion times
      final dayCompletionTimes = <int, DateTime>{};
      final dayCompletionTimesData = data['dayCompletionTimes'] as Map<String, dynamic>?;
      if (dayCompletionTimesData != null) {
        for (final entry in dayCompletionTimesData.entries) {
          final dayNumber = int.tryParse(entry.key);
          final timeString = entry.value as String?;
          if (dayNumber != null && timeString != null) {
            try {
              dayCompletionTimes[dayNumber] = DateTime.parse(timeString);
            } catch (e) {
              print('Error parsing day completion time for day $dayNumber: $e');
            }
          }
        }
      }

      return ProgramProgress(
        programId: programId,
        currentDay: currentDay,
        completedDays: completedDays,
        durationDays: totalDays,
        startedAt: startedAt,
        progressPercentage: _calculateProgressPercentage(completedDays.length, totalDays),
        lastCompletedAt: data['lastCompletedAt'] != null
            ? DateTime.parse(data['lastCompletedAt'] as String)
            : null,
        dayCompletionTimes: dayCompletionTimes,
      );
    } catch (e) {
      AppLogger.error('Error getting program progress', error: e);
      return null;
    }
  }

  /// Watches program progress for real-time updates
  Stream<ProgramProgress?> watchProgramProgress(String programId) {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('program_progress')
        .where('userId', isEqualTo: userId)
        .where('programId', isEqualTo: programId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();

      final completedDays = List<int>.from((data['completedDays'] as List<dynamic>?) ?? <dynamic>[]);
      final currentDay = (data['currentDay'] as int?) ?? 1;
      final totalDays = (data['totalDays'] as int?) ?? (data['durationDays'] as int?) ?? 30;
      final startedAt = data['startedAt'] != null 
          ? DateTime.parse(data['startedAt'] as String)
          : DateTime.now();

      // Parse day completion times
      final dayCompletionTimes = <int, DateTime>{};
      final dayCompletionTimesData = data['dayCompletionTimes'] as Map<String, dynamic>?;
      if (dayCompletionTimesData != null) {
        for (final entry in dayCompletionTimesData.entries) {
          final dayNumber = int.tryParse(entry.key);
          final timeString = entry.value as String?;
          if (dayNumber != null && timeString != null) {
            try {
              dayCompletionTimes[dayNumber] = DateTime.parse(timeString);
            } catch (e) {
              print('Error parsing day completion time for day $dayNumber: $e');
            }
          }
        }
      }

      return ProgramProgress(
        programId: programId,
        currentDay: currentDay,
        completedDays: completedDays,
        durationDays: totalDays,
        startedAt: startedAt,
        progressPercentage: _calculateProgressPercentage(completedDays.length, totalDays),
        lastCompletedAt: data['lastCompletedAt'] != null
            ? DateTime.parse(data['lastCompletedAt'] as String)
            : null,
        dayCompletionTimes: dayCompletionTimes,
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
      // Get all program progress (both active and completed)
      final allProgressSnapshot = await _firestore
          .collection('program_progress')
          .where('userId', isEqualTo: userId)
          .get();

      final completedCount = allProgressSnapshot.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      final totalStarted = allProgressSnapshot.docs.length;

      // Get total days completed from all programs
      final totalDaysCompleted = allProgressSnapshot.docs
          .map((doc) => (doc.data()['completedDays'] as List?)?.length ?? 0)
          .fold<int>(0, (sum, count) => sum + count);

      // Calculate streaks based on completion dates
      final streaks = await _calculateStreaks(userId);

      return ProgramStats(
        totalProgramsStarted: totalStarted,
        totalProgramsCompleted: completedCount,
        totalDaysCompleted: totalDaysCompleted,
        currentStreak: streaks['current'] ?? 0,
        longestStreak: streaks['longest'] ?? 0,
      );
    } catch (e) {
      AppLogger.error('Error getting program stats', error: e);
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

    // Reset program progress to day 1
    final progressQuery = await _firestore
        .collection('program_progress')
        .where('userId', isEqualTo: userId)
        .where('programId', isEqualTo: programId)
        .limit(1)
        .get();

    if (progressQuery.docs.isEmpty) {
      throw Exception('Program progress not found');
    }

    final progressRef = progressQuery.docs.first.reference;
    batch.update(progressRef, {
      'currentDay': 1,
      'completedDays': [],
      'lastCompletedAt': null,
      'status': 'active',
      'stats': {
        'totalSessions': 0,
        'averageScore': 0.0,
        'completionPercentage': 0.0,
      },
    });

    await batch.commit();
    AppLogger.info('Program progress reset for $programId');
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
      AppLogger.error('Error getting program', error: e);
      return null;
    }
  }

  Future<void> _completeProgram(String programId, String userId) async {
    AppLogger.info('Completing entire program: $programId');

    final batch = _firestore.batch();

    // Update program progress status to completed
    final progressQuery = await _firestore
        .collection('program_progress')
        .where('userId', isEqualTo: userId)
        .where('programId', isEqualTo: programId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (progressQuery.docs.isNotEmpty) {
      final progressRef = progressQuery.docs.first.reference;
      batch.update(progressRef, {
        'status': 'completed',
        'completedAt': DateTime.now().toIso8601String(),
        'stats.completionPercentage': 100.0,
      });
    }

    await batch.commit();
    AppLogger.info('Program completed and moved to completed programs');
  }

  double _calculateProgressPercentage(int completedDays, int totalDays) {
    if (totalDays == 0) return 0.0;
    return (completedDays / totalDays * 100).clamp(0.0, 100.0);
  }

  Future<Map<String, int>> _calculateStreaks(String userId) async {
    try {
      // Get all completed program progress sorted by completion date
      final progressDocs = await _firestore
          .collection('program_progress')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['active', 'completed'])
          .get();

      // Extract completion dates from all programs
      final completionDates = <DateTime>[];
      for (final doc in progressDocs.docs) {
        final data = doc.data();
        final lastCompleted = data['lastCompletedAt'];
        if (lastCompleted != null) {
          completionDates.add(DateTime.parse(lastCompleted as String));
        }
      }

      if (completionDates.isEmpty) {
        return {'current': 0, 'longest': 0};
      }

      final dates = completionDates
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
      AppLogger.error('Error calculating streaks', error: e);
      return {'current': 0, 'longest': 0};
    }
  }
}

/// Data class for program progress
class ProgramProgress {
  final String programId;
  final int currentDay;
  final List<int> completedDays;
  final int durationDays; // Changed from totalDays for consistency
  final DateTime startedAt;
  final double progressPercentage;
  final DateTime? lastCompletedAt;
  final Map<int, DateTime>? dayCompletionTimes; // When each day was completed

  ProgramProgress({
    required this.programId,
    required this.currentDay,
    required this.completedDays,
    required this.durationDays,
    required this.startedAt,
    required this.progressPercentage,
    this.lastCompletedAt,
    this.dayCompletionTimes,
  });

  bool get isCompleted => completedDays.length >= durationDays;
  bool isDayCompleted(int dayNumber) => completedDays.contains(dayNumber);
  int get remainingDays => durationDays - completedDays.length;
  Duration get timeActive => DateTime.now().difference(startedAt);
  
  /// Check if a specific day is accessible based on time-based rules
  bool isDayAccessible(int dayNumber) {
    // Day 1 is always accessible
    if (dayNumber == 1) return true;
    
    // Check if previous day was completed
    final previousDay = dayNumber - 1;
    if (!isDayCompleted(previousDay)) {
      return false; // Previous day not completed
    }
    
    final previousDayCompletionTime = dayCompletionTimes?[previousDay];
    if (previousDayCompletionTime == null) {
      return false; // Previous day completion time not recorded
    }
    
    // Check if it's been at least 24 hours since previous day completion
    final now = DateTime.now();
    final nextDayUnlockTime = DateTime(
      previousDayCompletionTime.year,
      previousDayCompletionTime.month,
      previousDayCompletionTime.day + 1,
      0, 0, 0, // Unlock at midnight
    );
    
    return now.isAfter(nextDayUnlockTime) || now.isAtSameMomentAs(nextDayUnlockTime);
  }
  
  /// Get the time when a specific day will be unlocked
  DateTime? getDayUnlockTime(int dayNumber) {
    if (dayNumber == 1) return startedAt; // Day 1 unlocks when program starts
    
    final previousDay = dayNumber - 1;
    if (!isDayCompleted(previousDay)) {
      return null; // Previous day not completed yet
    }
    
    final previousDayCompletionTime = dayCompletionTimes?[previousDay];
    if (previousDayCompletionTime == null) {
      return null; // Previous day completion time not recorded
    }
    
    return DateTime(
      previousDayCompletionTime.year,
      previousDayCompletionTime.month,
      previousDayCompletionTime.day + 1,
      0, 0, 0, // Unlock at midnight
    );
  }
  
  /// Get time remaining until next day unlock
  Duration? getTimeUntilDayUnlock(int dayNumber) {
    final unlockTime = getDayUnlockTime(dayNumber);
    if (unlockTime == null) return null;
    
    final now = DateTime.now();
    if (now.isAfter(unlockTime)) return Duration.zero;
    
    return unlockTime.difference(now);
  }
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
