import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/vocabulary.dart';

enum AudioKind { term, example, card }

enum PlaybackResult { completed, failed, cancelled }

abstract class SpeechBackend {
  Future<bool> playAsset(String asset, {required double rate});
  Future<bool> speak(
    String text, {
    required String language,
    required double rate,
  });
  Future<void> stop();
  Future<void> dispose();
}

class _Segment {
  const _Segment(this.text, this.language, {this.asset});
  final String text, language;
  final String? asset;
}

class _Playback {
  _Playback(this.backend);
  final SpeechBackend backend;
  final done = Completer<PlaybackResult>();
  void complete(PlaybackResult result) {
    if (!done.isCompleted) done.complete(result);
  }
}

/// One owner across screens. Stop/dispose from an older popup cannot cancel a
/// newer recording, and cancelled completion callbacks never advance a lesson.
class SpeechService {
  SpeechService({SpeechBackend Function()? backendFactory})
    : _factory = backendFactory ?? FlutterSpeechBackend.new;
  final SpeechBackend Function() _factory;
  static _Playback? _active;
  static Future<void> _transition = Future.value();
  _Playback? _owned;

  Future<PlaybackResult> playWord(
    Word word, {
    AudioKind kind = AudioKind.term,
    double rate = .45,
  }) {
    final segments = switch (kind) {
      AudioKind.term => [_Segment(word.term, 'de-DE')],
      AudioKind.example => [_Segment(word.example, 'de-DE')],
      AudioKind.card => [
        _Segment(word.term, 'de-DE', asset: word.audioAssets['term']),
        _Segment(word.translation, 'en-US'),
        _Segment(word.example, 'de-DE', asset: word.audioAssets['example']),
      ],
    };
    return _start(word.audioAssets[kind.name], segments, rate);
  }

  Future<bool> speak(String text, {double rate = .45}) async =>
      await _start(null, [_Segment(text, 'de-DE')], rate) ==
      PlaybackResult.completed;

  Future<PlaybackResult> _start(
    String? asset,
    List<_Segment> segments,
    double rate,
  ) {
    final previous = _active;
    previous?.complete(PlaybackResult.cancelled);
    final request = _Playback(_factory());
    _owned = request;
    _active = request;
    _transition = _transition
        .then((_) async {
          if (previous != null) await previous.backend.stop();
          if (_active != request) {
            await request.backend.dispose();
            return;
          }
          unawaited(_run(request, asset, segments, rate));
        })
        .catchError((Object error) {
          _finish(request, PlaybackResult.failed);
        });
    return request.done.future;
  }

  Future<void> _run(
    _Playback request,
    String? asset,
    List<_Segment> segments,
    double rate,
  ) async {
    try {
      if (asset != null) {
        final played = await request.backend.playAsset(asset, rate: rate);
        if (_active != request) return;
        if (played) {
          _finish(request, PlaybackResult.completed);
          return;
        }
      }
      for (final segment in segments) {
        if (_active != request) return;
        var played = false;
        if (segment.asset != null) {
          played = await request.backend.playAsset(segment.asset!, rate: rate);
        }
        if (_active != request) return;
        if (!played) {
          played = await request.backend.speak(
            segment.text,
            language: segment.language,
            rate: rate,
          );
        }
        if (_active != request) return;
        if (!played) {
          _finish(request, PlaybackResult.failed);
          return;
        }
      }
      _finish(request, PlaybackResult.completed);
    } catch (_) {
      _finish(
        request,
        _active == request ? PlaybackResult.failed : PlaybackResult.cancelled,
      );
    } finally {
      await request.backend.dispose();
    }
  }

  void _finish(_Playback request, PlaybackResult result) {
    if (_active == request) _active = null;
    request.complete(result);
  }

  Future<void> stop() async {
    final request = _owned;
    if (request == null || _active != request) return;
    _active = null;
    request.complete(PlaybackResult.cancelled);
    _transition = _transition
        .then((_) => request.backend.stop())
        .catchError((Object _) {});
    await _transition;
  }
}

class FlutterSpeechBackend implements SpeechBackend {
  // FlutterTts uses one platform callback channel; share its Dart handler too.
  static final _tts = FlutterTts();
  AudioPlayer? _player;
  StreamSubscription<void>? _completeSubscription;
  StreamSubscription<AudioEvent>? _errorSubscription;
  Completer<bool>? _audioDone;
  bool _disposed = false;

  void _completeAudio(bool success) {
    final pending = _audioDone;
    if (pending != null && !pending.isCompleted) pending.complete(success);
  }

  @override
  Future<bool> playAsset(String asset, {required double rate}) async {
    try {
      await _disposePlayer();
      if (_disposed) return false;
      final player = AudioPlayer();
      _player = player;
      _audioDone = Completer<bool>();
      _completeSubscription = player.onPlayerComplete.listen(
        (_) => _completeAudio(true),
      );
      _errorSubscription = player.eventStream.listen(
        (_) {},
        onError: (Object _) => _completeAudio(false),
      );
      await player.play(
        AssetSource(
          asset.replaceFirst(RegExp(r'^assets/'), ''),
          mimeType: 'audio/mpeg',
        ),
      );
      if (_disposed) return false;
      final speed = (rate / .45).clamp(.55, 1.45);
      if ((speed - 1).abs() > .01) {
        try {
          await player.setPlaybackRate(speed);
        } catch (_) {
          /* Keep valid audio at its natural speed. */
        }
      }
      final result = await _audioDone!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => false,
      );
      await _disposePlayer();
      return result;
    } catch (_) {
      await _disposePlayer();
      return false;
    }
  }

  @override
  Future<bool> speak(
    String text, {
    required String language,
    required double rate,
  }) async {
    try {
      if (_disposed) return false;
      final available = await _tts.isLanguageAvailable(language);
      if (_disposed || available == false || available == 0) return false;
      await _tts.awaitSpeakCompletion(true);
      if (_disposed) return false;
      await _tts.setLanguage(language);
      if (_disposed) return false;
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(1);
      if (_disposed) return false;
      final result = await _tts.speak(text);
      return !_disposed && result != 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    _completeAudio(false);
    try {
      await _player?.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> _disposePlayer() async {
    await _completeSubscription?.cancel();
    _completeSubscription = null;
    await _errorSubscription?.cancel();
    _errorSubscription = null;
    final player = _player;
    _player = null;
    if (player != null) {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _completeAudio(false);
    await _disposePlayer();
  }
}
