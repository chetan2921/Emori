import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isConfigured = false;
  bool _isSpeaking = false;
  bool _isCancelled = false;

  bool get isSpeaking => _isSpeaking;

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
      _isSpeaking = true;
      _isCancelled = false;
      await _flutterTts.speak(text);
      _isSpeaking = false;
    }
  }

  /// Speak text sentence-by-sentence from a stream of tokens.
  /// Starts TTS as soon as the first sentence is complete,
  /// giving a much more responsive feel for voice conversations.
  Future<String> speakFromStream(Stream<String> tokenStream) async {
    await _configure();
    _isCancelled = false;
    _isSpeaking = true;

    final fullText = StringBuffer();
    final sentenceBuffer = StringBuffer();
    final completer = Completer<void>();

    // Set up completion handler so we can await each sentence
    _flutterTts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });

    // Sentence-ending punctuation
    final sentenceEnd = RegExp(r'[.!?]\s*$');

    await for (final token in tokenStream) {
      if (_isCancelled) break;

      fullText.write(token);
      sentenceBuffer.write(token);

      // Check if we have a complete sentence
      final current = sentenceBuffer.toString().trim();
      if (current.isNotEmpty && sentenceEnd.hasMatch(current)) {
        // Speak this sentence immediately
        final completer0 = Completer<void>();
        _flutterTts.setCompletionHandler(() {
          if (!completer0.isCompleted) completer0.complete();
        });

        await _flutterTts.speak(current);
        await completer0.future; // Wait for this sentence to finish speaking

        sentenceBuffer.clear();

        if (_isCancelled) break;
      }
    }

    // Speak any remaining text that didn't end with punctuation
    final remaining = sentenceBuffer.toString().trim();
    if (remaining.isNotEmpty && !_isCancelled) {
      final completer1 = Completer<void>();
      _flutterTts.setCompletionHandler(() {
        if (!completer1.isCompleted) completer1.complete();
      });
      await _flutterTts.speak(remaining);
      await completer1.future;
    }

    _isSpeaking = false;
    return fullText.toString();
  }

  Future<void> stop() async {
    _isCancelled = true;
    _isSpeaking = false;
    await _flutterTts.stop();
  }
}
