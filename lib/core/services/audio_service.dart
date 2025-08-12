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
  int _currentIndex = 0;
  bool _isRepeatMode = false;
  bool _isAutoPlayNext = true;
  List<WordTimestamp> _currentWordTimestamps = []; // Store current word timestamps
  String? _preferredReciter; // user selected preferred reciter (folder name)
  bool _completionHandled = false; // guard against duplicate completed events causing skips
  final Set<String> _prefetchedUrls = <String>{}; // remember prefetched remote URLs

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
  bool get isAutoPlayNext => _isAutoPlayNext;
  AudioPlayer get player => _audioPlayer; // Expose player for external access if needed

  Future<void> initialize() async {
    try {
      // Initialize audio session
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Listen to player state changes
      _audioPlayer.playerStateStream.listen((playerState) {
        _updateState(playerState);
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

      // Listen to playback completion
      _audioPlayer.processingStateStream.listen((processingState) {
        if (processingState == ProcessingState.completed) {
          if (!_completionHandled) {
            _completionHandled = true;
            _onPlaybackCompleted();
          }
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
      _currentVerse = verse;
      _currentVerseController.add(verse);
      _currentWordTimestamps = wordTimestamps ?? []; // Set word timestamps
      _currentWordIndexController.add(null); // Reset word index
  _completionHandled = false; // new verse => allow completion handler once

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
  // Fire-and-forget prefetch of next verse in playlist for smoother gapless playback
  _prefetchNextInPlaylist();
      
    } catch (e) {
      _log('Error playing verse: $e');
      _setState(AudioState.error);
    }
  }

  Future<void> playPlaylist(List<Verse> verses, {int startIndex = 0}) async {
    if (verses.isEmpty) return;

    _currentPlaylist = verses;
    _currentIndex = startIndex.clamp(0, verses.length - 1);
  _completionHandled = false;
    
    // Note: For playlist, word-by-word highlighting would require passing timestamps for each verse in the playlist.
    // This is a more complex scenario and might need a different approach (e.g., loading timestamps dynamically).
    await playVerse(verses[_currentIndex]);
  }

  void _prefetchNextInPlaylist() {
    if (!_prefetchBeforePlay) return; // respect flag
    if (_currentPlaylist.isEmpty) return;
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _currentPlaylist.length) return;
    final nextVerse = _currentPlaylist[nextIndex];
    // Resolve and prefetch asynchronously
    () async {
      try {
        final url = await _resolveAudioUrlWithFallback(nextVerse);
        if (url == null) return;
        // Already local or downloaded
        String effective = url.startsWith('file://') ? url.substring(7) : url;
        if (_prefetchedUrls.contains(effective)) return;
        // Ensure local file (this will download if needed)
        final local = await _ensureLocalFile(url);
        if (local != null) {
          _prefetchedUrls.add(effective);
        }
      } catch (_) {
        // ignore prefetch errors
      }
    }();
  }

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
      _currentWordIndexController.add(null); // Clear word index on stop
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
    if (_currentPlaylist.isEmpty) return;

    if (_currentIndex < _currentPlaylist.length - 1) {
      _currentIndex++;
  _completionHandled = false;
      await playVerse(_currentPlaylist[_currentIndex]);
    } else if (_isRepeatMode) {
      _currentIndex = 0;
  _completionHandled = false;
      await playVerse(_currentPlaylist[_currentIndex]);
    } else {
      await stop();
    }
  }

  Future<void> playPrevious() async {
    if (_currentPlaylist.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
  _completionHandled = false;
      await playVerse(_currentPlaylist[_currentIndex]);
    } else if (_isRepeatMode) {
      _currentIndex = _currentPlaylist.length - 1;
  _completionHandled = false;
      await playVerse(_currentPlaylist[_currentIndex]);
    }
  }

  void toggleRepeatMode() {
    _isRepeatMode = !_isRepeatMode;
  }

  void toggleAutoPlayNext() {
    _isAutoPlayNext = !_isAutoPlayNext;
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

  void _onPlaybackCompleted() {
    if (_isAutoPlayNext && _currentPlaylist.isNotEmpty) {
      playNext();
    } else {
      stop();
    }
  }

  void _updateCurrentWordIndex(Duration currentPosition) {
    if (_currentWordTimestamps.isEmpty) {
      _currentWordIndexController.add(null);
      return;
    }

    int? foundIndex;
    for (int i = 0; i < _currentWordTimestamps.length; i++) {
      final timestamp = _currentWordTimestamps[i];
      final startMs = timestamp.start;
      final endMs = timestamp.end;

      if (currentPosition.inMilliseconds >= startMs && currentPosition.inMilliseconds < endMs) {
        foundIndex = i;
        break;
      }
    }
    _currentWordIndexController.add(foundIndex);
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

  void dispose() {
    _audioPlayer.dispose();
    _stateController.close();
    _positionController.close();
    _durationController.close();
    _currentVerseController.close();
    _currentWordIndexController.close(); // Close new stream
  }

  void _log(String message) {
    Logger.d(message, tag: 'AudioService');
  }
}
