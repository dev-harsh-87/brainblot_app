import 'package:spark_app/core/auth/services/permission_manager.dart';
import 'package:spark_app/core/utils/app_logger.dart';

/// Debug service to help test and verify permission system functionality
class PermissionDebugService {
  static const String tag = 'PermissionDebugService';

  /// Test permission refresh functionality
  static Future<void> testPermissionRefresh() async {
    try {
      AppLogger.info('Starting permission refresh test...', tag: tag);
      
      // Get initial state
      final initialState = PermissionManager.instance.getDebugInfo();
      AppLogger.info('Initial permission state: $initialState', tag: tag);
      
      // Force refresh
      await PermissionManager.instance.refreshPermissions();
      
      // Get new state
      final newState = PermissionManager.instance.getDebugInfo();
      AppLogger.info('New permission state after refresh: $newState', tag: tag);
      
      AppLogger.success('Permission refresh test completed', tag: tag);
    } catch (e) {
      AppLogger.error('Permission refresh test failed', error: e, tag: tag);
    }
  }

  /// Monitor permission changes for debugging
  static void startPermissionMonitoring() {
    AppLogger.info('Starting permission monitoring...', tag: tag);
    
    PermissionManager.instance.permissionStream.listen((permissions) {
      AppLogger.info('Permission change detected: $permissions', tag: tag);
    });
    
    PermissionManager.instance.addListener(() {
      final state = PermissionManager.instance.getDebugInfo();
      AppLogger.info('PermissionManager state changed: ${state['moduleAccess']}', tag: tag);
    });
  }

  /// Log current permission state
  static void logCurrentPermissions() {
    final manager = PermissionManager.instance;
    final debugInfo = manager.getDebugInfo();
    
    AppLogger.info('=== CURRENT PERMISSION STATE ===', tag: tag);
    AppLogger.info('Initialized: ${debugInfo['initialized']}', tag: tag);
    AppLogger.info('User Role: ${debugInfo['userRole']}', tag: tag);
    AppLogger.info('Module Access: ${debugInfo['moduleAccess']}', tag: tag);
    AppLogger.info('Permission Level: ${debugInfo['permissionLevel']}', tag: tag);
    AppLogger.info('Available Navigation: ${debugInfo['availableNavigation']}', tag: tag);
    AppLogger.info('================================', tag: tag);
  }

  /// Simulate a plan upgrade for testing
  static Future<void> simulatePlanUpgrade() async {
    try {
      AppLogger.info('Simulating plan upgrade...', tag: tag);
      
      // Log before
      AppLogger.info('BEFORE UPGRADE:', tag: tag);
      logCurrentPermissions();
      
      // Force permission refresh (simulates what happens after plan upgrade)
      await PermissionManager.instance.refreshPermissions();
      
      // Wait a moment for changes to propagate
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Log after
      AppLogger.info('AFTER UPGRADE:', tag: tag);
      logCurrentPermissions();
      
      AppLogger.success('Plan upgrade simulation completed', tag: tag);
    } catch (e) {
      AppLogger.error('Plan upgrade simulation failed', error: e, tag: tag);
    }
  }
}