import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isConfigured = false;

  Future<void> _configure() async {
    if (_isConfigured) return;

    // Set properties for a warm, natural female voice
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // Slightly slower for warmth
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.1); // Slightly higher pitch for a female voice

    // Attempt to set a high-quality voice if available
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }

    _isConfigured = true;
  }

  Future<void> speak(String text) async {
    await _configure();
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
