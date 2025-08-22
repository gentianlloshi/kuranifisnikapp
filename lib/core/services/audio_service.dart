import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:kurani_fisnik_app/core/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/verse.dart';
import '../../domain/entities/word_by_word.dart'; // Import WordByWord entities
import '../metrics/perf_metrics.dart';

enum AudioState {
  stopped,
  loading,
  playing,
  paused,
  error,
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final StreamController<AudioState> _stateController = StreamController<AudioState>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController = StreamController<Duration?>.broadcast();
  final StreamController<Verse?> _currentVerseController = StreamController<Verse?>.broadcast();
  final StreamController<int?> _currentWordIndexController = StreamController<int?>.broadcast(); // New stream for word index

  AudioState _currentState = AudioState.stopped;
  Verse? _currentVerse;
  List<Verse> _currentPlaylist = [];
  int _currentIndex = 0; // mirrors player.currentIndex; kept for legacy callers
  bool _isRepeatMode = false;
  bool _singleVerseLoop = false; // single verse loop (non-playlist)
  bool _isAutoPlayNext = true; // with ConcatenatingAudioSource this is always true unless disabled
  List<WordTimestamp> _currentWordTimestamps = []; // Store current word timestamps
  Map<int, List<WordTimestamp>> _allSurahTimestamps = {}; // verseNumber -> timestamps for playlist mode
  String? _preferredReciter; // user selected preferred reciter (folder name)
  bool _isAdvancing = false; // legacy guard (no longer needed with currentIndexStream) – will be removed after validation
  final Set<String> _prefetchedUrls = <String>{}; // remember prefetched remote URLs
  ConcatenatingAudioSource? _playlistSource; // active playlist audio source

  // Word sync optimization state
  int _wordPtr = 0; // current pointer into _currentWordTimestamps (monotonic advance during playback)
  int _lastEmittedWord = -1; // last emitted word index (to suppress duplicate stream events)
  int _lastLoggedVerse = -1; // to suppress duplicate advance playlist logs
  int _lastWordUpdateMs = 0; // throttle position processing
  static const int _wordThrottleMs = 55; // ~18 fps sampling for highlight (tune 40-70ms)

  // Tunables
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(milliseconds: 350);
  static const Duration _setUrlTimeout = Duration(seconds: 8);
  final bool _prefetchBeforePlay = true; // pre-download full verse file before playing to avoid mid-stream aborts

  // Getters
  Stream<AudioState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<Verse?> get currentVerseStream => _currentVerseController.stream;
  Stream<int?> get currentWordIndexStream => _currentWordIndexController.stream; // Getter for new stream
  
  AudioState get currentState => _currentState;
  Verse? get currentVerse => _currentVerse;
  bool get isRepeatMode => _isRepeatMode;
  bool get isSingleVerseLoop => _singleVerseLoop;
  bool get isAutoPlayNext => _isAutoPlayNext;
  AudioPlayer get player => _audioPlayer; // Expose player for external access if needed
  int get currentPlaylistLength => _currentPlaylist.length; // 0 or >0 if playlist mode

  Future<void> initialize() async {
    try {
      if (_disposed) {
        _disposed = false; // revive if previously soft-disposed
      }
      if (_currentState != AudioState.stopped || _audioPlayer.playerState.playing || _audioPlayer.playerState.processingState != ProcessingState.idle) {
        // Already initialized (or in use); idempotent return.
        _log('initialize() called while already active - idempotent no-op');
        return;
      }
      // Initialize audio session
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Listen to player state changes
      _audioPlayer.playerStateStream.listen(_updateState);

      // Track current index changes from just_audio (single source of truth)
      _audioPlayer.currentIndexStream.listen((idx) {
        if (idx == null || idx < 0) return;
        if (idx >= 0 && idx < _currentPlaylist.length) {
          _currentIndex = idx;
          final verse = _currentPlaylist[idx];
          _currentVerse = verse;
          _currentVerseController.add(verse);
          // Update word timestamps when advancing in playlist
          if (_allSurahTimestamps.isNotEmpty) {
            _currentWordTimestamps = _allSurahTimestamps[verse.verseNumber] ?? [];
            _wordPtr = 0;
            _lastEmittedWord = -1;
            _currentWordIndexController.add(null);
            if (_currentWordTimestamps.isNotEmpty) {
              _currentWordIndexController.add(0); // pre-emit first
              _lastEmittedWord = 0;
            }
            // Debug playlist advancement
            if (verse.verseNumber != _lastLoggedVerse) {
              // ignore: avoid_print
              print('[AudioService] advance playlist verse=${verse.verseKey} verseNumber=${verse.verseNumber} ts=${_currentWordTimestamps.length} availableKeys=${_allSurahTimestamps.keys.take(8).toList()}');
              _lastLoggedVerse = verse.verseNumber;
            }
            if (_currentWordTimestamps.isEmpty) {
              // ignore: avoid_print
              print('[AudioService][WARN] No timestamps for verseNumber=${verse.verseNumber}');
            }
          }
        }
      });

      // Listen to position changes
      _audioPlayer.positionStream.listen((position) {
        _positionController.add(position);
        _updateCurrentWordIndex(position); // Update word index on position change
      });

      // Listen to duration changes
      _audioPlayer.durationStream.listen((duration) {
        _durationController.add(duration);
      });

      // Rely on just_audio's internal advancement. For single verse playback we'll still observe completion -> stopped state.
      _audioPlayer.processingStateStream.listen((processingState) {
        if (processingState == ProcessingState.completed && _playlistSource == null) {
          // Single verse ended
          stop();
        }
      });

    } catch (e) {
      _log('Error initializing audio service: $e');
      _setState(AudioState.error);
    }
  }

