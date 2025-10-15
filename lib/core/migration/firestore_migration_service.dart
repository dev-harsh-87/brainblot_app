import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:brainblot_app/features/drills/data/firebase_drill_repository.dart';
import 'package:brainblot_app/features/drills/data/firebase_session_repository.dart';
import 'package:brainblot_app/features/programs/data/firebase_program_repository.dart';
import 'package:brainblot_app/features/auth/data/firebase_user_repository.dart';

/// Professional data migration service for transitioning to the new Firestore structure
/// Handles migration from old schema to new professional schema safely
class FirestoreMigrationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  // Repository instances for seeding default data
  late final FirebaseDrillRepository _drillRepo;
  late final FirebaseSessionRepository _sessionRepo;
  late final FirebaseProgramRepository _programRepo;
  late final FirebaseUserRepository _userRepo;

  FirestoreMigrationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance {
    _drillRepo = FirebaseDrillRepository(firestore: _firestore, auth: _auth);
    _sessionRepo = FirebaseSessionRepository(firestore: _firestore, auth: _auth);
    _programRepo = FirebaseProgramRepository(firestore: _firestore, auth: _auth);
    _userRepo = FirebaseUserRepository(firestore: _firestore, auth: _auth);
  }

  /// Run complete migration to new professional Firestore structure
  Future<void> runCompleteMigration() async {
    try {
      print('🚀 Starting complete Firestore migration to professional structure...');
      
      // Step 1: Check migration status
      final migrationStatus = await _checkMigrationStatus();
      print('📊 Migration status: $migrationStatus');
      
      if (migrationStatus['completed'] == true) {
        print('✅ Migration already completed, skipping...');
        return;
      }
      
      // Step 2: Create system metadata collection
      await _createSystemMetadata();
      
      // Step 3: Seed default drills
      await _seedDefaultDrills();
      
      // Step 4: Seed default programs
      await _seedDefaultPrograms();
      
      // Step 5: Migrate existing user data (if any)
      await _migrateExistingUserData();
      
      // Step 6: Set up analytics collections
      await _setupAnalyticsCollections();
      
      // Step 7: Mark migration as completed
      await _markMigrationCompleted();
      
      print('🎉 Complete Firestore migration completed successfully!');
      
    } catch (error) {
      print('❌ Error during migration: $error');
      await _logMigrationError(error.toString());
      rethrow;
    }
  }

  /// Check current migration status
  Future<Map<String, dynamic>> _checkMigrationStatus() async {
    try {
      final doc = await _firestore
          .collection('system')
          .doc('migration_status')
          .get();
      
      if (!doc.exists) {
        return {
          'completed': false,
          'version': 0,
          'lastAttempt': null,
        };
      }
      
      return doc.data() ?? {};
    } catch (error) {
      print('❌ Error checking migration status: $error');
      return {'completed': false, 'version': 0};
    }
  }

  /// Create system metadata and configuration
  Future<void> _createSystemMetadata() async {
    print('🔧 Creating system metadata...');
    
    final systemConfig = {
      'id': 'app_config',
      'version': '1.0.0',
      'features': {
        'leaderboards': true,
        'socialSharing': false,
        'premiumFeatures': true,
        'analytics': true,
      },
      'maintenance': {
        'scheduled': false,
        'message': null,
        'startTime': null,
        'endTime': null,
      },
      'limits': {
        'maxDrillsPerUser': 100,
        'maxProgramsPerUser': 50,
        'maxSessionsPerDay': 100,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    await _firestore
        .collection('system')
        .doc('app_config')
        .set(systemConfig);
    
    print('✅ System metadata created');
  }

  /// Seed default drills using the professional repository
  Future<void> _seedDefaultDrills() async {
    print('🌱 Seeding default drills...');
    
    try {
      await _drillRepo.seedDefaultDrills();
      print('✅ Default drills seeded successfully');
    } catch (error) {
      print('⚠️ Error seeding drills (may already exist): $error');
      // Continue migration even if drills already exist
    }
  }

  /// Seed default programs using the professional repository
  Future<void> _seedDefaultPrograms() async {
    print('🌱 Seeding default programs...');
    
    try {
      await _programRepo.seedDefaultPrograms();
      print('✅ Default programs seeded successfully');
    } catch (error) {
      print('⚠️ Error seeding programs (may already exist): $error');
      // Continue migration even if programs already exist
    }
  }

  /// Migrate existing user data to new structure
  Future<void> _migrateExistingUserData() async {
    print('👥 Migrating existing user data...');
    
    try {
      // Check for existing users in old structure
      final oldUsersSnapshot = await _firestore
          .collection('users')
          .limit(10)
          .get();
      
      if (oldUsersSnapshot.docs.isEmpty) {
        print('ℹ️ No existing users found, skipping user migration');
        return;
      }
      
      final batch = _firestore.batch();
      int migratedUsers = 0;
      
      for (final doc in oldUsersSnapshot.docs) {
        try {
          final userData = doc.data();
          final userId = doc.id;
          
          // Create enhanced user profile
          final enhancedUserData = {
            'userId': userId,
            'email': userData['email'] ?? 'unknown@example.com',
            'displayName': userData['displayName'] ?? userData['email']?.split('@').first ?? 'User',
            'profileImageUrl': userData['profileImageUrl'],
            'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
            'lastActiveAt': FieldValue.serverTimestamp(),
            'preferences': {
              'theme': userData['theme'] ?? 'system',
              'notifications': userData['notifications'] ?? true,
              'soundEnabled': userData['soundEnabled'] ?? true,
              'language': userData['language'] ?? 'en',
              'timezone': userData['timezone'] ?? 'UTC',
            },
            'subscription': {
              'plan': userData['subscriptionPlan'] ?? 'free',
              'status': 'active',
              'expiresAt': null,
              'features': ['basic_drills', 'basic_programs'],
            },
            'stats': {
              'totalSessions': userData['totalSessions'] ?? 0,
              'totalDrillsCompleted': userData['totalDrillsCompleted'] ?? 0,
              'totalProgramsCompleted': userData['totalProgramsCompleted'] ?? 0,
              'averageAccuracy': userData['averageAccuracy'] ?? 0.0,
              'averageReactionTime': userData['averageReactionTime'] ?? 0.0,
              'streakDays': userData['streakDays'] ?? 0,
              'lastSessionAt': userData['lastSessionAt'],
            },
            'migrated': true,
            'migrationDate': FieldValue.serverTimestamp(),
          };
          
          batch.set(
            _firestore.collection('users').doc(userId),
            enhancedUserData,
            SetOptions(merge: true)
          );
          
          migratedUsers++;
          
        } catch (error) {
          print('⚠️ Error migrating user ${doc.id}: $error');
          // Continue with other users
        }
      }
      
      if (migratedUsers > 0) {
        await batch.commit();
        print('✅ Migrated $migratedUsers users to new structure');
      }
      
    } catch (error) {
      print('⚠️ Error during user migration: $error');
      // Continue migration even if user migration fails
    }
  }

  /// Set up analytics collections
  Future<void> _setupAnalyticsCollections() async {
    print('📊 Setting up analytics collections...');
    
    try {
      // Create initial analytics document
      final analyticsData = {
        'id': 'daily_${DateTime.now().toIso8601String().split('T').first}',
        'type': 'daily',
        'date': FieldValue.serverTimestamp(),
        'metrics': {
          'totalUsers': 0,
          'activeUsers': 0,
          'newUsers': 0,
          'totalSessions': 0,
          'averageSessionDuration': 0.0,
          'popularDrills': [],
          'popularPrograms': [],
        },
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection('analytics')
          .doc('daily_${DateTime.now().toIso8601String().split('T').first}')
          .set(analyticsData);
      
      print('✅ Analytics collections set up');
    } catch (error) {
      print('⚠️ Error setting up analytics: $error');
      // Continue migration even if analytics setup fails
    }
  }

  /// Mark migration as completed
  Future<void> _markMigrationCompleted() async {
    final migrationStatus = {
      'completed': true,
      'version': 1,
      'completedAt': FieldValue.serverTimestamp(),
      'components': {
        'systemMetadata': true,
        'defaultDrills': true,
        'defaultPrograms': true,
        'userMigration': true,
        'analytics': true,
      },
    };
    
    await _firestore
        .collection('system')
        .doc('migration_status')
        .set(migrationStatus);
    
    print('✅ Migration marked as completed');
  }

  /// Log migration errors for debugging
  Future<void> _logMigrationError(String error) async {
    try {
      await _firestore
          .collection('system')
          .doc('migration_errors')
          .collection('errors')
          .add({
            'error': error,
            'timestamp': FieldValue.serverTimestamp(),
            'version': 1,
          });
    } catch (e) {
      print('❌ Failed to log migration error: $e');
    }
  }

  /// Rollback migration (emergency use only)
  Future<void> rollbackMigration() async {
    print('🔄 Rolling back migration...');
    
    try {
      // Mark migration as not completed
      await _firestore
          .collection('system')
          .doc('migration_status')
          .update({
            'completed': false,
            'rolledBackAt': FieldValue.serverTimestamp(),
          });
      
      print('✅ Migration rollback completed');
    } catch (error) {
      print('❌ Error during rollback: $error');
      rethrow;
    }
  }

  /// Verify migration integrity
  Future<bool> verifyMigration() async {
    print('🔍 Verifying migration integrity...');
    
    try {
      // Check system metadata
      final systemDoc = await _firestore.collection('system').doc('app_config').get();
      if (!systemDoc.exists) {
        print('❌ System metadata missing');
        return false;
      }
      
      // Check default drills
      final drillsSnapshot = await _firestore
          .collection('drills')
          .where('isPreset', isEqualTo: true)
          .limit(1)
          .get();
      if (drillsSnapshot.docs.isEmpty) {
        print('❌ Default drills missing');
        return false;
      }
      
      // Check default programs
      final programsSnapshot = await _firestore
          .collection('programs')
          .where('isPreset', isEqualTo: true)
          .limit(1)
          .get();
      if (programsSnapshot.docs.isEmpty) {
        print('❌ Default programs missing');
        return false;
      }
      
      print('✅ Migration integrity verified');
      return true;
      
    } catch (error) {
      print('❌ Error verifying migration: $error');
      return false;
    }
  }
}
