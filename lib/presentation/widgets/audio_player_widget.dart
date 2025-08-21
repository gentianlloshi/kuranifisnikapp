import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../../domain/entities/verse.dart';
import '../theme/theme.dart';
import 'sheet_header.dart';

class AudioPlayerWidget extends StatefulWidget {
  final bool mini;

  const AudioPlayerWidget({super.key, this.mini = false});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        if (audioProvider.currentVerse == null) {
          return const SizedBox.shrink();
        }

        final currentVerse = audioProvider.currentVerse!;

        Widget content;
        if (widget.mini) {
          content = _buildMiniPlayer(context, audioProvider, currentVerse);
        } else {
          content = _buildFullPlayer(context, audioProvider, currentVerse);
        }

        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: context.spaceLg, vertical: context.spaceSm),
          child: Material(
            elevation: 2,
            color: scheme.surface,
            borderRadius: BorderRadius.circular(context.radiusCard.x),
            child: Padding(
              padding: EdgeInsets.all(context.spaceLg),
              child: content,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniPlayer(BuildContext context, AudioProvider audioProvider, Verse currentVerse) {
    return Row(
      children: [
        Icon(
          audioProvider.isPlaying ? Icons.volume_up : Icons.volume_off,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(width: context.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sure ${currentVerse.surahNumber}, Ajeti ${currentVerse.number}',
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                audioProvider.formatDuration(audioProvider.currentPosition) + 
                ' / ' + 
                (audioProvider.currentDuration != null ? audioProvider.formatDuration(audioProvider.currentDuration!) : '--:--'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
    IconButton(
          onPressed: audioProvider.isLoading
              ? null
              : () => audioProvider.togglePlayPause(),
          icon: Icon(
            audioProvider.isLoading
                ? Icons.hourglass_empty
                : audioProvider.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
      color: Theme.of(context).colorScheme.primary,
          ),
        ),
        IconButton(
          onPressed: () {
            audioProvider.isPlayerExpanded = true;
            // Optionally navigate to full player or show as bottom sheet
          },
          icon: const Icon(Icons.expand_less),
        ),
        IconButton(
          tooltip: audioProvider.isSingleVerseLoop ? 'Hiq loop' : 'Loop ajetin',
          onPressed: audioProvider.isPlaylistMode ? null : () => audioProvider.setSingleVerseLoop(!audioProvider.isSingleVerseLoop),
          icon: Icon(
            Icons.repeat_one,
            color: audioProvider.isSingleVerseLoop ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color,
          ),
        ),
      ],
    );
  }

  Widget _buildFullPlayer(BuildContext context, AudioProvider audioProvider, Verse currentVerse) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current verse info
        Row(
          children: [
            Icon(
              Icons.volume_up,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sure ${currentVerse.surahNumber}, Ajeti ${currentVerse.number}',
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () => audioProvider.stop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        
  SizedBox(height: context.spaceMd),
        
        // Progress bar
        Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 3,
              ),
              child: Slider(
                value: audioProvider.progress.clamp(0.0, 1.0),
                onChanged: audioProvider.isLoading 
                    ? null 
                    : (value) => audioProvider.seekToProgress(value),
              ),
            ),
            
            // Time indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    audioProvider.formatDuration(audioProvider.currentPosition),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    audioProvider.currentDuration != null
                        ? audioProvider.formatDuration(audioProvider.currentDuration!)
                        : '--:--',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        
  SizedBox(height: context.spaceMd),
        
        // Control buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Previous button
            IconButton(
              onPressed: audioProvider.isLoading 
                  ? null 
                  : () => audioProvider.playPrevious(),
              icon: const Icon(Icons.skip_previous),
            ),
            
            // Play/Pause button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.all(context.spaceSm),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
              ),
              onPressed: audioProvider.isLoading ? null : () => audioProvider.togglePlayPause(),
              child: Icon(
                audioProvider.isLoading
                    ? Icons.hourglass_empty
                    : audioProvider.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
              ),
            ),
            
            // Next button
            IconButton(
              onPressed: audioProvider.isLoading 
                  ? null 
                  : () => audioProvider.playNext(),
              icon: const Icon(Icons.skip_next),
            ),
            
            // Repeat button
            IconButton(
              onPressed: () => audioProvider.toggleRepeatMode(),
              icon: Icon(
                audioProvider.isRepeatMode ? Icons.repeat_on : Icons.repeat,
                color: audioProvider.isRepeatMode 
                    ? Theme.of(context).primaryColor 
                    : null,
              ),
            ),
            // Single verse loop (only in single verse mode)
            IconButton(
              tooltip: 'Loop ajetin aktual',
              onPressed: audioProvider.isPlaylistMode ? null : () => audioProvider.setSingleVerseLoop(!audioProvider.isSingleVerseLoop),
              icon: Icon(
                Icons.repeat_one,
                color: audioProvider.isSingleVerseLoop ? Theme.of(context).primaryColor : null,
              ),
            ),
            
            // More options button
            IconButton(
              onPressed: () => _showAudioOptions(context, audioProvider),
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
  SizedBox(height: context.spaceLg),
        // Download button
        _buildDownloadButton(context, audioProvider, currentVerse),
      ],
    );
  }

  Widget _buildDownloadButton(BuildContext context, AudioProvider audioProvider, Verse currentVerse) {
    return FutureBuilder<bool>(
      future: audioProvider.isVerseAudioDownloaded(currentVerse),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        if (_isDownloading) {
          return Column(
            children: [
              LinearProgressIndicator(value: _downloadProgress),
              Text('${(_downloadProgress * 100).toStringAsFixed(0)}% e shkarkuar'),
            ],
          );
        } else if (isDownloaded) {
          return ElevatedButton.icon(
            onPressed: () async {
              await audioProvider.deleteVerseAudio(currentVerse);
              setState(() {}); // Refresh UI
            },
            icon: const Icon(Icons.delete),
            label: const Text('Fshij Audio'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          );
        } else {
          return ElevatedButton.icon(
            onPressed: () async {
              setState(() {
                _isDownloading = true;
                _downloadProgress = 0.0;
              });
              try {
                await audioProvider.downloadVerseAudio(currentVerse, (progress) {
                  setState(() {
                    _downloadProgress = progress;
                  });
                });
                context.read<AppStateProvider>().enqueueSnack('Audio u shkarkua me sukses!');
              } catch (e) {
                context.read<AppStateProvider>().enqueueSnack('Gabim gjatë shkarkimit: $e');
              } finally {
                setState(() {
                  _isDownloading = false;
                  _downloadProgress = 0.0;
                });
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Shkarko Audio'),
          );
        }
      },
    );
  }

  void _showAudioOptions(BuildContext context, AudioProvider audioProvider) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => BottomSheetWrapper(
        child: AudioOptionsSheet(audioProvider: audioProvider),
      ),
    );
  }
}

class AudioOptionsSheet extends StatefulWidget {
  final AudioProvider audioProvider;

  const AudioOptionsSheet({
    super.key,
    required this.audioProvider,
  });

  @override
  State<AudioOptionsSheet> createState() => _AudioOptionsSheetState();
}

class _AudioOptionsSheetState extends State<AudioOptionsSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(
            title: 'Opsionet e Audio-s',
            leadingIcon: Icons.settings_voice,
            onClose: () => Navigator.of(context).maybePop(),
            divider: false,
          ),
          SizedBox(height: context.spaceMd),
          
          // Volume control
          Text(
            'Volumi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: context.spaceSm),
          Row(
            children: [
              const Icon(Icons.volume_down),
              Expanded(
                child: Slider(
                  value: widget.audioProvider.volume,
                  onChanged: (value) => widget.audioProvider.setVolume(value),
                ),
              ),
              const Icon(Icons.volume_up),
            ],
          ),
          
          SizedBox(height: context.spaceMd),
          
          // Playback speed control
          Text(
            'Shpejtësia e Leximit',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: context.spaceSm),
          Row(
            children: [
              const Text('0.5x'),
              Expanded(
                child: Slider(
                  value: widget.audioProvider.playbackSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  label: '${widget.audioProvider.playbackSpeed}x',
                  onChanged: (value) => widget.audioProvider.setPlaybackSpeed(value),
                ),
              ),
              const Text('2.0x'),
            ],
          ),
          
          SizedBox(height: context.spaceMd),
          
          // Repeat mode toggle
          SwitchListTile(
            title: const Text('Përsërit'),
            subtitle: const Text('Përsërit listën e leximit'),
            value: widget.audioProvider.isRepeatMode,
            onChanged: (_) => widget.audioProvider.toggleRepeatMode(),
          ),
          
          SizedBox(height: context.spaceMd),
          
          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mbyll'),
            ),
          ),
        ],
      ),
    );
  }
}