  Future<void> playVerse(Verse verse, {List<WordTimestamp>? wordTimestamps}) async {
    try {
      _setState(AudioState.loading);
  _singleVerseLoop = false; // reset per new verse
      _currentVerse = verse;
      _currentVerseController.add(verse);
      _currentWordTimestamps = wordTimestamps ?? [];
      _currentWordIndexController.add(null);
      if (_currentWordTimestamps.isNotEmpty) {
        // Pre-emit first word index so UI highlights instantly
        _currentWordIndexController.add(0);
      }
  // DO NOT reset _isAdvancing here; wait until verse actually starts playing to avoid race with completion events.

      final audioUrl = await _resolveAudioUrlWithFallback(verse);
      if (audioUrl == null) {
        throw Exception('Asnjë URL audio nuk u gjet (404) për ajetin ${verse.verseKey}');
      }
      // Strategy: ensure local cached file (prefetch) for stability, then use setFilePath
      String? playPath;
      if (_prefetchBeforePlay) {
        playPath = await _ensureLocalFile(audioUrl);
      }
      // Fallback to streaming if prefetch disabled or failed
      final isLocal = playPath != null;
  if (isLocal) { PerfMetrics.instance.incAudioCacheHit(); }

      bool success = false;
      for (int attempt = 0; attempt < _maxRetries && !success; attempt++) {
        try {
          if (isLocal) {
            await _audioPlayer.setFilePath(playPath, preload: true).timeout(_setUrlTimeout);
          } else {
            await _audioPlayer.setUrl(audioUrl).timeout(_setUrlTimeout);
          }
          await _audioPlayer.play();
          success = true;
        } catch (e) {
          if (attempt == _maxRetries - 1) rethrow;
          final backoff = _initialRetryDelay * pow(2, attempt).toInt();
          await Future.delayed(backoff);
        }
      }
  // Now that playback has successfully started, allow completion handler again.
  _isAdvancing = false;
      // No manual prefetch when single verse – playlist prefetch handled separately.
      
    } catch (e) {
      _log('Error playing verse: $e');
      _setState(AudioState.error);
    }
  }

