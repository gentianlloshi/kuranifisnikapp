import 'package:flutter/material.dart';
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
    return Consumer3<QuranProvider, SurahSelectionProvider, ReadingProgressProvider>(
      builder: (context, quranProvider, selectionProvider, progressProvider, child) {
        if (quranProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (quranProvider.error != null) {
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
                Text(
                  'Gabim në ngarkimin e të dhënave',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  quranProvider.error!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => quranProvider.loadSurahs(),
                  child: const Text('Provo përsëri'),
                ),
              ],
            ),
          );
        }

  final surahs = quranProvider.surahs; // List<SurahMeta>
        if (surahs.isEmpty) {
          return const Center(
            child: Text('Nuk u gjetën sure'),
          );
        }

  final selection = selectionProvider;
  final selectionMode = selection.selectionMode;
  return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                // Refined breakpoints using an approximate target tile width
                const double targetTileWidth = 320;
                int columns = (width / targetTileWidth).floor().clamp(1, 6);
                // Ensure legacy breakpoints minimums still honored
                if (width < 600) columns = 1;
                if (columns == 1) {
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 96, top: 8),
                    itemCount: surahs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return FutureBuilder<ReadingResumePoint?>(
                          future: progressProvider.getMostRecent(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                            final rp = snapshot.data!;
                            final meta = surahs.firstWhere((s) => s.number == rp.surah, orElse: () => surahs.first);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: _ContinueCard(
                                surah: meta,
                                verse: rp.verse,
                                onTap: () => context.read<QuranProvider>().openSurahAtVerse(rp.surah, rp.verse),
                              ),
                            );
                          },
                        );
                      }
                      final surah = surahs[index - 1];
                      final surah = surahs[index];
                      final selected = selection.isSelected(surah.number);
                      return SurahListItem(
                        surah: surah,
                        selected: selected,
                        selectionMode: selectionMode,
                        onTap: () => selectionMode ? selection.toggle(surah.number) : _onSurahTap(context, surah),
                        onLongPress: () => selection.toggle(surah.number),
                        onPlay: () => _playSingleSurah(context, surah),
                        progressProvider: progressProvider,
                      );
                    },
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.only(bottom: 96, left: 4, right: 4, top: 4),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 3.6,
                  ),
                  itemCount: surahs.length,
                  itemBuilder: (context, index) {
                    final surah = surahs[index];
          final selected = selection.isSelected(surah.number);
                    return Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: SurahListItem(
                        surah: surah,
                        selected: selected,
            selectionMode: selectionMode,
            onTap: () => selectionMode ? selection.toggle(surah.number) : _onSurahTap(context, surah),
            onLongPress: () => selection.toggle(surah.number),
                        onPlay: () => _playSingleSurah(context, surah),
                        progressProvider: progressProvider,
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
      },
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Luajti ${selected.length} sure (multi playlist TODO)')));
    context.read<SurahSelectionProvider>().clear();
  }

  void _downloadSelected(BuildContext context, List<int> selected) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Shkarkimi i ${selected.length} sureve (skeleton)')));
  }
}

class SurahListItem extends StatelessWidget {
  final SurahMeta surah;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPlay;
  final bool selectionMode;
  final bool selected;
  final ReadingProgressProvider? progressProvider;

  const SurahListItem({
    super.key,
    required this.surah,
    required this.onTap,
    this.onLongPress,
    this.onPlay,
    this.selectionMode = false,
    this.selected = false,
  this.progressProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final muted = theme.textTheme.bodySmall?.color?.withOpacity(0.7);
    final borderColor = selected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.15);
    final bgOverlay = selected ? theme.colorScheme.primary.withOpacity(0.10) : Colors.transparent;
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
                        color: selected ? theme.colorScheme.primary : theme.iconTheme.color?.withOpacity(0.5),
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
                      style: theme.textTheme.bodyArabic.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (progressProvider != null)
                FutureBuilder<double>(
                  future: progressProvider!.getProgressPercent(surah.number, totalVerses: surah.versesCount),
                  builder: (context, snapshot) {
                    final p = snapshot.data ?? 0;
                    if (p <= 0) return const SizedBox.shrink();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: p,
                        backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.35),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.25))),
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
