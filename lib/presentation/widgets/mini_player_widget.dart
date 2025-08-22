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
        if (quran.surahs.isEmpty) return const SizedBox.shrink();
        final surahMeta = quran.surahs.firstWhere(
          (s) => s.number == verse.surahNumber,
          orElse: () => quran.surahs.first,
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
                    Semantics(
                      button: true,
                      label: audio.isPlaying ? 'Pauzo' : 'Luaj',
                      child: IconButton(
                      icon: Icon(
                        audio.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: scheme.primary,
                        size: 36,
                      ),
                        onPressed: () => audio.togglePlayPause(),
                      ),
                    ),
                    if (!audio.isPlaylistMode)
                      Semantics(
                        button: true,
                        label: audio.isSingleVerseLoop ? 'Hiq loop ajet' : 'Loop ajetin',
                        child: IconButton(
                        icon: Icon(
                          Icons.repeat_one,
                          color: audio.isSingleVerseLoop ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                        tooltip: audio.isSingleVerseLoop ? 'Hiq loop' : 'Loop ajetin',
                          onPressed: () => audio.setSingleVerseLoop(!audio.isSingleVerseLoop),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${surahMeta.nameTranslation.isNotEmpty ? surahMeta.nameTranslation : 'Sure'} • Ajeti ${verse.number}',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: context.spaceXs),
                          Semantics(
                            label: 'Progresi i leximit ${(progress * 100).toStringAsFixed(0)} përqind',
                            child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress > 0 && progress.isFinite ? progress : null,
                              minHeight: 4,
                              backgroundColor: scheme.primary.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation(scheme.primary),
                            ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Mbyll mini playerin',
                      child: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Mbyll',
                        onPressed: () async {
                        await audio.stop();
                        },
                      ),
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
      builder: (ctx) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          audio.isPlayerExpanded = false;
        },
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
          if (audio.isPlaylistMode && audio.isABLoopEnabled && audio.loopStartVerse != null && audio.loopEndVerse != null)
            Padding(
              padding: EdgeInsets.only(bottom: context.spaceSm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  label: 'A deri B aktiv nga ${audio.loopStartVerse!.surahNumber}:${audio.loopStartVerse!.number} deri ${audio.loopEndVerse!.surahNumber}:${audio.loopEndVerse!.number}' + (audio.remainingABLoops != null ? ', mbetur ${audio.remainingABLoops} herë' : ''),
                  child: InputChip(
                  label: Text(
                    'A-B: ${audio.loopStartVerse!.surahNumber}:${audio.loopStartVerse!.number} → ${audio.loopEndVerse!.surahNumber}:${audio.loopEndVerse!.number}' +
                    (audio.remainingABLoops != null ? ' ×${audio.remainingABLoops}' : ''),
                  ),
                  avatar: const Icon(Icons.loop, size: 18),
                  onDeleted: audio.disableABLoop,
                  deleteIcon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
          Semantics(
            label: 'Rrëshqitësi i kohës së leximit',
            child: Slider(
            value: audio.progress.clamp(0.0, 1.0),
            onChanged: (v) => audio.seekToProgress(v),
            ),
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
              Semantics(
                button: true,
                label: 'Kalo në ajetin e mëparshëm',
                child: IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: audio.playPrevious,
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: audio.isPlaying ? 'Pauzo' : 'Luaj',
                child: ElevatedButton(
                onPressed: audio.togglePlayPause,
                child: Icon(audio.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'Kalo në ajetin tjetër',
                child: IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: audio.playNext,
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: audio.isRepeatMode ? 'Çaktivizo përsëritjen' : 'Aktivizo përsëritjen',
                child: IconButton(
                icon: Icon(audio.isRepeatMode ? Icons.repeat_on : Icons.repeat),
                color: audio.isRepeatMode ? scheme.primary : null,
                onPressed: audio.toggleRepeatMode,
                ),
              ),
              if (!audio.isPlaylistMode)
                Semantics(
                  button: true,
                  label: audio.isSingleVerseLoop ? 'Hiq loop ajet' : 'Loop ajetin',
                  child: IconButton(
                  icon: Icon(audio.isSingleVerseLoop ? Icons.repeat_one_on : Icons.repeat_one),
                  color: audio.isSingleVerseLoop ? scheme.primary : null,
                  tooltip: 'Loop ajetin',
                  onPressed: () => audio.setSingleVerseLoop(!audio.isSingleVerseLoop),
                  ),
                ),
              if (!audio.isPlaylistMode)
                PopupMenuButton<int>(
                  tooltip: 'Numër përsëritjesh',
                  icon: const Icon(Icons.filter_1),
                  onSelected: (v) => audio.setSingleVerseLoopCount(v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 2, child: Text('2x')), 
                    PopupMenuItem(value: 3, child: Text('3x')),
                    PopupMenuItem(value: 5, child: Text('5x')),
                    PopupMenuItem(value: 10, child: Text('10x')),
                    PopupMenuItem(value: 0, child: Text('Paq (hiq)')),
                  ],
                ),
              // A-B loop controls for playlist mode (MEMO-2b)
              if (audio.isPlaylistMode) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Cakto pika A (fillimi) te ajeti aktual',
                  child: IconButton(
                    icon: const Icon(Icons.flag),
                    onPressed: () {
                      final v = audio.currentVerse;
                      if (v != null) {
                        audio.setABLoop(start: v, end: audio.loopEndVerse ?? v, repeatCount: audio.remainingABLoops);
                      }
                    },
                  ),
                ),
                Tooltip(
                  message: 'Cakto pika B (fundi) te ajeti aktual',
                  child: IconButton(
                    icon: const Icon(Icons.flag_circle),
                    onPressed: () {
                      final v = audio.currentVerse;
                      if (v != null) {
                        audio.setABLoop(start: audio.loopStartVerse ?? v, end: v, repeatCount: audio.remainingABLoops);
                      }
                    },
                  ),
                ),
                Tooltip(
                  message: audio.isABLoopEnabled ? 'Çaktivizo A-B loop' : 'Aktivizo A-B loop',
                  child: IconButton(
                    icon: Icon(audio.isABLoopEnabled ? Icons.repeat_on : Icons.repeat),
                    color: audio.isABLoopEnabled ? scheme.primary : null,
                    onPressed: () {
                      final v = audio.currentVerse;
                      if (audio.isABLoopEnabled) {
                        audio.disableABLoop();
                      } else if (v != null) {
                        audio.setABLoop(start: audio.loopStartVerse ?? v, end: audio.loopEndVerse ?? v, repeatCount: audio.remainingABLoops);
                      }
                    },
                  ),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Numër përsëritjesh A-B',
                  icon: const Icon(Icons.filter_2),
                  onSelected: (v) {
                    final cnt = v == 0 ? null : v;
                    final cur = audio.currentVerse;
                    if (cur != null) {
                      audio.setABLoop(start: audio.loopStartVerse ?? cur, end: audio.loopEndVerse ?? cur, repeatCount: cnt);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 2, child: Text('2x A-B')), 
                    PopupMenuItem(value: 3, child: Text('3x A-B')),
                    PopupMenuItem(value: 5, child: Text('5x A-B')),
                    PopupMenuItem(value: 10, child: Text('10x A-B')),
                    PopupMenuItem(value: 0, child: Text('Paq (hiq)')),
                  ],
                ),
              ],
            ],
          ),
        ],
      );
    });
  }
}