  Future<void> playPlaylist(List<Verse> verses, {required Map<int, List<WordTimestamp>> allTimestamps, int startIndex = 0}) async {
    if (verses.isEmpty) return;
    _setState(AudioState.loading);
    _currentPlaylist = verses;
    _currentIndex = startIndex.clamp(0, verses.length - 1);
    _allSurahTimestamps = allTimestamps;
    _playlistSource?.clear();
    // Build sources (prefer local cached files if present / prefetch flag)
    final children = <AudioSource>[];
    for (final v in verses) {
      final url = await _resolveAudioUrlWithFallback(v);
      if (url == null) continue; // skip missing
      String? path;
      if (_prefetchBeforePlay) {
        path = await _ensureLocalFile(url);
      }
      final effective = path != null ? Uri.file(path) : Uri.parse(url);
  if (path != null) { PerfMetrics.instance.incAudioCacheHit(); }
      children.add(AudioSource.uri(effective));
    }
    final source = ConcatenatingAudioSource(children: children);
    _playlistSource = source;
    await _audioPlayer.setAudioSource(source, initialIndex: _currentIndex);
    // Pre-initialize current verse + timestamps before playback starts so UI can highlight immediately
    if (_currentPlaylist.isNotEmpty) {
      final initialVerse = _currentPlaylist[_currentIndex];
      _currentVerse = initialVerse;
      _currentVerseController.add(initialVerse);
      if (_allSurahTimestamps.isNotEmpty) {
        _currentWordTimestamps = _allSurahTimestamps[initialVerse.verseNumber] ?? [];
        _currentWordIndexController.add(null);
        if (_currentWordTimestamps.isNotEmpty) {
          _currentWordIndexController.add(0);
        }
        // Debug log
        // ignore: avoid_print
        print('[AudioService] init playlist verse=${initialVerse.verseNumber} ts=${_currentWordTimestamps.length}');
        if (_currentWordTimestamps.isEmpty) {
          // ignore: avoid_print
          print('[AudioService][WARN] Initial verse has no timestamps. Keys loaded: ${_allSurahTimestamps.keys.length}');
        }
      }
    }
    await _audioPlayer.play();
    _isAdvancing = false;
  }

  // Seek to a verse inside the current playlist by matching verse identity.
  // Returns true if the verse was found and seek performed. If [autoPlay] is true, resumes playback after seek.
  Future<bool> seekToVerseInPlaylist(Verse target, {bool autoPlay = true}) async {
    if (_playlistSource == null || _currentPlaylist.isEmpty) return false;
    // Prefer matching by verseKey when present; fallback to surahId+verseNumber
    final String? key = target.verseKey;
    final int surah = target.surahId ?? target.surahNumber;
    final int ayah = target.verseNumber ?? target.number;
    int found = -1;
    for (int i = 0; i < _currentPlaylist.length; i++) {
      final v = _currentPlaylist[i];
      if (key != null && key.isNotEmpty) {
        if (v.verseKey == key) { found = i; break; }
      } else {
        final s = v.surahId ?? v.surahNumber;
        final a = v.verseNumber ?? v.number;
        if (s == surah && a == ayah) { found = i; break; }
      }
    }
    if (found < 0) return false;
    try {
      await _audioPlayer.seek(Duration.zero, index: found);
      if (autoPlay) {
        await _audioPlayer.play();
      }
      return true;
    } catch (e) {
      _log('seekToVerseInPlaylist failed: $e');
      return false;
    }
  }

  void _prefetchNextInPlaylist() {/* obsolete with ConcatenatingAudioSource - retained for compatibility */}

  Future<void> play() async {
    try {
      await _audioPlayer.play();
    } catch (e) {
      _log('Error playing audio: $e');
      _setState(AudioState.error);
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      _log('Error pausing audio: $e');
      _setState(AudioState.error);
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _currentVerse = null;
      _currentVerseController.add(null);
      _currentWordTimestamps = []; // Clear timestamps on stop
  _allSurahTimestamps = {};
      _currentWordIndexController.add(null); // Clear word index on stop
  _singleVerseLoop = false;
      _setState(AudioState.stopped);
    } catch (e) {
      _log('Error stopping audio: $e');
      _setState(AudioState.error);
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      _log('Error seeking audio: $e');
    }
  }

  Future<void> playNext() async {
    if (_playlistSource != null) {
      try { await _audioPlayer.seekToNext(); } catch (_) {}
    }
  }

  Future<void> playPrevious() async {
    if (_playlistSource != null) {
      try { await _audioPlayer.seekToPrevious(); } catch (_) {}
    }
  }

  void toggleRepeatMode() {
    _isRepeatMode = !_isRepeatMode;
    _audioPlayer.setLoopMode(_isRepeatMode ? LoopMode.all : LoopMode.off);
  }

  Future<void> setSingleVerseLoop(bool enable) async {
    _singleVerseLoop = enable;
    if (_playlistSource != null) return; // only for single verse mode
    await _audioPlayer.setLoopMode(enable ? LoopMode.one : LoopMode.off);
  }

