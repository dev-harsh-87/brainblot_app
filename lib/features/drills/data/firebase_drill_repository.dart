import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:spark_app/features/drills/data/drill_repository.dart';
import 'package:spark_app/core/utils/app_logger.dart';
import 'package:uuid/uuid.dart';

/// Firebase implementation using the new clean database structure
/// No duplicate collections, uses tags and proper role-based filtering
class FirebaseDrillRepository implements DrillRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _uuid = const Uuid();

  // Collection names following the new schema
  static const String _drillsCollection = 'drills';
  static const String _userFavoritesCollection = 'user_favorites';
  static const String _usersCollection = 'users';

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

    return _firestore
        .collection(_drillsCollection)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((snapshot) async {
          try {
            final allDrills = _mapSnapshotToDrills(snapshot);
            
            // Filter drills based on user access
            final accessibleDrills = await _filterAccessibleDrills(allDrills, userId);
            
            // Sort by createdAt (newest first)
            accessibleDrills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            
            return accessibleDrills;
          } catch (error) {
            AppLogger.error('Error in watchAll', error: error);
            return <Drill>[];
          }
        });
  }

  @override
  Stream<List<Drill>> watchByCategory(String category) {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_drillsCollection)
        .where('category', isEqualTo: category)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((snapshot) async {
          try {
            final drills = _mapSnapshotToDrills(snapshot);
            final accessibleDrills = await _filterAccessibleDrills(drills, userId);
            accessibleDrills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return accessibleDrills;
          } catch (error) {
            AppLogger.error('Error watching drills by category', error: error);
            return <Drill>[];
          }
        });
  }

  @override
  Stream<List<Drill>> watchByDifficulty(Difficulty difficulty) {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_drillsCollection)
        .where('difficulty', isEqualTo: difficulty.name)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((snapshot) async {
          try {
            final drills = _mapSnapshotToDrills(snapshot);
            final accessibleDrills = await _filterAccessibleDrills(drills, userId);
            accessibleDrills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return accessibleDrills;
          } catch (error) {
            AppLogger.error('Error watching drills by difficulty', error: error);
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
        .collection(_userFavoritesCollection)
        .where('userId', isEqualTo: userId)
        .where('entityType', isEqualTo: 'drill')
        .snapshots()
        .asyncMap((favSnapshot) async {
          try {
            final favoriteIds = favSnapshot.docs
                .map((doc) => doc.data()['entityId'] as String)
                .toList();

            if (favoriteIds.isEmpty) {
              return <Drill>[];
            }

            // Get favorite drills in batches (Firestore 'in' query limit is 10)
            final drills = <Drill>[];
            for (int i = 0; i < favoriteIds.length; i += 10) {
              final batch = favoriteIds.skip(i).take(10).toList();
              final drillSnapshot = await _firestore
                  .collection(_drillsCollection)
                  .where(FieldPath.documentId, whereIn: batch)
                  .where('status', isEqualTo: 'active')
                  .get();
              
              drills.addAll(_mapSnapshotToDrills(drillSnapshot));
            }

            // Sort by createdAt
            drills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return drills;
          } catch (error) {
            AppLogger.error('Error watching favorite drills', error: error);
            return <Drill>[];
          }
        });
  }

  @override
  Future<List<Drill>> fetchAll({String? query, String? category, Difficulty? difficulty}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];

      Query drillQuery = _firestore
          .collection(_drillsCollection)
          .where('status', isEqualTo: 'active');

      // Apply category filter
      if (category != null && category.isNotEmpty) {
        drillQuery = drillQuery.where('category', isEqualTo: category);
      }

      // Apply difficulty filter
      if (difficulty != null) {
        drillQuery = drillQuery.where('difficulty', isEqualTo: difficulty.name);
      }

      final snapshot = await drillQuery.get();
      final allDrills = _mapSnapshotToDrills(snapshot);
      
      // Filter by access permissions
      final accessibleDrills = await _filterAccessibleDrills(allDrills, userId);
      
      // Apply search query filter in memory
      var filteredDrills = accessibleDrills;
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        filteredDrills = filteredDrills.where((drill) => 
          drill.name.toLowerCase().contains(queryLower) ||
          drill.category.toLowerCase().contains(queryLower) ||
          drill.tags.any((tag) => tag.toLowerCase().contains(queryLower))
        ).toList();
      }
      
      // Sort by createdAt (newest first)
      filteredDrills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return filteredDrills;
    } catch (error) {
      AppLogger.error('Error fetching all drills', error: error);
      throw Exception('Failed to fetch drills: $error');
    }
  }

  @override
  Future<List<Drill>> fetchMyDrills({String? query, String? category, Difficulty? difficulty}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      Query drillQuery = _firestore
          .collection(_drillsCollection)
          .where('createdBy', isEqualTo: userId)
          .where('status', isEqualTo: 'active');

      if (category != null && category.isNotEmpty) {
        drillQuery = drillQuery.where('category', isEqualTo: category);
      }

      if (difficulty != null) {
        drillQuery = drillQuery.where('difficulty', isEqualTo: difficulty.name);
      }

      final snapshot = await drillQuery.get();
      List<Drill> drills = _mapSnapshotToDrills(snapshot);

      // Apply search query filter in memory
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        drills = drills.where((drill) => 
          drill.name.toLowerCase().contains(queryLower) ||
          drill.tags.any((tag) => tag.toLowerCase().contains(queryLower))
        ).toList();
      }

      drills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return drills;
    } catch (error) {
      AppLogger.error('Error fetching my drills', error: error);
      throw Exception('Failed to fetch my drills: $error');
    }
  }

  @override
  Future<List<Drill>> fetchAdminDrills({String? query, String? category, Difficulty? difficulty}) async {
    try {
      AppLogger.info('🔍 Fetching admin drills...', tag: 'DrillRepository');
      
      // Try multiple approaches to find admin drills
      List<Drill> adminDrills = [];
      
      // Approach 1: Query by createdByRole = 'admin'
      Query drillQuery = _firestore
          .collection(_drillsCollection)
          .where('createdByRole', isEqualTo: 'admin')
          .where('status', isEqualTo: 'active');

      if (category != null && category.isNotEmpty) {
        drillQuery = drillQuery.where('category', isEqualTo: category);
      }

      if (difficulty != null) {
        drillQuery = drillQuery.where('difficulty', isEqualTo: difficulty.name);
      }

      final snapshot = await drillQuery.get();
      adminDrills = _mapSnapshotToDrills(snapshot);
      
      AppLogger.info('📊 Found ${adminDrills.length} drills with createdByRole=admin', tag: 'DrillRepository');
      
      // Approach 2: If no drills found, try querying by is_admin field
      if (adminDrills.isEmpty) {
        AppLogger.info('🔍 No drills found with createdByRole=admin, trying is_admin field...', tag: 'DrillRepository');
        
        Query adminFlagQuery = _firestore
            .collection(_drillsCollection)
            .where('is_admin', isEqualTo: true)
            .where('status', isEqualTo: 'active');

        if (category != null && category.isNotEmpty) {
          adminFlagQuery = adminFlagQuery.where('category', isEqualTo: category);
        }

        if (difficulty != null) {
          adminFlagQuery = adminFlagQuery.where('difficulty', isEqualTo: difficulty.name);
        }

        final adminFlagSnapshot = await adminFlagQuery.get();
        adminDrills = _mapSnapshotToDrills(adminFlagSnapshot);
        
        AppLogger.info('📊 Found ${adminDrills.length} drills with is_admin=true', tag: 'DrillRepository');
      }
      
      // Approach 3: If still no drills, try finding drills created by admin users
      if (adminDrills.isEmpty) {
        AppLogger.info('🔍 No admin drills found, checking for drills created by admin users...', tag: 'DrillRepository');
        
        // Get admin user IDs
        final adminUsersSnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .get();
        
        final adminUserIds = adminUsersSnapshot.docs.map((doc) => doc.id).toList();
        AppLogger.info('👥 Found ${adminUserIds.length} admin users', tag: 'DrillRepository');
        
        if (adminUserIds.isNotEmpty) {
          // Query drills created by admin users (Firestore 'in' query supports up to 10 values)
          final adminUserIdsToQuery = adminUserIds.take(10).toList();
          
          Query adminUserDrillsQuery = _firestore
              .collection(_drillsCollection)
              .where('createdBy', whereIn: adminUserIdsToQuery)
              .where('status', isEqualTo: 'active');

          if (category != null && category.isNotEmpty) {
            adminUserDrillsQuery = adminUserDrillsQuery.where('category', isEqualTo: category);
          }

          if (difficulty != null) {
            adminUserDrillsQuery = adminUserDrillsQuery.where('difficulty', isEqualTo: difficulty.name);
          }

          final adminUserDrillsSnapshot = await adminUserDrillsQuery.get();
          adminDrills = _mapSnapshotToDrills(adminUserDrillsSnapshot);
          
          AppLogger.info('📊 Found ${adminDrills.length} drills created by admin users', tag: 'DrillRepository');
        }
      }

      // Apply search query filter in memory
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        adminDrills = adminDrills.where((drill) =>
          drill.name.toLowerCase().contains(queryLower) ||
          drill.tags.any((tag) => tag.toLowerCase().contains(queryLower))
        ).toList();
      }

      adminDrills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      AppLogger.info('✅ Returning ${adminDrills.length} admin drills', tag: 'DrillRepository');
      return adminDrills;
    } catch (error) {
      AppLogger.error('Error fetching admin drills', error: error, tag: 'DrillRepository');
      throw Exception('Failed to fetch admin drills: $error');
    }
  }

  @override
  Future<List<Drill>> fetchPublicDrills({String? query, String? category, Difficulty? difficulty}) async {
    try {
      Query drillQuery = _firestore
          .collection(_drillsCollection)
          .where('visibility', isEqualTo: 'public')
          .where('status', isEqualTo: 'active');

      if (category != null && category.isNotEmpty) {
        drillQuery = drillQuery.where('category', isEqualTo: category);
      }

      if (difficulty != null) {
        drillQuery = drillQuery.where('difficulty', isEqualTo: difficulty.name);
      }

      final snapshot = await drillQuery.get();
      List<Drill> drills = _mapSnapshotToDrills(snapshot);

      // Filter out current user's drills
      final userId = _currentUserId;
      if (userId != null) {
        drills = drills.where((drill) => drill.createdBy != userId).toList();
      }

      // Apply search query filter in memory
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        drills = drills.where((drill) =>
          drill.name.toLowerCase().contains(queryLower) ||
          drill.tags.any((tag) => tag.toLowerCase().contains(queryLower))
        ).toList();
      }

      drills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return drills;
    } catch (error) {
      AppLogger.error('Error fetching public drills', error: error);
      throw Exception('Failed to fetch public drills: $error');
    }
  }

  @override
  Future<List<Drill>> fetchFavoriteDrills({String? query, String? category, Difficulty? difficulty}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      // Get user's favorite drill IDs
      final favSnapshot = await _firestore
          .collection(_userFavoritesCollection)
          .where('userId', isEqualTo: userId)
          .where('entityType', isEqualTo: 'drill')
          .get();

      final favoriteIds = favSnapshot.docs
          .map((doc) => doc.data()['entityId'] as String)
          .toList();

      if (favoriteIds.isEmpty) return [];

      // Get favorite drills in batches
      final drills = <Drill>[];
      for (int i = 0; i < favoriteIds.length; i += 10) {
        final batch = favoriteIds.skip(i).take(10).toList();
        Query drillQuery = _firestore
            .collection(_drillsCollection)
            .where(FieldPath.documentId, whereIn: batch)
            .where('status', isEqualTo: 'active');

        if (category != null && category.isNotEmpty) {
          drillQuery = drillQuery.where('category', isEqualTo: category);
        }

        if (difficulty != null) {
          drillQuery = drillQuery.where('difficulty', isEqualTo: difficulty.name);
        }

        final snapshot = await drillQuery.get();
        drills.addAll(_mapSnapshotToDrills(snapshot));
      }

      // Apply search query filter in memory
      var filteredDrills = drills;
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        filteredDrills = drills.where((drill) => 
          drill.name.toLowerCase().contains(queryLower) ||
          drill.tags.any((tag) => tag.toLowerCase().contains(queryLower))
        ).toList();
      }

      filteredDrills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filteredDrills;
    } catch (error) {
      AppLogger.error('Error fetching favorite drills', error: error);
      throw Exception('Failed to fetch favorite drills: $error');
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
        return null;
      }

      final drill = _mapDocumentToDrill(doc);
      if (drill == null) return null;

      // Check if user has access
      final hasAccess = await _hasAccessToDrill(drill, userId);
      return hasAccess ? drill : null;
    } catch (error) {
      AppLogger.error('Error fetching drill by ID', error: error);
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
      // Get user data to determine role
      final userDoc = await _firestore.collection(_usersCollection).doc(userId).get();
      final userData = userDoc.data();
      final userRole = userData?['role'] as String? ?? 'user';

      final drillWithMetadata = _addMetadataToDrill(drill, userId, userRole);
      final drillData = _drillToFirestoreData(drillWithMetadata);

      await _firestore
          .collection(_drillsCollection)
          .doc(drillWithMetadata.id)
          .set(drillData, SetOptions(merge: true));

      return drillWithMetadata;
    } catch (error) {
      AppLogger.error('Error upserting drill', error: error);
      throw Exception('Failed to upsert drill: $error');
    }
  }

  @override
  Future<Drill> create(Drill drill) async {
    return await upsert(drill);
  }

  @override
  Future<void> update(Drill drill) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User must be authenticated to update drills');
    }

    try {
      // Check if user owns this drill or is admin
      final existingDoc = await _firestore
          .collection(_drillsCollection)
          .doc(drill.id)
          .get();

      if (!existingDoc.exists) {
        throw Exception('Drill not found');
      }

      final existingData = existingDoc.data()!;
      final isOwner = existingData['createdBy'] == userId;
      final isAdmin = await _isUserAdmin(userId);

      if (!isOwner && !isAdmin) {
        throw Exception('Not authorized to update this drill');
      }

      final updatedData = _drillToFirestoreData(drill);
      updatedData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_drillsCollection)
          .doc(drill.id)
          .update(updatedData);
    } catch (error) {
      AppLogger.error('Error updating drill', error: error);
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
      final doc = await _firestore
          .collection(_drillsCollection)
          .doc(id)
          .get();

      if (!doc.exists) {
        throw Exception('Drill not found');
      }

      final data = doc.data()!;
      final isOwner = data['createdBy'] == userId;
      final isAdmin = await _isUserAdmin(userId);

      if (!isOwner && !isAdmin) {
        throw Exception('Not authorized to delete this drill');
      }

      // Soft delete by updating status
      await _firestore
          .collection(_drillsCollection)
          .doc(id)
          .update({
            'status': 'archived',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Remove from favorites
      final favSnapshot = await _firestore
          .collection(_userFavoritesCollection)
          .where('entityId', isEqualTo: id)
          .where('entityType', isEqualTo: 'drill')
          .get();

      final batch = _firestore.batch();
      for (final doc in favSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (error) {
      AppLogger.error('Error deleting drill', error: error);
      throw Exception('Failed to delete drill: $error');
    }
  }

  @override
  Future<void> toggleFavorite(String drillId) async {
    final userId = _currentUserId;
    print('🔷 Spark 🔧 toggleFavorite called: drillId=$drillId, userId=$userId');
    
    if (userId == null) {
      print('🔷 Spark ❌ User not authenticated');
      throw Exception('User must be authenticated to manage favorites');
    }

    try {
      print('🔷 Spark 🔍 Checking existing favorites...');
      // Check if already favorited
      final existingFav = await _firestore
          .collection(_userFavoritesCollection)
          .where('userId', isEqualTo: userId)
          .where('entityId', isEqualTo: drillId)
          .where('entityType', isEqualTo: 'drill')
          .get();

      print('🔷 Spark 📊 Found ${existingFav.docs.length} existing favorites');

      if (existingFav.docs.isNotEmpty) {
        // Remove from favorites
        print('🔷 Spark 🗑️ Removing from favorites...');
        await existingFav.docs.first.reference.delete();
        print('🔷 Spark ✅ Successfully removed from favorites');
      } else {
        // Add to favorites
        print('🔷 Spark ➕ Adding to favorites...');
        final docRef = await _firestore
            .collection(_userFavoritesCollection)
            .add({
              'userId': userId,
              'entityId': drillId,
              'entityType': 'drill',
              'createdAt': FieldValue.serverTimestamp(),
            });
        print('🔷 Spark ✅ Successfully added to favorites with ID: ${docRef.id}');
      }
    } catch (error) {
      print('🔷 Spark ❌ Error in toggleFavorite: $error');
      AppLogger.error('Error toggling favorite', error: error);
      throw Exception('Failed to toggle favorite: $error');
    }
  }

  @override
  Future<bool> isFavorite(String drillId) async {
    final userId = _currentUserId;
    print('🔷 Spark 🔍 isFavorite called: drillId=$drillId, userId=$userId');
    
    if (userId == null) {
      print('🔷 Spark ❌ User not authenticated for isFavorite');
      return false;
    }

    try {
      final favSnapshot = await _firestore
          .collection(_userFavoritesCollection)
          .where('userId', isEqualTo: userId)
          .where('entityId', isEqualTo: drillId)
          .where('entityType', isEqualTo: 'drill')
          .get();

      final isFavorite = favSnapshot.docs.isNotEmpty;
      print('🔷 Spark 📊 isFavorite result: $isFavorite (found ${favSnapshot.docs.length} docs)');
      return isFavorite;
    } catch (error) {
      print('🔷 Spark ❌ Error in isFavorite: $error');
      AppLogger.error('Error checking favorite status', error: error);
      return false;
    }
  }

  // Helper methods

  Future<List<Drill>> _filterAccessibleDrills(List<Drill> drills, String userId) async {
    final isAdmin = await _isUserAdmin(userId);

    return drills.where((drill) {
      // Admin can see all drills
      if (isAdmin) return true;
      
      // Own drills
      if (drill.createdBy == userId) return true;
      
      // Public drills
      if (drill.visibility == 'public') return true;
      
      // Shared drills
      if (drill.sharedWith.contains(userId)) return true;
      
      return false;
    }).toList();
  }

  Future<bool> _hasAccessToDrill(Drill drill, String userId) async {
    // Admin can see all drills
    if (await _isUserAdmin(userId)) return true;
    
    // Own drill
    if (drill.createdBy == userId) return true;
    
    // Public drill
    if (drill.visibility == 'public') return true;
    
    // Shared drill
    if (drill.sharedWith.contains(userId)) return true;
    
    return false;
  }

  Future<bool> _isUserAdmin(String userId) async {
    try {
      final userDoc = await _firestore.collection(_usersCollection).doc(userId).get();
      final userData = userDoc.data();
      return userData?['role'] == 'admin' || userData?['is_admin'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _hasModuleAccess(String userId, String module) async {
    try {
      final userDoc = await _firestore.collection(_usersCollection).doc(userId).get();
      final userData = userDoc.data();
      final subscription = userData?['subscription'] as Map<String, dynamic>?;
      final moduleAccess = subscription?['moduleAccess'] as Map<String, dynamic>?;
      return moduleAccess?.containsKey(module) ?? false;
    } catch (e) {
      AppLogger.error('Error checking module access for $module', error: e);
      return false;
    }
  }

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
      AppLogger.error('Error mapping document to drill', error: error);
      return null;
    }
  }

  Drill _addMetadataToDrill(Drill drill, String userId, String userRole) {
    return drill.copyWith(
      id: drill.id.isEmpty ? _uuid.v4() : drill.id,
      createdBy: drill.createdBy ?? userId,
      createdByRole: userRole,
      visibility: drill.visibility.isEmpty ? 'private' : drill.visibility,
      status: 'active',
    );
  }

  Map<String, dynamic> _drillToFirestoreData(Drill drill) {
    final data = drill.toMap();
    
    // Ensure required fields are set
    data['createdBy'] = drill.createdBy ?? _currentUserId;
    data['createdByRole'] = drill.createdByRole;
    data['visibility'] = drill.visibility.isEmpty ? 'private' : drill.visibility;
    data['status'] = drill.status.isEmpty ? 'active' : drill.status;
    data['sharedWith'] = drill.sharedWith;
    data['tags'] = drill.tags;
    
    // Add admin status based on creator's role
    data['is_admin'] = drill.createdByRole == 'admin';
    
    // Use serverTimestamp for createdAt only if it's a new drill
    if (!data.containsKey('createdAt') || data['createdAt'] == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    
    // Add analytics fields if not present
    if (!data.containsKey('analytics')) {
      data['analytics'] = {
        'totalPlays': 0,
        'averageRating': 0.0,
        'totalRatings': 0,
        'totalFavorites': 0,
      };
    }

    return data;
  }

  Drill _firestoreDataToDrill(String id, Map<String, dynamic> data) {
    // Convert Firestore data back to Drill object
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
      description: data['description'] as String? ?? '',
      category: data['category'] as String,
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == data['difficulty'],
        orElse: () => Difficulty.beginner,
      ),
      type: data['type'] as String? ?? 'reaction',
      tags: List<String>.from((data['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[]),
      createdBy: data['createdBy'] as String?,
      createdByRole: data['createdByRole'] as String? ?? 'user',
      visibility: data['visibility'] as String? ?? 'private',
      sharedWith: List<String>.from((data['sharedWith'] as List<dynamic>?)?.cast<String>() ?? <String>[]),
      status: data['status'] as String? ?? 'active',
      
      // Configuration
      durationSec: data['configuration']?['durationSec'] as int? ?? data['durationSec'] as int? ?? 30,
      restSec: data['configuration']?['restSec'] as int? ?? data['restSec'] as int? ?? 10,
      sets: data['configuration']?['sets'] as int? ?? data['sets'] as int? ?? 1,
      reps: data['configuration']?['reps'] as int? ?? data['reps'] as int? ?? 10,
      stimulusTypes: (data['configuration']?['stimulusTypes'] as List? ?? data['stimulusTypes'] as List? ?? ['color'])
          .map((e) => StimulusType.values.firstWhere(
                (s) => s.name == e,
                orElse: () => StimulusType.color,
              ))
          .toList(),
      numberOfStimuli: data['configuration']?['numberOfStimuli'] as int? ?? data['numberOfStimuli'] as int? ?? 4,
      zones: (data['configuration']?['zones'] as List? ?? data['zones'] as List? ?? ['center'])
          .map((e) => ReactionZone.values.firstWhere(
                (z) => z.name == e,
                orElse: () => ReactionZone.center,
              ))
          .toList(),
      colors: (data['configuration']?['colors'] as List? ?? data['colors'] as List? ?? ['#FF0000'])
          .map((hex) => Color(int.parse(
                (hex as String).replaceFirst('#', ''),
                radix: 16,
              )))
          .toList(),
      arrows: (data['configuration']?['arrows'] as List? ?? data['arrows'] as List? ?? ['up', 'down', 'left', 'right'])
          .map((e) => ArrowDirection.values.firstWhere(
                (a) => a.name == e,
                orElse: () => ArrowDirection.up,
              ))
          .toList(),
      shapes: (data['configuration']?['shapes'] as List? ?? data['shapes'] as List? ?? ['circle', 'square', 'triangle'])
          .map((e) => ShapeType.values.firstWhere(
                (s) => s.name == e,
                orElse: () => ShapeType.circle,
              ))
          .toList(),
      numberRange: (data['configuration']?['numberRange'] ?? data['numberRange']) != null
          ? NumberRange.values.firstWhere(
              (n) => n.name == (data['configuration']?['numberRange'] ?? data['numberRange']),
              orElse: () => NumberRange.oneToFive,
            )
          : NumberRange.oneToFive,
      presentationMode: data['configuration']?['presentationMode'] != null
          ? PresentationMode.values.firstWhere(
              (p) => p.name == data['configuration']['presentationMode'],
              orElse: () => PresentationMode.visual,
            )
          : data['presentationMode'] != null
              ? PresentationMode.values.firstWhere(
                  (p) => p.name == data['presentationMode'],
                  orElse: () => PresentationMode.visual,
                )
              : PresentationMode.visual,
      drillMode: data['configuration']?['drillMode'] != null
          ? DrillMode.values.firstWhere(
              (m) => m.name == data['configuration']['drillMode'],
              orElse: () => DrillMode.touch,
            )
          : data['drillMode'] != null
              ? DrillMode.values.firstWhere(
                  (m) => m.name == data['drillMode'],
                  orElse: () => DrillMode.touch,
                )
              : DrillMode.touch,
      stimulusLengthMs: data['configuration']?['stimulusLengthMs'] as int? ?? data['stimulusLengthMs'] as int? ?? 1000,
      delayBetweenStimuliMs: data['configuration']?['delayBetweenStimuliMs'] as int? ?? data['delayBetweenStimuliMs'] as int? ?? 500,
      customStimuliIds: List<String>.from((data['configuration']?['customStimuliIds'] as List<dynamic>?)?.cast<String>() ?? <String>[]),
      
      // Media
      videoUrl: data['media']?['videoUrl'] as String? ?? data['videoUrl'] as String?,
      stepImageUrl: data['media']?['stepImageUrl'] as String? ?? data['stepImageUrl'] as String?,
      
      // Legacy fields for compatibility
      favorite: false, // Will be determined by user_favorites collection
      isPreset: false, // No longer used
      createdAt: createdAt,
    );
  }

  @Deprecated('No longer creating preset drills')
  Future<void> seedDefaultDrills() async {
    // No longer creating preset drills
    AppLogger.info('Preset drills feature removed - users create their own content');
  }
}