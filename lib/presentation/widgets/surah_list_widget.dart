import 'package:flutter/material.dart';
import '../providers/app_state_provider.dart';
import 'package:provider/provider.dart';
import '../providers/reading_progress_provider.dart';
import '../theme/theme.dart';
import '../providers/quran_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/word_by_word_provider.dart';
import '../../domain/entities/surah_meta.dart';
import '../providers/surah_selection_provider.dart';

class SurahListWidget extends StatelessWidget {
  const SurahListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Fine-grained selects to avoid rebuilding the whole list for unrelated provider changes.
    final isLoading = context.select<QuranProvider, bool>((p) => p.isLoading);
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = context.select<QuranProvider, String?>((p) => p.error);
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text('Gabim në ngarkimin e të dhënave'),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<QuranProvider>().loadSurahs(),
              child: const Text('Provo përsëri'),
            ),
          ],
        ),
      );
    }

    final surahs = context.select<QuranProvider, List<SurahMeta>>((p) => p.surahs);
    if (surahs.isEmpty) {
      return const Center(child: Text('Nuk u gjetën sure'));
    }

    final selectionMode = context.select<SurahSelectionProvider, bool>((s) => s.selectionMode);
    final selection = context.read<SurahSelectionProvider>();
    final progressProvider = context.read<ReadingProgressProvider>();

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const double targetTileWidth = 320;
            int columns = (width / targetTileWidth).floor().clamp(1, 6);
            if (width < 600) columns = 1;
            if (columns == 1) {
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 96, top: 8),
                // Fix the row extent to provide enough vertical space for the tile contents
                itemExtent: 120,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                addSemanticIndexes: false,
                itemCount: surahs.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _ContinueCardLoader(surahs: surahs);
                  }
                  final surah = surahs[index - 1];
                  return SurahListItem(
                    key: ValueKey<int>(surah.number),
                    surah: surah,
                    onTap: () => selectionMode ? selection.toggle(surah.number) : _onSurahTap(context, surah),
                    onLongPress: () => selection.toggle(surah.number),
                    onPlay: () => _playSingleSurah(context, surah),
                  );
                },
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.only(bottom: 96, left: 4, right: 4, top: 4),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              addSemanticIndexes: false,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 3.6,
              ),
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                final surah = surahs[index];
                return Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: SurahListItem(
                    key: ValueKey<int>(surah.number),
                    surah: surah,
                    onTap: () => selectionMode ? selection.toggle(surah.number) : _onSurahTap(context, surah),
                    onLongPress: () => selection.toggle(surah.number),
                    onPlay: () => _playSingleSurah(context, surah),
                  ),
                );
              },
            );
          },
        ),
        if (selectionMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SelectionActionBar(
              count: selection.count,
              onCancel: selection.clear,
              onPrimary: () => _playSelected(context, selection.selectedIds),
              onDownload: () => _downloadSelected(context, selection.selectedIds),
            ),
          ),
      ],
    );
  }

  void _onSurahTap(BuildContext context, SurahMeta surah) {
    _loadSurah(context, surah);
  }

  void _loadSurah(BuildContext context, SurahMeta surah) {
    context.read<QuranProvider>().ensureSurahLoaded(surah.number);
  }

  Future<void> _playSingleSurah(BuildContext context, SurahMeta surah) async {
    final provider = context.read<QuranProvider>();
    await provider.ensureSurahLoaded(surah.number);
  if (!context.mounted) return;
    final wbw = context.read<WordByWordProvider>();
    final verses = provider.fullCurrentSurahVerses; // full surah verses
    if (verses.isEmpty) return;
    context.read<AudioProvider>().playSurah(verses, wbwProvider: wbw);
  }

  Future<void> _playSelected(BuildContext context, List<int> selected) async {
    if (selected.isEmpty) return;
    final q = context.read<QuranProvider>();
    final first = selected.first;
    final surah = q.surahs.firstWhere((s) => s.number == first, orElse: () => q.surahs.first);
    await _playSingleSurah(context, surah);
  if (!context.mounted) return;
  context.read<AppStateProvider>().enqueueSnack('Luajti ${selected.length} sure (multi playlist TODO)');
    context.read<SurahSelectionProvider>().clear();
  }

  void _downloadSelected(BuildContext context, List<int> selected) {
  context.read<AppStateProvider>().enqueueSnack('Shkarkimi i ${selected.length} sureve (skeleton)');
  }
}

