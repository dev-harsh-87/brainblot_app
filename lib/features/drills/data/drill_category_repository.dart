import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/features/drills/domain/drill_category.dart';

class DrillCategoryRepository {
  final FirebaseFirestore _firestore;

  DrillCategoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get all active categories ordered by order field
  Future<List<DrillCategory>> getActiveCategories() async {
    try {
      final snapshot = await _firestore
          .collection('drill_categories')
          .where('isActive', isEqualTo: true)
          .get();

      final categories = snapshot.docs
          .map((doc) => DrillCategory.fromMap(doc.data()))
          .toList();
      
      // Sort in memory to avoid requiring composite index
      categories.sort((a, b) {
        final orderCompare = a.order.compareTo(b.order);
        if (orderCompare != 0) return orderCompare;
        return a.displayName.compareTo(b.displayName);
      });

      return categories;
    } catch (e) {
      print('❌ Error fetching active categories: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Get all categories (admin only)
  Future<List<DrillCategory>> getAllCategories() async {
    try {
      final snapshot = await _firestore
          .collection('drill_categories')
          .get();

      final categories = snapshot.docs
          .map((doc) => DrillCategory.fromMap(doc.data()))
          .toList();
      
      // Sort in memory to avoid requiring composite index
      categories.sort((a, b) {
        final orderCompare = a.order.compareTo(b.order);
        if (orderCompare != 0) return orderCompare;
        return a.displayName.compareTo(b.displayName);
      });

      return categories;
    } catch (e) {
      print('❌ Error fetching all categories: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Get category by ID
  Future<DrillCategory?> getCategoryById(String id) async {
    try {
      final doc = await _firestore.collection('drill_categories').doc(id).get();
      if (!doc.exists) return null;
      return DrillCategory.fromMap(doc.data()!);
    } catch (e) {
      print('Error fetching category: $e');
      return null;
    }
  }

  /// Create a new category
  Future<void> createCategory(DrillCategory category) async {
    try {
      await _firestore
          .collection('drill_categories')
          .doc(category.id)
          .set(category.toMap());
    } catch (e) {
      print('Error creating category: $e');
      rethrow;
    }
  }

  /// Update an existing category
  Future<void> updateCategory(DrillCategory category) async {
    try {
      final updatedCategory = category.copyWith(
        updatedAt: DateTime.now(),
      );
      await _firestore
          .collection('drill_categories')
          .doc(category.id)
          .update(updatedCategory.toMap());
    } catch (e) {
      print('Error updating category: $e');
      rethrow;
    }
  }

  /// Delete a category (soft delete by setting isActive to false)
  Future<void> deleteCategory(String id) async {
    try {
      await _firestore.collection('drill_categories').doc(id).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error deleting category: $e');
      rethrow;
    }
  }

  /// Permanently delete a category (hard delete)
  Future<void> permanentlyDeleteCategory(String id) async {
    try {
      await _firestore.collection('drill_categories').doc(id).delete();
    } catch (e) {
      print('Error permanently deleting category: $e');
      rethrow;
    }
  }

  /// Toggle category active status
  Future<void> toggleCategoryStatus(String id, bool isActive) async {
    try {
      await _firestore.collection('drill_categories').doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error toggling category status: $e');
      rethrow;
    }
  }

  /// Reorder categories
  Future<void> reorderCategories(List<DrillCategory> categories) async {
    try {
      final batch = _firestore.batch();
      for (var i = 0; i < categories.length; i++) {
        final category = categories[i].copyWith(
          order: i,
          updatedAt: DateTime.now(),
        );
        batch.update(
          _firestore.collection('drill_categories').doc(category.id),
          category.toMap(),
        );
      }
      await batch.commit();
    } catch (e) {
      print('Error reordering categories: $e');
      rethrow;
    }
  }

  /// Stream of active categories
  Stream<List<DrillCategory>> watchActiveCategories() {
    return _firestore
        .collection('drill_categories')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => DrillCategory.fromMap(doc.data()))
              .toList();
          
          // Sort in memory
          categories.sort((a, b) {
            final orderCompare = a.order.compareTo(b.order);
            if (orderCompare != 0) return orderCompare;
            return a.displayName.compareTo(b.displayName);
          });
          
          return categories;
        });
  }

  /// Stream of all categories (admin only)
  Stream<List<DrillCategory>> watchAllCategories() {
    return _firestore
        .collection('drill_categories')
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => DrillCategory.fromMap(doc.data()))
              .toList();
          
          // Sort in memory
          categories.sort((a, b) {
            final orderCompare = a.order.compareTo(b.order);
            if (orderCompare != 0) return orderCompare;
            return a.displayName.compareTo(b.displayName);
          });
          
          return categories;
        });
  }
}