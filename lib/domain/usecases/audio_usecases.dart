import '../../core/services/audio_service.dart';
import '../entities/verse.dart';
import '../entities/word_by_word.dart';

class PlayVerseUseCase {
  final AudioService _audioService;

  PlayVerseUseCase(this._audioService);

  Future<void> call(Verse verse) async {
    await _audioService.playVerse(verse);
  }
}

class PlaySurahUseCase {
  final AudioService _audioService;

  PlaySurahUseCase(this._audioService);

  Future<void> call(List<Verse> verses, {int startIndex = 0, Map<int, List<WordTimestamp>>? allTimestamps}) async {
    await _audioService.playPlaylist(verses, startIndex: startIndex, allTimestamps: allTimestamps ?? const {});
  }
}

class PlayAudioUseCase {
  final AudioService _audioService;

  PlayAudioUseCase(this._audioService);

  Future<void> call() async {
    await _audioService.play();
  }
}

class PauseAudioUseCase {
  final AudioService _audioService;

  PauseAudioUseCase(this._audioService);

  Future<void> call() async {
    await _audioService.pause();
  }
}

class StopAudioUseCase {
  final AudioService _audioService;

  StopAudioUseCase(this._audioService);

  Future<void> call() async {
    await _audioService.stop();
  }
}

class SeekAudioUseCase {
  final AudioService _audioService;

  SeekAudioUseCase(this._audioService);

  Future<void> call(Duration position) async {
    await _audioService.seekTo(position);
  }
}

class PlayNextVerseUseCase {
  final AudioService _audioService;

  PlayNextVerseUseCase(this._audioService);

  Future<void> call() async {
    await _audioService.playNext();
  }
}

class PlayPreviousVerseUseCase {
  final AudioService _audioService;

  PlayPreviousVerseUseCase(this._audioService);

  Future<void> call() async {
    await _audioService.playPrevious();
  }
}

class ToggleRepeatModeUseCase {
  final AudioService _audioService;

  ToggleRepeatModeUseCase(this._audioService);

  void call() {
    _audioService.toggleRepeatMode();
  }
}

class SetVolumeUseCase {
  final AudioService _audioService;

  SetVolumeUseCase(this._audioService);

  Future<void> call(double volume) async {
    await _audioService.setVolume(volume);
  }
}

class SetPlaybackSpeedUseCase {
  final AudioService _audioService;

  SetPlaybackSpeedUseCase(this._audioService);

  Future<void> call(double speed) async {
    await _audioService.setSpeed(speed);
  }
}

class IsAudioDownloadedUseCase {
  final AudioService _audioService;

  IsAudioDownloadedUseCase(this._audioService);

  Future<bool> call(String url) async {
    return await _audioService.isAudioDownloaded(url);
  }
}

class DownloadAudioUseCase {
  final AudioService _audioService;

  DownloadAudioUseCase(this._audioService);

  Future<void> call(String url, Function(double) onProgress) async {
    await _audioService.downloadAudio(url, onProgress);
  }
}

class DeleteAudioUseCase {
  final AudioService _audioService;

  DeleteAudioUseCase(this._audioService);

  Future<void> call(String url) async {
    await _audioService.deleteAudio(url);
  }
}

class DownloadSurahAudioUseCase {
  final AudioService _audioService;

  DownloadSurahAudioUseCase(this._audioService);

  Future<void> call(int surahId, List<Verse> verses, Function(double) onProgress) async {
    await _audioService.downloadSurahAudio(surahId, verses, onProgress);
  }
}

class GetDownloadedSizeForSurahUseCase {
  final AudioService _audioService;

  GetDownloadedSizeForSurahUseCase(this._audioService);

  Future<double> call(int surahId, List<Verse> verses) async {
    return await _audioService.getDownloadedSizeForSurah(surahId, verses);
  }
}
