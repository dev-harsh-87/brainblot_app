import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:spark_app/core/utils/app_logger.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Play whistle sound effect - signals "now stimuli comes"
  Future<void> playWhistle() async {
    AppLogger.info('Playing local whistle sound to signal "now stimuli comes"', tag: 'AudioService');
    
    try {
      // Set audio player to maximum volume for clear whistle sound
      await _audioPlayer.setVolume(1.0);
      
      // Play the local whistle.mp3 file from assets
      AppLogger.debug('Playing local whistle.mp3 file', tag: 'AudioService');
      
      await _audioPlayer.play(AssetSource('audio/whistle.mp3'));
      
      // Wait for the sound to complete
      // We'll wait for a reasonable duration, then stop to ensure clean state
      await Future.delayed(const Duration(milliseconds: 2000));
      
      // Stop the player to ensure clean state for next use
      await _audioPlayer.stop();
      
      AppLogger.success('Local whistle sound played successfully - stimuli ready to show', tag: 'AudioService');
      
    } catch (e) {
      AppLogger.error('Local whistle sound failed, using system sound fallback', error: e, tag: 'AudioService');
      
      // Fallback: Use system sounds if local file fails
      try {
        AppLogger.debug('Using system sound fallback for whistle', tag: 'AudioService');
        
        // Play a distinctive pattern to signal "now stimuli comes"
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 200));
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 200));
        await SystemSound.play(SystemSoundType.alert);
        
        AppLogger.success('System sound whistle fallback completed', tag: 'AudioService');
        
      } catch (fallbackError) {
        AppLogger.error('Even system sound fallback failed', error: fallbackError, tag: 'AudioService');
        
        // Final fallback - single alert
        try {
          await SystemSound.play(SystemSoundType.alert);
        } catch (finalError) {
          AppLogger.error('All audio methods failed', error: finalError, tag: 'AudioService');
        }
      }
    }
  }

  /// Play countdown tick sound
  Future<void> playCountdownTick() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    } catch (e) {
      // Fallback to haptic feedback only
      await HapticFeedback.lightImpact();
    }
  }

  /// Dispose audio resources
  void dispose() {
    _audioPlayer.dispose();
  }
}