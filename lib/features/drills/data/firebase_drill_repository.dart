import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/data/drill_repository.dart';
import 'package:uuid/uuid.dart';

/// Professional Firebase implementation of DrillRepository
/// Follows the new Firestore schema with proper error handling and performance optimization
class FirebaseDrillRepository implements DrillRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _uuid = const Uuid();

  // Collection names following the new schema
  static const String _drillsCollection = 'drills';
  static const String _userFavoritesCollection = 'user_favorites';
  static const String _userDrillsCollection = 'user_drills';

  FirebaseDrillRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  Stream<List<Drill>> watchAll() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    // Watch user's own drills
    return _firestore
        .collection(_drillsCollection)
        .where('createdBy', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          try {
            // Get user's own drills
            final myDrills = _mapSnapshotToDrills(snapshot);
            
            // Get shared drills for current user
            final sharedDrills = await _getSharedDrills(userId);
            
            // Combine and remove duplicates by ID
            final seenIds = <String>{};
            final allDrills = <Drill>[];
            
            for (final drill in [...myDrills, ...sharedDrills]) {
              if (!seenIds.contains(drill.id)) {
                seenIds.add(drill.id);
                allDrills.add(drill);
              }
            }
            
            // Sort by createdAt (newest first)
            allDrills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            
            return allDrills;
          } catch (error) {
            print('❌ Error in watchAll: $error');
            return <Drill>[];
          }
        });
  }

  // Helper method to get drills shared with the current user
  Future<List<Drill>> _getSharedDrills(String userId) async {
    try {
      final sharedDrills = await _firestore
          .collection(_drillsCollection)
          .where('sharedWith', arrayContains: userId)
          .get();
          
      return _mapSnapshotToDrills(sharedDrills);
    } catch (e) {
      print('Error fetching shared drills: $e');
      return [];
    }
  }

  @override
  Stream<List<Drill>> watchByCategory(String category) {
    return _firestore
        .collection(_drillsCollection)
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
          try {
            final drills = _mapSnapshotToDrills(snapshot);
            // Sort by createdAt in memory
            drills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return drills;
          } catch (error) {
            print('Error watching drills by category: $error');
            return <Drill>[];
          }
        });
  }

  @override
  Stream<List<Drill>> watchByDifficulty(Difficulty difficulty) {
    return _firestore
        .collection(_drillsCollection)
        .where('difficulty', isEqualTo: difficulty.name)
        .snapshots()
        .map((snapshot) {
          try {
            final drills = _mapSnapshotToDrills(snapshot);
            // Sort by createdAt in memory
            drills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return drills;
          } catch (error) {
            print('Error watching drills by difficulty: $error');
            return <Drill>[];
          }
        });
  }

  @override
  Stream<List<Drill>> watchFavorites() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_drillsCollection)
        .where('favorite', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          try {
            final drills = _mapSnapshotToDrills(snapshot);
            // Filter to only show user's own drills
            final filtered = drills.where((drill) =>
                drill.createdBy == userId).toList();
            // Sort by createdAt in memory
            filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return filtered;
          } catch (error) {
            print('Error watching favorite drills: $error');
            return <Drill>[];
          }
        });
  }

  @override
  Future<List<Drill>> fetchAll({String? query, String? category, Difficulty? difficulty}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];

      // Get user's own drills
      final myDrillsSnapshot = await _firestore
          .collection(_drillsCollection)
          .where('createdBy', isEqualTo: userId)
          .get();
      List<Drill> myDrills = _mapSnapshotToDrills(myDrillsSnapshot);

      // Get drills shared with the user
      final sharedDrills = await _getSharedDrills(userId);

      // Combine user's drills + shared drills, removing duplicates by ID
      final seenIds = <String>{};
      final allDrills = <Drill>[];
      
      for (final drill in [...myDrills, ...sharedDrills]) {
        if (!seenIds.contains(drill.id)) {
          seenIds.add(drill.id);
          allDrills.add(drill);
        }
      }
      
      // Apply filters in memory
      var filteredDrills = allDrills;
      
      if (category != null && category.isNotEmpty) {
        filteredDrills = filteredDrills.where((drill) => drill.category == category).toList();
      }
      
      if (difficulty != null) {
        filteredDrills = filteredDrills.where((drill) => drill.difficulty == difficulty).toList();
      }
      
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        filteredDrills = filteredDrills.where((drill) => 
          drill.name.toLowerCase().contains(queryLower) ||
          (drill.category?.toLowerCase().contains(queryLower) ?? false)
        ).toList();
      }
      
      // Sort by createdAt (newest first)
      filteredDrills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return filteredDrills;
    } catch (error) {
      print('❌ Error fetching all drills: $error');
      throw Exception('Failed to fetch drills: $error');
    }
  }

  @override
  Future<Drill?> fetchById(String id) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return null;

      final doc = await _firestore
          .collection(_drillsCollection)
          .doc(id)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null; // Document doesn't exist or has no data
      }

      final data = doc.data()!; // Safe to use ! here as we checked data() != null
      final List<String> sharedWith = (data['sharedWith'] as List<dynamic>?)
              ?.whereType<String>()
              .where((s) => s.isNotEmpty)
              .toList() ?? 
          <String>[];
      final createdBy = data['createdBy'] as String?;

      // Check if user has access (is owner, is public, or is in sharedWith)
      final hasAccess = createdBy == userId ||
                       sharedWith.contains(userId);

      if (!hasAccess) {
        return null; // User doesn't have access to this drill
      }

      return _mapDocumentToDrill(doc);
    } catch (error) {
      print('Error fetching drill by ID: $error');
      throw Exception('Failed to fetch drill: $error');
    }
  }

  @override
  Future<Drill> upsert(Drill drill) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to create/update drills');
    }

    try {
      final drillWithMetadata = _addMetadataToDrill(drill, userId);
      final drillData = _drillToFirestoreData(drillWithMetadata);

      final batch = _firestore.batch();

      // Add to global drills collection
      final drillRef = _firestore
          .collection(_drillsCollection)
          .doc(drillWithMetadata.id);
      batch.set(drillRef, drillData, SetOptions(merge: true));

      // Add to user's drills collection if it's a user-created drill (not preset)
      if (!drillWithMetadata.isPreset) {
        final userDrillRef = _firestore
            .collection(_userDrillsCollection)
            .doc(userId)
            .collection('drills')
            .doc(drillWithMetadata.id);
        batch.set(
          userDrillRef, 
          {
            'drillId': drillWithMetadata.id,
            'createdAt': FieldValue.serverTimestamp(),
            'isCustom': true,
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      return drillWithMetadata;
    } catch (error) {
      throw Exception('Failed to upsert drill: $error');
    }
  }

  @override
  Future<Drill> create(Drill drill) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to create drills');
    }
    
    // Delegate to upsert since they share the same logic
    return await upsert(drill);
  }

  @override
  Future<void> update(Drill drill) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to update drills');
    }

    try {
      // Check if user owns this drill
      final existingDoc = await _firestore
          .collection(_drillsCollection)
          .doc(drill.id)
          .get();

      if (!existingDoc.exists) {
        throw Exception('Drill not found');
      }

      final existingData = existingDoc.data()!;
      if (existingData['createdBy'] != userId && existingData['isPreset'] == true) {
        throw Exception('Not authorized to update this drill');
      }

      final updatedData = _drillToFirestoreData(drill);
      updatedData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_drillsCollection)
          .doc(drill.id)
          .update(updatedData);

      // Drill updated successfully
    } catch (error) {
      print('Error updating drill: $error');
      throw Exception('Failed to update drill: $error');
    }
  }

  @override
  Future<void> delete(String id) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to delete drills');
    }

    try {
      // Check if user owns this drill
      final doc = await _firestore
          .collection(_drillsCollection)
          .doc(id)
          .get();

      if (!doc.exists) {
        throw Exception('Drill not found');
      }

      final data = doc.data()!;
      if (data['createdBy'] != userId) {
        throw Exception('Not authorized to delete this drill');
      }

      if (data['isPreset'] == true) {
        throw Exception('Cannot delete preset drills');
      }

      final batch = _firestore.batch();

      // Remove from global drills collection
      final drillRef = _firestore
          .collection(_drillsCollection)
          .doc(id);
      batch.delete(drillRef);

      // Remove from user's drills collection
      final userDrillRef = _firestore
          .collection(_userDrillsCollection)
          .doc(userId)
          .collection('drills')
          .doc(id);
      batch.delete(userDrillRef);

      await batch.commit();

      // Drill deleted successfully
    } catch (error) {
      print('Error deleting drill: $error');
      throw Exception('Failed to delete drill: $error');
    }
  }

  @override
  Future<void> toggleFavorite(String drillId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to manage favorites');
    }

    try {
      final drillDoc = await _firestore
          .collection(_drillsCollection)
          .doc(drillId)
          .get();

      if (!drillDoc.exists) {
        throw Exception('Drill not found');
      }

      final drill = _firestoreDataToDrill(drillDoc.id, drillDoc.data()!);
      
      // Users can only favorite their own drills
      if (drill.createdBy == userId) {
        await _firestore
            .collection(_drillsCollection)
            .doc(drillId)
            .update({'favorite': !drill.favorite});
      }

      // Favorite toggled for drill
    } catch (error) {
      print('Error toggling favorite: $error');
      throw Exception('Failed to toggle favorite: $error');
    }
  }

  @override
  Future<bool> isFavorite(String drillId) async {
    try {
      final drillDoc = await _firestore
          .collection(_drillsCollection)
          .doc(drillId)
          .get();

      if (!drillDoc.exists) {
        return false;
      }

      final data = drillDoc.data()!;
      return data['favorite'] as bool? ?? false;
    } catch (error) {
      print('Error checking favorite status: $error');
      return false;
    }
  }

  /// REMOVED: No longer seeding default/preset drills
  /// Users must create their own drills
  @Deprecated('Preset drills removed - users create their own content')
  Future<void> seedDefaultDrills() async {
    // No longer creating preset drills
    // Users will create their own drills from scratch
    print('ℹ️ Preset drills feature removed - users create their own content');
  }

  // Helper methods

  List<Drill> _mapSnapshotToDrills(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => _mapDocumentToDrill(doc))
        .where((drill) => drill != null)
        .cast<Drill>()
        .toList();
  }

  Drill? _mapDocumentToDrill(DocumentSnapshot doc) {
    try {
      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      return _firestoreDataToDrill(doc.id, data);
    } catch (error) {
      print('Error mapping document to drill: $error');
      return null;
    }
  }

  Drill _addMetadataToDrill(Drill drill, String userId) {
    return drill.copyWith(
      id: drill.id.isEmpty ? _uuid.v4() : drill.id,
      createdBy: drill.createdBy ?? userId,
      isPreset: false, // All user-created drills are NOT presets
    );
  }

  Map<String, dynamic> _drillToFirestoreData(Drill drill) {
    final data = drill.toMap();
    
    // Ensure required Firestore fields are set correctly
    data['createdBy'] = drill.createdBy ?? _currentUserId;
    data['isPreset'] = false; // No more preset drills
    data['sharedWith'] = drill.sharedWith.isNotEmpty ? drill.sharedWith : [];
    data['favorite'] = drill.favorite;
    
    // Use serverTimestamp for createdAt only if it's a new drill
    // For updates, preserve the original createdAt
    if (!data.containsKey('createdAt') || data['createdAt'] == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['version'] = 1;
    
    // Add analytics fields if not present
    if (!data.containsKey('analytics')) {
      data['analytics'] = {
        'totalPlays': 0,
        'averageRating': 0.0,
        'totalRatings': 0,
      };
    }

    // Add metadata if not present
    if (!data.containsKey('metadata')) {
      data['metadata'] = {
        'instructions': 'Follow the on-screen prompts and react as quickly as possible.',
        'tips': ['Stay focused', 'React quickly', 'Maintain accuracy'],
        'equipment': ['Mobile device or computer'],
        'targetSkills': ['Reaction time', 'Visual processing', 'Hand-eye coordination'],
      };
    }

    return data;
  }

  Drill _firestoreDataToDrill(String id, Map<String, dynamic> data) {
    // Convert Firestore data back to Drill object
    // Handle createdAt field - could be Timestamp or null
    DateTime createdAt = DateTime.now();
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        createdAt = DateTime.parse(data['createdAt'] as String);
      }
    }

    return Drill(
      id: id,
      name: data['name'] as String,
      category: data['category'] as String,
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == data['difficulty'],
        orElse: () => Difficulty.beginner,
      ),
      durationSec: data['durationSec'] as int,
      restSec: data['restSec'] as int,
      reps: data['reps'] as int,
      stimulusTypes: (data['stimulusTypes'] as List)
          .map((e) => StimulusType.values.firstWhere(
                (s) => s.name == e,
                orElse: () => StimulusType.color,
              ))
          .toList(),
      numberOfStimuli: data['numberOfStimuli'] as int,
      zones: (data['zones'] as List)
          .map((e) => ReactionZone.values.firstWhere(
                (z) => z.name == e,
                orElse: () => ReactionZone.center,
              ))
          .toList(),
      colors: (data['colors'] as List)
          .map((hex) => Color(int.parse(
                (hex as String).replaceFirst('#', ''),
                radix: 16,
              )))
          .toList(),
      favorite: data['favorite'] as bool? ?? false,
      isPreset: data['isPreset'] as bool? ?? false,
      createdBy: data['createdBy'] as String?,
      sharedWith: List<String>.from((data['sharedWith'] as List<dynamic>?)?.cast<String>() ?? <String>[]),
      createdAt: createdAt,
    );
  }

  /// REMOVED: No longer creating default drills
  @Deprecated('Preset drills removed - users create their own content')
  List<Drill> _createDefaultDrills() {
    // No longer creating default drills
    return [];
  }

  @override
  Future<List<Drill>> fetchMyDrills({String? query, String? category, Difficulty? difficulty}) async {
    final userId = _currentUserId;
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(_drillsCollection)
          .where('createdBy', isEqualTo: userId)
          .get();
      
      List<Drill> drills = _mapSnapshotToDrills(snapshot);

      // Apply filters in memory to avoid complex Firestore indexes
      if (category != null && category.isNotEmpty) {
        drills = drills.where((drill) => drill.category == category).toList();
      }

      if (difficulty != null) {
        drills = drills.where((drill) => drill.difficulty == difficulty).toList();
      }

      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        drills = drills.where((drill) => 
            drill.name.toLowerCase().contains(queryLower)).toList();
      }

      // Sort by createdAt
      drills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return drills;
    } catch (error) {
      print('Error fetching my drills: $error');
      throw Exception('Failed to fetch my drills: $error');
    }
  }

  @override
  Future<List<Drill>> fetchPublicDrills({String? query, String? category, Difficulty? difficulty}) async {
    final userId = _currentUserId;
    
    try {
      // Start with just public drills to avoid complex index
      final snapshot = await _firestore
          .collection(_drillsCollection)
          .get();
      
      List<Drill> drills = _mapSnapshotToDrills(snapshot);

      // Apply all filters in memory to avoid complex indexes
      if (category != null && category.isNotEmpty) {
        drills = drills.where((drill) => drill.category == category).toList();
      }

      if (difficulty != null) {
        drills = drills.where((drill) => drill.difficulty == difficulty).toList();
      }

      // Filter out current user's drills
      if (userId != null) {
        drills = drills.where((drill) => drill.createdBy != userId).toList();
      }

      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        drills = drills.where((drill) =>
            drill.name.toLowerCase().contains(queryLower)).toList();
      }

      // Sort by createdAt
      drills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return drills;
    } catch (error) {
      print('Error fetching public drills: $error');
      throw Exception('Failed to fetch public drills: $error');
    }
  }

  @override
  Future<List<Drill>> fetchAdminDrills({String? query, String? category, Difficulty? difficulty}) async {
    try {
      // First, get all users with admin role
      final usersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      
      final adminUserIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      
      if (adminUserIds.isEmpty) {
        return [];
      }
      
      // Fetch drills created by admin users
      final snapshot = await _firestore
          .collection(_drillsCollection)
          .get();
      
      List<Drill> drills = _mapSnapshotToDrills(snapshot);

      // Filter to only include drills created by admin users
      drills = drills.where((drill) => adminUserIds.contains(drill.createdBy)).toList();

      // Apply filters in memory
      if (category != null && category.isNotEmpty) {
        drills = drills.where((drill) => drill.category == category).toList();
      }

      if (difficulty != null) {
        drills = drills.where((drill) => drill.difficulty == difficulty).toList();
      }

      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        drills = drills.where((drill) =>
            drill.name.toLowerCase().contains(queryLower)).toList();
      }

      // Sort by createdAt
      drills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return drills;
    } catch (error) {
      print('Error fetching admin drills: $error');
      throw Exception('Failed to fetch admin drills: $error');
    }
  }

  @override
  Future<List<Drill>> fetchFavoriteDrills({String? query, String? category, Difficulty? difficulty}) async {
    final userId = _currentUserId;
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(_drillsCollection)
          .where('favorite', isEqualTo: true)
          .get();
      
      List<Drill> drills = _mapSnapshotToDrills(snapshot);

      // Filter to only show drills user can see (their own or public ones)
      drills = drills.where((drill) =>
          drill.createdBy == userId).toList();

      // Apply filters in memory to avoid complex indexes
      if (category != null && category.isNotEmpty) {
        drills = drills.where((drill) => drill.category == category).toList();
      }

      if (difficulty != null) {
        drills = drills.where((drill) => drill.difficulty == difficulty).toList();
      }

      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        drills = drills.where((drill) => 
            drill.name.toLowerCase().contains(queryLower)).toList();
      }

      // Sort by createdAt
      drills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return drills;
    } catch (error) {
      print('Error fetching favorite drills: $error');
      throw Exception('Failed to fetch favorite drills: $error');
    }
  }
}
