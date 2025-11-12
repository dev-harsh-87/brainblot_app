import 'package:spark_app/core/di/injection.dart';
import 'package:spark_app/features/drills/data/drill_repository.dart';

/// Service to handle data migration for drill configuration issues
class DrillMigrationService {
  final DrillRepository _drillRepository = getIt<DrillRepository>();

  /// Check and fix drills with invalid sets values
  Future<void> migrateDrillSets() async {
    print('🔧 Starting drill sets migration...');
    
    try {
      // Get all user drills
      final userDrills = await _drillRepository.fetchMyDrills();
      print('📊 Found ${userDrills.length} user drills to check');
      
      int migratedCount = 0;
      
      for (final drill in userDrills) {
        // Check for invalid sets value (less than 1)
        if (drill.sets < 1) {
          print('⚠️ Found drill "${drill.name}" with invalid sets: ${drill.sets}');
          
          // Create a corrected version with sets = 1 as minimum
          final correctedDrill = drill.copyWith(sets: 1);
          
          // Update the drill in repository
          await _drillRepository.upsert(correctedDrill);
          migratedCount++;
          
          print('✅ Fixed drill "${drill.name}" - sets corrected to 1');
        }
        
        // Check for drills that might have been improperly defaulted
        // This is a heuristic check - if duration suggests multiple sets but sets = 1
        if (drill.sets == 1 && drill.durationSec >= 120 && drill.reps > 1) {
          print('🤔 Found potential multi-set drill "${drill.name}" with sets=1 but duration=${drill.durationSec}s, reps=${drill.reps}');
          // Don't auto-fix this as we can't be sure of user intent
          // Just log for manual review
        }
      }
      
      print('✅ Migration complete! Fixed $migratedCount drills');
      
    } catch (e) {
      print('❌ Error during drill migration: $e');
    }
  }
  
  /// Get drill statistics for debugging
  Future<Map<String, dynamic>> getDrillStatistics() async {
    try {
      final userDrills = await _drillRepository.fetchMyDrills();
      
      final stats = <String, dynamic>{
        'total_drills': userDrills.length,
        'drills_with_sets_1': userDrills.where((d) => d.sets == 1).length,
        'drills_with_sets_2': userDrills.where((d) => d.sets == 2).length,
        'drills_with_sets_3_plus': userDrills.where((d) => d.sets >= 3).length,
        'drills_with_invalid_sets': userDrills.where((d) => d.sets < 1).length,
        'average_duration': userDrills.isNotEmpty 
            ? userDrills.map((d) => d.durationSec).reduce((a, b) => a + b) / userDrills.length 
            : 0,
      };
      
      print('📈 Drill Statistics:');
      stats.forEach((key, value) {
        print('  $key: $value');
      });
      
      return stats;
    } catch (e) {
      print('❌ Error getting drill statistics: $e');
      return {};
    }
  }
}