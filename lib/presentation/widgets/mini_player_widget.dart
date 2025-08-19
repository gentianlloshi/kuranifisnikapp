import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../providers/quran_provider.dart';
import '../theme/theme.dart';
import 'sheet_header.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        final verse = audio.currentVerse;
        if (verse == null) return const SizedBox.shrink();
        if (audio.isPlayerExpanded) return const SizedBox.shrink();
        final quran = context.read<QuranProvider>();
        final surah = quran.surahs.firstWhere(
          (s) => s.number == verse.surahNumber,
          orElse: () => quran.currentSurah ?? (quran.surahs.isNotEmpty ? quran.surahs.first : null)!,
        );
        final progress = audio.progress.clamp(0.0, 1.0);
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          top: false,
          child: Material(
            elevation: 6,
            color: scheme.surface,
            child: InkWell(
              onTap: () => _openFull(context),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.spaceLg, vertical: context.spaceSm),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        audio.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: scheme.primary,
                        size: 36,
                      ),
                      onPressed: () => audio.togglePlayPause(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${surah.nameTranslation.isNotEmpty ? surah.nameTranslation : 'Sure'} • Ajeti ${verse.number}',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: context.spaceXs),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress > 0 && progress.isFinite ? progress : null,
                              minHeight: 4,
                              backgroundColor: scheme.primary.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation(scheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Mbyll',
                      onPressed: () async {
                        await audio.stop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFull(BuildContext context) {
    final audio = context.read<AudioProvider>();
    audio.isPlayerExpanded = true; // hide mini
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => WillPopScope(
        onWillPop: () async { audio.isPlayerExpanded = false; return true; },
        child: BottomSheetWrapper(
          padding: EdgeInsets.all(context.spaceLg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(
                  title: 'Leximi i Ajetit',
                  leadingIcon: Icons.play_circle_fill,
                  onClose: () {
                    audio.isPlayerExpanded = false;
                    Navigator.pop(context);
                  },
                ),
                SizedBox(height: context.spaceMd),
                _FullPlayerCore(),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => audio.isPlayerExpanded = false);
  }
}

class _FullPlayerCore extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(builder: (context, audio, _) {
      final verse = audio.currentVerse;
      if (verse == null) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      final pos = audio.currentPosition;
      final dur = audio.currentDuration ?? Duration.zero;
      String _fmt(Duration d){
        final m = d.inMinutes.remainder(60).toString().padLeft(2,'0');
        final s = d.inSeconds.remainder(60).toString().padLeft(2,'0');
        return '$m:$s';
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sure ${verse.surahNumber} • Ajeti ${verse.number}', style: Theme.of(context).textTheme.bodyLarge),
          SizedBox(height: context.spaceMd),
          Slider(
            value: audio.progress.clamp(0.0, 1.0),
            onChanged: (v) => audio.seekToProgress(v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(pos), style: Theme.of(context).textTheme.bodySmall),
              Text(_fmt(dur), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          SizedBox(height: context.spaceLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: audio.playPrevious,
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: audio.togglePlayPause,
                child: Icon(audio.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: audio.playNext,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(audio.isRepeatMode ? Icons.repeat_on : Icons.repeat),
                color: audio.isRepeatMode ? scheme.primary : null,
                onPressed: audio.toggleRepeatMode,
              ),
            ],
          ),
        ],
      );
    });
  }
}
