import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/services/audio_service.dart';
import '../../domain/entities/verse.dart';

class AudioProvider extends ChangeNotifier {
  final AudioService _audioService = AudioService();
  late final AudioPlayer _player;

  bool _initialized = false;
  bool _isPlayerExpanded = false;
  bool _isRepeatMode = false;
  String? _error;

  // Cached state
  Duration _currentPosition = Duration.zero;
  Duration? _currentDuration;
  Verse? _currentVerse;
  int? _currentWordIndex;

  bool get isPlaying => _audioService.currentState == AudioState.playing;
  bool get isLoading => _audioService.currentState == AudioState.loading;
  Duration get currentPosition => _currentPosition;
  Duration? get currentDuration => _currentDuration;
  double get volume => _player.volume;
  double get playbackSpeed => _player.speed;
  Verse? get currentVerse => _currentVerse;
  int? get currentWordIndex => _currentWordIndex;
  bool get isRepeatMode => _isRepeatMode;
  bool get isPlayerExpanded => _isPlayerExpanded;
  String? get error => _error;
  // Backwards compatibility names used in widgets
  dynamic get currentTrack => _currentVerse; // alias

  AudioProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _audioService.initialize();
      _player = _audioService.player;
      _listenStreams();
      _initialized = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _listenStreams() {
    _audioService.positionStream.listen((pos) {
      _currentPosition = pos;
      notifyListeners();
    });
    _audioService.durationStream.listen((dur) {
      _currentDuration = dur;
      notifyListeners();
    });
    _audioService.currentVerseStream.listen((verse) {
      _currentVerse = verse;
      notifyListeners();
    });
    _audioService.currentWordIndexStream.listen((index) {
      _currentWordIndex = index;
      notifyListeners();
    });
    _audioService.stateStream.listen((_) {
      notifyListeners();
    });
  }

  // Public control API expected by widgets
  Future<void> playVerse(Verse verse) async {
    try {
      await _audioService.playVerse(verse);
    } catch (e) { _error = e.toString(); notifyListeners(); }
  }

  Future<void> playSurah(List<Verse> verses, {int startIndex = 0}) async {
    try { await _audioService.playPlaylist(verses, startIndex: startIndex); } catch (e) { _error = e.toString(); notifyListeners(); }
  }

  Future<void> togglePlayPause() async {
    if (!_initialized) return;
    try {
      if (isPlaying) {
        await _audioService.pause();
      } else {
        await _audioService.play();
      }
    } catch (e) { _error = e.toString(); notifyListeners(); }
  }

  Future<void> stop() async { try { await _audioService.stop(); } catch (e) { _error = e.toString(); notifyListeners(); } }
  Future<void> playNext() async { try { await _audioService.playNext(); } catch (e) { _error = e.toString(); notifyListeners(); } }
  Future<void> playPrevious() async { try { await _audioService.playPrevious(); } catch (e) { _error = e.toString(); notifyListeners(); } }
  void toggleRepeatMode() { _audioService.toggleRepeatMode(); _isRepeatMode = !_isRepeatMode; notifyListeners(); }

  Future<void> seekTo(Duration position) async { try { await _audioService.seekTo(position); } catch (e) { _error = e.toString(); notifyListeners(); } }
  Future<void> setVolume(double volume) async { try { await _audioService.setVolume(volume); notifyListeners(); } catch (e) { _error = e.toString(); notifyListeners(); } }
  Future<void> setPlaybackSpeed(double speed) async { try { await _audioService.setSpeed(speed); notifyListeners(); } catch (e) { _error = e.toString(); notifyListeners(); } }

  double get progress {
    if (_currentDuration == null || _currentDuration!.inMilliseconds == 0) return 0.0;
    return _currentPosition.inMilliseconds / _currentDuration!.inMilliseconds;
  }

  Future<void> seekToProgress(double value) async {
    if (_currentDuration == null) return;
    final target = _currentDuration! * value;
    await seekTo(target);
  }

  // Download support using underlying service URL logic
  // Download helpers could be reintroduced when exposing manual caching UI
  Future<bool> isVerseAudioDownloaded(Verse verse) async {
    // Use service resolution to get final URL, then check local existence via resolve path logic
    // Simpler: attempt resolve (may cost a HEAD) – acceptable for on-demand button
    try {
      // Reuse play resolution indirectly by constructing code
      final surah = (verse.surahId ?? verse.surahNumber).toString().padLeft(3,'0');
      final ayah = (verse.verseNumber ?? verse.number).toString().padLeft(3,'0');
      final code = '$surah$ayah';
      // Check known reciter folders
      const reciters = ['Alafasy_128kbps','Abdul_Basit_Mujawwad','AbdulSamad_64kbps'];
      for (final r in reciters) {
        final url = 'https://everyayah.com/data/$r/$code.mp3';
        if (await _audioService.isAudioDownloaded(url)) return true;
      }
      return false;
    } catch (_) { return false; }
  }

  Future<void> downloadVerseAudio(Verse verse, Function(double) onProgress) async {
    final surah = (verse.surahId ?? verse.surahNumber).toString().padLeft(3,'0');
    final ayah = (verse.verseNumber ?? verse.number).toString().padLeft(3,'0');
    final code = '$surah$ayah';
    // Prefer first reciter; fallback list could be added
    final url = 'https://everyayah.com/data/Alafasy_128kbps/$code.mp3';
    await _audioService.downloadAudio(url, onProgress);
  }

  Future<void> deleteVerseAudio(Verse verse) async {
    final surah = (verse.surahId ?? verse.surahNumber).toString().padLeft(3,'0');
    final ayah = (verse.verseNumber ?? verse.number).toString().padLeft(3,'0');
    final code = '$surah$ayah';
    const reciters = ['Alafasy_128kbps','Abdul_Basit_Mujawwad','AbdulSamad_64kbps'];
    for (final r in reciters) {
      final url = 'https://everyayah.com/data/$r/$code.mp3';
      await _audioService.deleteAudio(url); // ignore errors
    }
  }

  String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2,'0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2,'0');
    return '$m:$s';
  }

  set isPlayerExpanded(bool v) { _isPlayerExpanded = v; notifyListeners(); }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