class SurahListItem extends StatelessWidget {
  final SurahMeta surah;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPlay;

  const SurahListItem({
    super.key,
    required this.surah,
    required this.onTap,
    this.onLongPress,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Read only what this tile cares about
    final selectionMode = context.select<SurahSelectionProvider, bool>((s) => s.selectionMode);
    final selected = context.select<SurahSelectionProvider, bool>((s) => s.isSelected(surah.number));
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7);
    final borderColor = selected ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.15);
    final bgOverlay = selected ? theme.colorScheme.primary.withValues(alpha: 0.10) : Colors.transparent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: selected ? 2 : 1),
        color: bgOverlay,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        selected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: selected ? theme.colorScheme.primary : theme.iconTheme.color?.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      surah.nameTranslation,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.play_arrow, color: theme.colorScheme.primary),
                    splashRadius: 20,
                    onPressed: onPlay,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text('Nr. ${surah.number} • ${surah.versesCount} ajete',
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(surah.revelation, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                  const Spacer(),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      surah.nameArabic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyArabic.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Only this tile listens to its own progress value
              Selector<ReadingProgressProvider, double>(
                selector: (context, prov) => prov.progressPercentSync(surah.number, totalVerses: surah.versesCount),
                builder: (context, p, __) {
                  if (p <= 0) return const SizedBox.shrink();
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: p,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final SurahMeta surah; final int verse; final VoidCallback onTap;
  const _ContinueCard({required this.surah, required this.verse, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.25))),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.play_circle_fill, color: theme.colorScheme.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vazhdo leximin', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height:4),
                    Text('Sure ${surah.nameTranslation} • Ajeti $verse', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.iconTheme.color),
            ],
          ),
        ),
      ),
    );
  }
}

// Defers fetching "Continue Reading" resume point until after first frame to reduce startup work.
class _ContinueCardLoader extends StatefulWidget {
  final List<SurahMeta> surahs;
  const _ContinueCardLoader({required this.surahs});
  @override
  State<_ContinueCardLoader> createState() => _ContinueCardLoaderState();
}

class _ContinueCardLoaderState extends State<_ContinueCardLoader> {
  ReadingResumePoint? _resume;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final rp = await context.read<ReadingProgressProvider>().getMostRecent();
        if (!mounted) return;
        setState(() => _resume = rp);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final rp = _resume;
    if (rp == null) return const SizedBox.shrink();
    final meta = widget.surahs.firstWhere((s) => s.number == rp.surah, orElse: () => widget.surahs.first);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: _ContinueCard(
        surah: meta,
        verse: rp.verse,
        onTap: () async {
          context.read<QuranProvider>().openSurahAtVerse(rp.surah, rp.verse);
          if (!mounted) return;
          context.read<AppStateProvider>().enqueueSnack('Vazhduat te ${meta.nameTranslation} • Ajeti ${rp.verse}');
        },
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onCancel;
  final VoidCallback onPrimary;
  final VoidCallback onDownload;
  const _SelectionActionBar({
    required this.count,
    required this.onCancel,
    required this.onPrimary,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text('$count zgjedhur', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: 'Shkarko (skeleton)',
              icon: const Icon(Icons.download),
              onPressed: onDownload,
            ),
            FilledButton.icon(
              onPressed: onPrimary,
              icon: const Icon(Icons.playlist_play),
              label: const Text('Luaj'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: const Text('Anulo'),
            )
          ],
        ),
      ),
    );
  }
}
