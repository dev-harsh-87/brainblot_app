import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Play whistle sound effect
  Future<void> playWhistle() async {
    try {
      // Use system sound for whistle effect
      await SystemSound.play(SystemSoundType.click);
      
      // Add haptic feedback for better user experience
      await HapticFeedback.heavyImpact();
      
      // Optional: You can add a custom whistle sound file later
      // await _audioPlayer.play(AssetSource('sounds/whistle.mp3'));
    } catch (e) {
      // Fallback to haptic feedback only if audio fails
      await HapticFeedback.heavyImpact();
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