  void toggleAutoPlayNext() {
    // With ConcatenatingAudioSource auto-advance is inherent; method retained for API compatibility.
    _isAutoPlayNext = !_isAutoPlayNext;
    _audioPlayer.setLoopMode(_isAutoPlayNext ? (_isRepeatMode ? LoopMode.all : LoopMode.off) : LoopMode.off);
  }

  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed.clamp(0.5, 2.0));
  }

  void _updateState(PlayerState playerState) {
    switch (playerState.processingState) {
      case ProcessingState.idle:
        _setState(AudioState.stopped);
        break;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        _setState(AudioState.loading);
        break;
      case ProcessingState.ready:
        if (playerState.playing) {
          _setState(AudioState.playing);
        } else {
          _setState(AudioState.paused);
        }
        break;
      case ProcessingState.completed:
        _setState(AudioState.stopped);
        break;
    }
  }

  void _setState(AudioState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void _onPlaybackCompleted() {/* obsolete with playlist-driven advancement */}

  void _updateCurrentWordIndex(Duration currentPosition) {
    if (_currentWordTimestamps.isEmpty) {
      _currentWordIndexController.add(null);
      return;
    }
    final int posMs = currentPosition.inMilliseconds;
    // Throttle: only process if enough time passed OR we might have crossed boundary to next word
    if (posMs - _lastWordUpdateMs < _wordThrottleMs) {
      // Early exit unless we obviously surpassed next boundary
      if (_wordPtr + 1 < _currentWordTimestamps.length && posMs < _currentWordTimestamps[_wordPtr + 1].start) {
        return; // still inside current word
      }
    }
    _lastWordUpdateMs = posMs;

    // Fast path: advance pointer forward while position >= start of next word
    while (_wordPtr + 1 < _currentWordTimestamps.length && posMs >= _currentWordTimestamps[_wordPtr + 1].start) {
      _wordPtr++;
    }
    // Handle seek backwards (position before current word start)
    if (posMs < _currentWordTimestamps[_wordPtr].start) {
      // Binary search to find correct index
      int low = 0;
      int high = _wordPtr;
      while (low < high) {
        final mid = (low + high) >> 1;
        if (_currentWordTimestamps[mid].start <= posMs) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      // Adjust pointer to previous that actually starts before posMs
      if (low > 0 && _currentWordTimestamps[low].start > posMs) {
        _wordPtr = low - 1;
      } else {
        _wordPtr = low.clamp(0, _currentWordTimestamps.length - 1);
      }
    }

    // Validate we are inside word range; if after end of last word keep pointer at last
    if (_wordPtr >= _currentWordTimestamps.length) {
      _wordPtr = _currentWordTimestamps.length - 1;
    }
    final currentTs = _currentWordTimestamps[_wordPtr];
    if (posMs < currentTs.start) {
      // Rare guard (due to binary search rounding) - shift back until correct
      while (_wordPtr > 0 && posMs < _currentWordTimestamps[_wordPtr].start) {
        _wordPtr--;
      }
    } else if (posMs >= currentTs.end) {
      while (_wordPtr + 1 < _currentWordTimestamps.length && posMs >= _currentWordTimestamps[_wordPtr].end) {
        _wordPtr++;
      }
    }

    if (_wordPtr != _lastEmittedWord) {
      _lastEmittedWord = _wordPtr;
      _currentWordIndexController.add(_wordPtr);
    }
  }

  Future<String?> _resolveAudioUrlWithFallback(Verse verse) async {
    final surah = verse.surahId.toString().padLeft(3, '0');
    final ayah = verse.verseNumber.toString().padLeft(3, '0');
    final code = '$surah$ayah';

    // Kandidatë recituesish (preferencat e përdoruesit në krye nëse ekziston)
    final List<String> baseReciters = [
      'Alafasy_128kbps', // i besueshëm
      'Abdul_Basit_Mujawwad',
      'AbdulSamad_64kbps',
    ];

    List<String> reciters;
    if (_preferredReciter != null && _preferredReciter != 'default' && baseReciters.contains(_preferredReciter)) {
      reciters = [
        _preferredReciter!,
        ...baseReciters.where((r) => r != _preferredReciter),
      ];
    } else {
      reciters = baseReciters;
    }

    final candidates = [
      for (final r in reciters) 'https://everyayah.com/data/$r/$code.mp3',
    ];

    for (final url in candidates) {
      try {
        if (await isAudioDownloaded(url)) {
          final path = await getLocalFilePath(url);
          return 'file://$path';
        }
        final resp = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) return url;
      } catch (_) {
        // vazhdo me tjetrin
      }
    }
    return null;
  }

  // Ensure local copy exists; returns local file path or null if failed
  Future<String?> _ensureLocalFile(String audioUrl) async {
    try {
      // If already local file URL
      if (audioUrl.startsWith('file://')) {
        return audioUrl.substring(7);
      }
      // Download (with retries) into local cache
      final localPath = await getLocalFilePath(audioUrl);
      final file = File(localPath);
      if (await file.exists()) return localPath;

      for (int attempt = 0; attempt < _maxRetries; attempt++) {
        try {
          final resp = await http.get(Uri.parse(audioUrl)).timeout(const Duration(seconds: 12));
          if (resp.statusCode == 200) {
            await file.parent.create(recursive: true);
            await file.writeAsBytes(resp.bodyBytes, flush: true);
            return localPath;
          }
        } catch (e) {
          if (attempt == _maxRetries - 1) {
            // swallow and return null to allow streaming fallback
            break;
          }
          final delay = _initialRetryDelay * pow(2, attempt + 1).toInt();
          await Future.delayed(delay);
        }
      }
    } catch (_) {
      // ignore, will fallback
    }
    return null; // fallback to remote streaming
  }

  // External integration to set preferred reciter at runtime
  void setPreferredReciter(String? reciter) {
    _preferredReciter = reciter;
  }

  // Download management methods
  Future<String> getLocalFilePath(String url) async {
    final directory = await getApplicationDocumentsDirectory();
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final fileName = segments.isNotEmpty ? segments.last : 'audio.mp3';
      final reciterFolder = segments.length >= 2 ? segments[segments.length - 2] : 'default';
      return '${directory.path}/audio/$reciterFolder/$fileName';
    } catch (_) {
      final fileNameFallback = url.split('/').last;
      return '${directory.path}/audio/$fileNameFallback';
    }
  }

  Future<bool> isAudioDownloaded(String url) async {
    final filePath = await getLocalFilePath(url);
    return File(filePath).exists();
  }

  Future<void> downloadAudio(String url, Function(double) onProgress) async {
    final filePath = await getLocalFilePath(url);
    final file = File(filePath);

    // Create directory if it doesn't exist
    await file.parent.create(recursive: true);

    if (await file.exists()) {
      _log('Audio already downloaded: $filePath');
      return;
    }

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Failed to download audio: ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      List<int> bytes = [];
      int downloadedBytes = 0;

      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;
        if (contentLength != null) {
          onProgress(downloadedBytes / contentLength);
        }
      }

      await file.writeAsBytes(bytes);
      _log('Audio downloaded to: $filePath');
    } catch (e) {
      _log('Error downloading audio: $e');
      throw e;
    }
  }

  Future<void> deleteAudio(String url) async {
    final filePath = await getLocalFilePath(url);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      _log('Audio deleted: $filePath');
    }
  }

  Future<void> downloadSurahAudio(int surahId, List<Verse> verses, Function(double) onProgress) async {
    int totalVerses = verses.length;
    int downloadedVerses = 0;

    for (final verse in verses) {
      final audioUrl = await _resolveAudioUrlWithFallback(verse);
      if (audioUrl != null) {
        final effectiveUrl = audioUrl.startsWith('file://') ? audioUrl.substring(7) : audioUrl;
        if (!await isAudioDownloaded(effectiveUrl)) {
          await downloadAudio(effectiveUrl, (progress) {
            final totalProgress = (downloadedVerses + progress) / totalVerses;
            onProgress(totalProgress);
          });
        }
      }
      downloadedVerses++;
      onProgress(downloadedVerses / totalVerses);
    }
  }

  Future<double> getDownloadedSizeForSurah(int surahId, List<Verse> verses) async {
    double totalSize = 0;
    for (final verse in verses) {
      final audioUrl = await _resolveAudioUrlWithFallback(verse);
      if (audioUrl != null) {
        final effectiveUrl = audioUrl.startsWith('file://') ? audioUrl.substring(7) : audioUrl;
        if (await isAudioDownloaded(effectiveUrl)) {
          final filePath = await getLocalFilePath(effectiveUrl);
          final file = File(filePath);
          if (await file.exists()) {
            totalSize += await file.length();
          }
        }
      }
    }
    return totalSize;
  }

  bool _disposed = false;

  void dispose() {
    // Intentionally left as soft-dispose; singleton retained for app lifetime.
    if (_disposed) return;
    try {
      _audioPlayer.stop();
    } catch (_) {}
    _disposed = true;
  }

  void _log(String message) {
    Logger.d(message, tag: 'AudioService');
  }
}
