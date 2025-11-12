import 'package:spark_app/features/drills/domain/drill_category.dart';
import 'package:spark_app/features/drills/data/drill_category_repository.dart';

class CategoryInitializationService {
  final DrillCategoryRepository _repository = DrillCategoryRepository();

  /// Initialize default drill categories
  Future<void> initializeDefaultCategories() async {
    try {
      print('🏷️ Checking for existing categories...');
      
      final existingCategories = await _repository.getAllCategories();
      
      if (existingCategories.isNotEmpty) {
        print('ℹ️ Categories already exist (${existingCategories.length} found)');
        return;
      }

      print('📝 Creating default categories...');
      
      final defaultCategories = [
        DrillCategory(
          id: 'fitness',
          name: 'fitness',
          displayName: 'Fitness',
          order: 0,
        ),
        DrillCategory(
          id: 'soccer',
          name: 'soccer',
          displayName: 'Soccer',
          order: 1,
        ),
        DrillCategory(
          id: 'basketball',
          name: 'basketball',
          displayName: 'Basketball',
          order: 2,
        ),
        DrillCategory(
          id: 'hockey',
          name: 'hockey',
          displayName: 'Hockey',
          order: 3,
        ),
        DrillCategory(
          id: 'tennis',
          name: 'tennis',
          displayName: 'Tennis',
          order: 4,
        ),
        DrillCategory(
          id: 'volleyball',
          name: 'volleyball',
          displayName: 'Volleyball',
          order: 5,
        ),
        DrillCategory(
          id: 'football',
          name: 'football',
          displayName: 'Football',
          order: 6,
        ),
        DrillCategory(
          id: 'lacrosse',
          name: 'lacrosse',
          displayName: 'Lacrosse',
          order: 7,
        ),
        DrillCategory(
          id: 'physiotherapy',
          name: 'physiotherapy',
          displayName: 'Physiotherapy',
          order: 8,
        ),
        DrillCategory(
          id: 'agility',
          name: 'agility',
          displayName: 'Agility',
          order: 9,
        ),
      ];

      for (final category in defaultCategories) {
        await _repository.createCategory(category);
        print('✅ Created category: ${category.displayName}');
      }

      print('✅ Default categories initialized successfully!');
    } catch (e) {
      print('❌ Failed to initialize default categories: $e');
      rethrow;
    }
  }

  /// Check if categories need initialization
  Future<bool> needsInitialization() async {
    try {
      final categories = await _repository.getAllCategories();
      return categories.isEmpty;
    } catch (e) {
      print('Error checking categories: $e');
      return true;
    }
  }
}