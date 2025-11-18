import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spark_app/features/admin/domain/custom_stimulus.dart';

class CustomStimulusRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'custom_stimuli';

  // Get all custom stimuli
  Future<List<CustomStimulus>> getAllCustomStimuli() async {
    try {
      // Use simpler query to avoid index requirement
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final stimuli = querySnapshot.docs
          .map((doc) => CustomStimulus.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
      
      // Sort in memory instead of using Firestore orderBy
      stimuli.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return stimuli;
    } catch (e) {
      print('Error getting custom stimuli: $e');
      return [];
    }
  }

  // Get custom stimuli by type
  Future<List<CustomStimulus>> getCustomStimuliByType(CustomStimulusType type) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: type.name)
          .where('isActive', isEqualTo: true)
          .get();

      final stimuli = querySnapshot.docs
          .map((doc) => CustomStimulus.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
      
      // Sort in memory instead of using Firestore orderBy
      stimuli.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return stimuli;
    } catch (e) {
      print('Error getting custom stimuli by type: $e');
      return [];
    }
  }

  // Get custom stimulus by ID
  Future<CustomStimulus?> getCustomStimulusById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      
      if (doc.exists) {
        return CustomStimulus.fromJson({
          'id': doc.id,
          ...doc.data()!,
        });
      }
      return null;
    } catch (e) {
      print('Error getting custom stimulus by ID: $e');
      return null;
    }
  }

  // Create new custom stimulus
  Future<String> createCustomStimulus(CustomStimulus stimulus) async {
    try {
      // Use the stimulus ID as the document ID for consistency
      await _firestore
          .collection(_collection)
          .doc(stimulus.id)
          .set(stimulus.toJson());
      return stimulus.id;
    } catch (e) {
      print('Error creating custom stimulus: $e');
      throw Exception('Failed to create custom stimulus: $e');
    }
  }

  // Update custom stimulus
  Future<void> updateCustomStimulus(CustomStimulus stimulus) async {
    try {
      // Use set with merge to handle cases where document might not exist
      await _firestore
          .collection(_collection)
          .doc(stimulus.id)
          .set(stimulus.copyWith(updatedAt: DateTime.now()).toJson(), SetOptions(merge: true));
    } catch (e) {
      print('Error updating custom stimulus: $e');
      throw Exception('Failed to update custom stimulus: $e');
    }
  }

  // Delete custom stimulus (hard delete)
  Future<void> deleteCustomStimulus(String id) async {
    try {
      // First check if the document exists
      final docRef = _firestore.collection(_collection).doc(id);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        print('Document with ID $id does not exist, already deleted');
        return; // Document doesn't exist, consider it already deleted
      }
      
      // Document exists, perform hard delete
      await docRef.delete();
      
      print('Successfully deleted custom stimulus: $id');
    } catch (e) {
      print('Error deleting custom stimulus: $e');
      
      // If it's a not-found error, we can consider it already deleted
      if (e.toString().contains('not-found') || e.toString().contains('NOT_FOUND')) {
        print('Document not found during delete, considering it already deleted');
        return;
      }
      
      throw Exception('Failed to delete custom stimulus: $e');
    }
  }

  // Add a method for soft delete if needed in the future
  Future<void> softDeleteCustomStimulus(String id) async {
    try {
      final docRef = _firestore.collection(_collection).doc(id);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        print('Document with ID $id does not exist for soft delete');
        return;
      }
      
      await docRef.update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('Successfully soft-deleted custom stimulus: $id');
    } catch (e) {
      print('Error soft-deleting custom stimulus: $e');
      throw Exception('Failed to soft-delete custom stimulus: $e');
    }
  }

  // Get custom stimuli created by specific user
  Future<List<CustomStimulus>> getCustomStimuliByCreator(String creatorId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: creatorId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => CustomStimulus.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      print('Error getting custom stimuli by creator: $e');
      return [];
    }
  }

  // Stream of custom stimuli for real-time updates
  Stream<List<CustomStimulus>> streamCustomStimuli() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final stimuli = snapshot.docs
              .map((doc) => CustomStimulus.fromJson({
                    'id': doc.id,
                    ...doc.data(),
                  }))
              .toList();
          
          // Sort in memory instead of using Firestore orderBy to avoid index requirement
          stimuli.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return stimuli;
        });
  }

  // Search custom stimuli by name
  Future<List<CustomStimulus>> searchCustomStimuli(String searchTerm) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => CustomStimulus.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .where((stimulus) => 
              stimulus.name.toLowerCase().contains(searchTerm.toLowerCase()) ||
              stimulus.description.toLowerCase().contains(searchTerm.toLowerCase()))
          .toList();
    } catch (e) {
      print('Error searching custom stimuli: $e');
      return [];
    }
  }
}