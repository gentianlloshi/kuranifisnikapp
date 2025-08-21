import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/services/audio_service.dart';
import 'word_by_word_provider.dart';
import '../../domain/entities/verse.dart';
import '../../domain/entities/word_by_word.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int? _remainingSingleVerseLoops; // bounded loop counter when set
  // A-B loop (MEMO-2b) state: defines inclusive verse range within a playlist (or single verses list) to loop.
  Verse? _loopStartVerse;
  Verse? _loopEndVerse;
  bool _abLoopEnabled = false;
  int? _remainingABLoops; // null => infinite until disabled

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
  bool get isSingleVerseLoop => _audioService.isSingleVerseLoop;
  bool get isPlaylistMode => _audioService.currentPlaylistLength > 1;
  bool get isABLoopEnabled => _abLoopEnabled;
  Verse? get loopStartVerse => _loopStartVerse;
  Verse? get loopEndVerse => _loopEndVerse;
  int? get remainingABLoops => _remainingABLoops;
  static bool canSingleVerseLoop(int playlistLength) => playlistLength <= 1;
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
      // Load persisted single verse loop preference (only applies outside playlist)
      try {
        final prefs = await SharedPreferences.getInstance();
        final loopPref = prefs.getBool('audio_single_verse_loop') ?? false;
        if (loopPref) {
          await _audioService.setSingleVerseLoop(true);
        }
      } catch (_) {}
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
      // If single verse finished (stopped state) and bounded loops remain, replay
      if (_audioService.currentState == AudioState.stopped && _audioService.isSingleVerseLoop && _remainingSingleVerseLoops != null) {
        if (_remainingSingleVerseLoops! > 0 && _currentVerse != null) {
          _remainingSingleVerseLoops = _remainingSingleVerseLoops! - 1;
          if (_remainingSingleVerseLoops! >= 0) {
            // Replay without toggling flags (still in loop)
            // ignore: unawaited_futures
            _audioService.playVerse(_currentVerse!);
          }
        }
        if (_remainingSingleVerseLoops != null && _remainingSingleVerseLoops! <= 0) {
          // Auto-disable loop after completion
          // ignore: unawaited_futures
          _audioService.setSingleVerseLoop(false);
          _remainingSingleVerseLoops = null;
        }
      }
      // Handle A-B loop advancement in playlist mode: if enabled and current verse is end, jump back to start.
      if (_abLoopEnabled && _loopStartVerse != null && _loopEndVerse != null && _audioService.currentState == AudioState.stopped) {
        // In playlist mode completion triggers stopped for single verse playback path; for playlist we monitor currentVerseStream
      }
      notifyListeners();
    });

    // Monitor verse changes for A-B looping (playlist only)
    _audioService.currentVerseStream.listen((v) {
      if (!_abLoopEnabled || _loopStartVerse == null || _loopEndVerse == null) return;
      if (!_audioService.isSingleVerseLoop && isPlaylistMode && v != null) {
        final startKey = _loopStartVerse!.verseKey;
        final endKey = _loopEndVerse!.verseKey;
        // If we've just reached end verse and loops remaining, schedule jump to start
        if (v.verseKey == endKey) {
          if (_remainingABLoops != null) {
            if (_remainingABLoops! <= 0) {
              disableABLoop();
              return;
            }
            _remainingABLoops = _remainingABLoops! - 1;
          }
          // Seek to start verse by index if playlist and verses loaded
          // We rely on playlist order matching provided verses sequence.
          _jumpToLoopStart();
        }
      }
    });
  }

  // Public control API expected by widgets
  Future<void> playVerse(Verse verse) async {
    try {
      await _audioService.playVerse(verse);
    } catch (e) { _error = e.toString(); notifyListeners(); }
  }

  // Playback with optional real timestamps; falls back to synthetic spacing if missing.
  Future<void> playVerseWithWordData(Verse verse, WordByWordVerse? wbw, {List<WordTimestamp>? timestamps}) async {
    if (timestamps != null && timestamps.isNotEmpty && wbw != null && wbw.words.isNotEmpty) {
      // Align lengths if they mismatch
      List<WordTimestamp> adjusted = timestamps;
      if (timestamps.length != wbw.words.length) {
        final m = timestamps.length < wbw.words.length ? timestamps.length : wbw.words.length;
        adjusted = timestamps.take(m).toList();
      }
      try { await _audioService.playVerse(verse, wordTimestamps: adjusted); } catch (e) { _error = e.toString(); notifyListeners(); }
      return;
    }
    if (wbw == null || wbw.words.isEmpty) { return playVerse(verse); }
    const perWordMs = 600; // synthetic fallback
    final synthetic = <WordTimestamp>[];
    for (int i = 0; i < wbw.words.length; i++) {
      final start = i * perWordMs;
      final end = (i + 1) * perWordMs;
      synthetic.add(WordTimestamp(start: start, end: end));
    }
    try { await _audioService.playVerse(verse, wordTimestamps: synthetic); } catch (e) { _error = e.toString(); notifyListeners(); }
  }

  Future<void> playSurah(List<Verse> verses, {int startIndex = 0, WordByWordProvider? wbwProvider}) async {
    try {
      Map<int, List<WordTimestamp>>? map;
      if (wbwProvider != null) {
        // Ensure surah data loaded (idempotent)
        final surahId = verses.isNotEmpty ? (verses.first.surahId ?? verses.first.surahNumber) : null;
        if (surahId != null) {
          await wbwProvider.ensureLoaded(surahId);
          map = wbwProvider.allTimestamps;
        }
      }
      await _audioService.playPlaylist(verses, startIndex: startIndex, allTimestamps: map ?? const {});
    } catch (e) { _error = e.toString(); notifyListeners(); }
  }

  // A-B loop controls (playlist verse range). Verses must belong to current playlist context.
  void setABLoop({Verse? start, Verse? end, int? repeatCount}) {
    if (start == null || end == null) {
      disableABLoop();
      return;
    }
    // Ensure ordering; if user picked in reverse, swap.
    if ((start.surahId ?? start.surahNumber) == (end.surahId ?? end.surahNumber) && (start.verseNumber ?? start.number) > (end.verseNumber ?? end.number)) {
      final tmp = start; start = end; end = tmp;
    }
    _loopStartVerse = start;
    _loopEndVerse = end;
    _abLoopEnabled = true;
    _remainingABLoops = repeatCount != null && repeatCount > 0 ? repeatCount : null; // null => infinite
    notifyListeners();
  }

  void disableABLoop() {
    _abLoopEnabled = false;
    _loopStartVerse = null;
    _loopEndVerse = null;
    _remainingABLoops = null;
    notifyListeners();
  }

  Future<void> _jumpToLoopStart() async {
    if (!_abLoopEnabled || _loopStartVerse == null) return;
    // Find index in current playlist
    if (!isPlaylistMode || _audioService.player.sequence == null) return;
    final startKey = _loopStartVerse!.verseKey;
    // We rely on _currentPlaylist stored in AudioService not directly accessible; workaround: trigger stop & replay strategy.
    // Simpler approach: request playVerse which disrupts playlist ordering (acceptable first iteration) – future: expose playlist mapping from service.
    await playVerse(_loopStartVerse!);
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
  Future<void> setSingleVerseLoop(bool enable) async {
    if (isPlaylistMode && enable) return; // guard: do not enable in playlist mode
    await _audioService.setSingleVerseLoop(enable);
    // Persist preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('audio_single_verse_loop', enable);
    } catch (_) {}
    notifyListeners();
  }

  // Configure finite loop count (plays verse N times total). Calls enable loop and sets counter.
  Future<void> setSingleVerseLoopCount(int times) async {
    if (times <= 1) { _remainingSingleVerseLoops = null; await setSingleVerseLoop(false); return; }
    if (isPlaylistMode) return;
    _remainingSingleVerseLoops = times - 1; // remaining after first play
    await setSingleVerseLoop(true);
  }

  // AUDIO-1: Start playback from last read verse using provided callback to fetch resume point.
  Future<void> playFromLastRead(Future<Verse?> Function() resolver) async {
    try {
      final verse = await resolver();
      if (verse != null) {
        await playVerse(verse);
      }
    } catch (e) { _error = e.toString(); notifyListeners(); }
  }

  // AUDIO-1 convenience: given ReadingProgressProvider + QuranProvider, start playback from most recent reading point.
  Future<void> playFromReadingProgress({required Future<Map<String,int>> Function() getLastReadPosition, required int? Function() currentSurahIdProvider, required Future<void> Function(int) ensureSurahLoaded, required Verse? Function(int,int) verseFinder}) async {
    try {
      final pos = await getLastReadPosition(); // map surah->verse
      if (pos.isEmpty) return;
      // Choose most recent surah based on verse update order (map insertion order unknown) – select highest timestamp not available here, fallback to highest surah id.
      // For richer resume use dedicated ReadingProgressProvider externally.
      // Pick max surah key.
      final surah = pos.keys.map(int.parse).fold<int>(1,(a,b)=> b>a?b:a);
      final verseNumber = pos['$surah'] ?? 1;
      if (currentSurahIdProvider() != surah) {
        await ensureSurahLoaded(surah);
      }
      Verse? verse = verseFinder(surah, verseNumber);
      verse ??= Verse(surahId: surah, verseNumber: verseNumber, arabicText: '', translation: null, transliteration: null, verseKey: '$surah:$verseNumber');
      await playVerse(verse);
    } catch (e) { _error = e.toString(); notifyListeners(); }
  }

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
  // Do NOT dispose the singleton AudioService here; it's app-scoped to avoid
  // recreating underlying platform player (which caused dead-thread warnings).
  super.dispose();
  }
}
