import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'dart:async';

import '../providers/memorization_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/quran_provider.dart';
import '../providers/selection_service.dart';
import '../../domain/entities/verse.dart';
import '../theme/theme.dart';
import '../../domain/entities/memorization_verse.dart';

/// New Memorization Tab (MEMO-1):
/// - Sticky controls header (stats + actions)
/// - Group navigation (prev/next surah groups)
/// - Verses list for active surah with status chips & selection support placeholder
class MemorizationTab extends StatefulWidget {
  const MemorizationTab({super.key});
  @override
  State<MemorizationTab> createState() => _MemorizationTabState();
}

class _MemorizationTabState extends State<MemorizationTab> {
  bool _initialized = false;
  final ScrollController _scrollController = ScrollController();
  int? _requestedArabicSurah; // MEMO-3: avoid redundant surah loads for Arabic text

  // reserved for future audio binding (auto-scroll listener)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Load data (new provider API)
      WidgetsBinding.instance.addPostFrameCallback((_) => context.read<MemorizationProvider>().load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MemorizationProvider, SelectionService>(
      builder: (context, mem, selection, _) {
        if (mem.isLoading && mem.groupedSurahs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (mem.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Gabim: ${mem.error}', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => mem.load(),
                  child: const Text('Ringarko'),
                ),
              ],
            ),
          );
        }
        if (mem.groupedSurahs.isEmpty) {
          return _buildEmptyState(context);
        }
  // Observe current playing verse for auto-scroll
  final audio = context.watch<AudioProvider>();
  _maybeAutoScroll(mem, audio.currentVerse);
  final selecting = selection.mode == SelectionMode.memorization;
  return CustomScrollView(
          controller: _scrollController,
          slivers: [
            if (selecting)
              SliverToBoxAdapter(
                child: _MemSelectionBar(
                  count: selection.selected.length,
                  onCancel: selection.clear,
                  onRemove: () async {
                    for (final key in selection.selected.toList()) {
                      final parts = key.split(':');
                      if (parts.length==2) {
                        final s = int.tryParse(parts[0]);
                        final v = int.tryParse(parts[1]);
                        if (s!=null && v!=null) { await mem.removeVerse(s,v); }
                      }
                    }
                    selection.clear();
                    if (context.mounted) {
                      context.read<AppStateProvider>().enqueueSnack('U hoqën ajetet e përzgjedhura');
                    }
                  },
                ),
              ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(child: _buildHeader(context, mem), minExtent: 140, maxExtent: 180),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, index) {
                  final verses = mem.versesForActiveSurah();
                  if (index >= verses.length) return null;
                  final mv = verses[index];
                  return _buildVerseTile(context, mem, mv);
                },
                childCount: mem.versesForActiveSurah().length,
              ),
            ),
            if (mem.versesForActiveSurah().isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(context.spaceXl),
                  child: const Text('Nuk ka ajete të zgjedhura për këtë sure.'),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 64)),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 72, color: Theme.of(context).colorScheme.primary.withOpacity(0.35)),
            SizedBox(height: context.spaceLg),
            Text('Shtoni ajete nga pamja e leximit për të nisur memorizimin.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, MemorizationProvider mem) {
    final global = mem.globalStatusCounts();
    final active = mem.statusCountsForActive();
    final activeSurah = mem.activeSurah;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: context.spaceMd, right: context.spaceMd, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Memorizim', style: Theme.of(context).textTheme.titleLarge),
                ),
                _NavButton(icon: Icons.chevron_left, onTap: mem.goToPrevGroup, enabled: _hasPrev(mem)),
                _NavButton(icon: Icons.chevron_right, onTap: mem.goToNextGroup, enabled: _hasNext(mem)),
                IconButton(
                  tooltip: 'Luaj Seancën',
                  icon: const Icon(Icons.play_circle_fill),
                  onPressed: () => _playSession(context, mem),
                ),
              ],
            ),
            if (activeSurah != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Sure $activeSurah  •  ${active['new']} të reja  •  ${active['inProgress']} në progres  •  ${active['mastered']} të mësuara',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            SizedBox(height: context.spaceSm),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatChip(label: 'Totale', value: global.values.fold<int>(0, (a, b) => a + b)),
                        SizedBox(width: context.spaceSm),
                        _StatChip(label: 'Të mësuara', value: global['mastered'] ?? 0, color: Colors.green),
                        SizedBox(width: context.spaceSm),
                        _StatChip(label: 'Në progres', value: global['inProgress'] ?? 0, color: Colors.orange),
                        SizedBox(width: context.spaceSm),
                        _StatChip(label: 'Të reja', value: global['new'] ?? 0, color: Colors.blueGrey),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: mem.hideText ? 'Shfaq tekstin' : 'Fsheh tekstin',
                  onPressed: mem.toggleHideText,
                  icon: Icon(mem.hideText ? Icons.visibility_off : Icons.visibility),
                ),
                IconButton(
                  tooltip: 'Zgjidh të gjitha',
                  onPressed: mem.selectAllForActive,
                  icon: const Icon(Icons.select_all),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playSession(BuildContext context, MemorizationProvider mem) async {
    final session = mem.session;
    if (session == null || session.selectedVerseKeys.isEmpty) return;
    final audio = context.read<AudioProvider>();
    final quran = context.read<QuranProvider>();
    final surah = session.surah;
    // Ensure surah loaded
    if (quran.currentSurah == null || quran.currentSurah!.number != surah) {
      await quran.navigateToSurah(surah);
    }
    final verseNumbers = mem.sessionVerseNumbersOrdered();
    if (verseNumbers.isEmpty) return;
    // Filter verses from provider (paged list may not include all yet); naive approach: ensure all pages loaded until last needed verse present
    int safety = 20;
    while (safety-- > 0) {
      final currentMax = quran.currentVerses.isEmpty ? 0 : quran.currentVerses.map((v) => v.number).reduce((a,b)=>a>b?a:b);
      if (currentMax >= verseNumbers.last) break;
      quran.loadMoreVerses();
      await Future.delayed(const Duration(milliseconds: 30));
    }
    final verses = quran.currentVerses.where((v) => verseNumbers.contains(v.number)).toList()
      ..sort((a,b)=>a.number.compareTo(b.number));
    if (verses.isEmpty) return;
    // Build repeated playlist
    final repeat = (session.repeatTarget <= 1) ? 1 : session.repeatTarget;
  final List<Verse> playlist = [];
  for (int i=0;i<repeat;i++) { playlist.addAll(verses); }
  await audio.playSurah(playlist);
  }

  bool _hasPrev(MemorizationProvider mem) {
    if (mem.activeSurah == null) return false;
    final list = mem.groupedSurahs;
    final idx = list.indexOf(mem.activeSurah!);
    return idx > 0;
  }

  bool _hasNext(MemorizationProvider mem) {
    if (mem.activeSurah == null) return false;
    final list = mem.groupedSurahs;
    final idx = list.indexOf(mem.activeSurah!);
    return idx >= 0 && idx < list.length - 1;
  }

  Widget _buildVerseTile(BuildContext context, MemorizationProvider mem, MemorizationVerse mv) {
    final selected = mem.isSelected(mv.surah, mv.verse);
    String? arabicText;
    final quran = context.watch<QuranProvider>();
    if (quran.currentSurah?.number == mv.surah) {
      for (final v in quran.fullCurrentSurahVerses.isNotEmpty ? quran.fullCurrentSurahVerses : quran.currentVerses) {
        if (v.number == mv.verse) { arabicText = v.textArabic; break; }
      }
    } else if (mem.hideText && _requestedArabicSurah != mv.surah) {
      // Lazy load surah Arabic if entering hide mode
      _requestedArabicSurah = mv.surah;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final qp = context.read<QuranProvider>();
        if (qp.currentSurah?.number != mv.surah) {
          qp.navigateToSurah(mv.surah);
        }
      });
    }
    final sel = context.read<SelectionService>();
    final selecting = sel.mode == SelectionMode.memorization;
    final keyStr = '${mv.surah}:${mv.verse}';
    final isSelected = selecting && sel.contains(keyStr);
    return _MemorizationVerseTile(
      key: ValueKey(mv.key),
      verse: mv,
      selected: selected,
      hideText: mem.hideText,
      arabicText: arabicText,
      onSelect: () {
        if (!selecting) sel.start(SelectionMode.memorization);
        sel.toggle(keyStr);
      },
      onCycle: () => mem.cycleStatus(mv),
      onRemove: () => mem.removeVerse(mv.surah, mv.verse),
    );
  }

  String _statusLabel(MemorizationStatus status) => switch (status) {
        MemorizationStatus.newVerse => 'I Ri',
        MemorizationStatus.inProgress => 'Në Progres',
        MemorizationStatus.mastered => 'I Mësuar',
      };

  DateTime _lastAutoScroll = DateTime.fromMillisecondsSinceEpoch(0);
  static const _autoScrollCooldown = Duration(milliseconds: 500);

  void _maybeAutoScroll(MemorizationProvider mem, Verse? playing) {
    if (playing == null) return;
    if (mem.activeSurah == null || playing.surahNumber != mem.activeSurah) return;
    if (mem.session == null || !mem.session!.selectedVerseKeys.contains('${playing.surahNumber}:${playing.number}')) return;
    final now = DateTime.now();
    if (now.difference(_lastAutoScroll) < _autoScrollCooldown) return;
    _lastAutoScroll = now;
    // Find index
    final verses = mem.versesForActiveSurah();
    final idx = verses.indexWhere((v) => v.verse == playing.number);
    if (idx == -1) return;
    // Compute scroll offset approximation (ListTile height ~72?) use position in sliver list by jumping to index * 72; smooth animate
    final targetOffset = (idx * 72).toDouble();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double _minH;
  final double _maxH;
  _StickyHeaderDelegate({required this.child, required double minExtent, required double maxExtent})
      : _minH = minExtent,
        _maxH = maxExtent;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate._minH != _minH || oldDelegate._maxH != _maxH;
  @override
  double get maxExtent => _maxH;
  @override
  double get minExtent => _minH;
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;
  const _StatChip({required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: TextStyle(fontWeight: FontWeight.bold, color: c)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: c.withOpacity(0.9))),
        ],
      ),
    );
  }
}

class _StatusCycleButton extends StatelessWidget {
  final MemorizationVerse mv;
  final VoidCallback onCycle;
  const _StatusCycleButton({required this.mv, required this.onCycle});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color statusColor;
    String label;
    switch (mv.status) {
      case MemorizationStatus.newVerse:
        label = 'I Ri';
        statusColor = Colors.blueGrey;
        break;
      case MemorizationStatus.inProgress:
        label = 'Në Progres';
        statusColor = Colors.orange;
        break;
      case MemorizationStatus.mastered:
        label = 'I Mësuar';
        statusColor = Colors.green;
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) {
        return ScaleTransition(scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack), child: child);
      },
      child: OutlinedButton(
        key: ValueKey(mv.status),
        style: OutlinedButton.styleFrom(
          foregroundColor: statusColor,
          side: BorderSide(color: statusColor.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        onPressed: onCycle,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: mv.status == MemorizationStatus.mastered ? FontWeight.bold : FontWeight.w500),
          child: Text(label),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final Future<void> Function()? onTap;
  final bool enabled;
  const _NavButton({required this.icon, required this.onTap, required this.enabled});
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon),
      );
}

// MEMO-3: Verse tile with hide-text blur + tap-to-peek reveal.
class _MemorizationVerseTile extends StatefulWidget {
  final MemorizationVerse verse;
  final bool selected;
  final bool hideText;
  final String? arabicText;
  final VoidCallback onSelect;
  final VoidCallback onCycle;
  final VoidCallback onRemove;
  const _MemorizationVerseTile({
    super.key,
    required this.verse,
    required this.selected,
    required this.hideText,
    this.arabicText,
    required this.onSelect,
    required this.onCycle,
    required this.onRemove,
  });

  @override
  State<_MemorizationVerseTile> createState() => _MemorizationVerseTileState();
}

class _MemorizationVerseTileState extends State<_MemorizationVerseTile> with SingleTickerProviderStateMixin {
  bool _peek = false;
  Timer? _reHideTimer;
  static const _peekDuration = Duration(seconds: 5);

  @override
  void didUpdateWidget(covariant _MemorizationVerseTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.hideText) {
      _cancelTimer();
      if (_peek) setState(() => _peek = false);
    }
  }

  void _cancelTimer() { _reHideTimer?.cancel(); _reHideTimer = null; }

  void _togglePeek() {
    if (!widget.hideText) return; // not in hide mode
    setState(() => _peek = !_peek);
    _cancelTimer();
    if (_peek) {
      _reHideTimer = Timer(_peekDuration, () {
        if (mounted) setState(() => _peek = false);
      });
    }
  }

  Color _statusColor(MemorizationStatus status) => switch (status) {
        MemorizationStatus.newVerse => Colors.blueGrey,
        MemorizationStatus.inProgress => Colors.orange,
        MemorizationStatus.mastered => Colors.green,
      };

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mv = widget.verse;
    final colorScheme = Theme.of(context).colorScheme;
  final tileColor = widget.selected ? colorScheme.primary.withOpacity(0.12) : Colors.transparent;
    final statusColor = _statusColor(mv.status);
    return InkWell(
      onTap: widget.onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tileColor,
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 18, child: Text('${mv.verse}')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Ajeti ${mv.verse}', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(width: 8),
                      _StatusCycleButton(mv: mv, onCycle: widget.onCycle),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    child: _buildArabicMasked(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Hiq',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onRemove,
                ),
                if (widget.hideText)
                  IconButton(
                    tooltip: _peek ? 'Fsheh' : 'Shfaq',
                    icon: Icon(_peek ? Icons.visibility : Icons.visibility_off, size: 20),
                    onPressed: _togglePeek,
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildArabicMasked(BuildContext context) {
    final hide = widget.hideText && !_peek;
  final arabic = widget.arabicText ?? '…';
    final baseStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20, height: 1.4);
    if (!hide) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: 1,
        child: Text(arabic, textDirection: TextDirection.rtl, style: baseStyle),
      );
    }
    return GestureDetector(
      onTap: _togglePeek,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Obscured text silhouette (for height stability)
          Opacity(
            opacity: 0,
            child: Text(arabic, textDirection: TextDirection.rtl, style: baseStyle),
          ),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('Prek për të parë', style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemSelectionBar extends StatelessWidget {
  final int count; final VoidCallback onCancel; final Future<void> Function() onRemove; 
  const _MemSelectionBar({required this.count, required this.onCancel, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.close), tooltip: 'Anulo', onPressed: onCancel),
              Text('$count të zgjedhura', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Hiq', onPressed: onRemove),
            ],
          ),
        ),
      ),
    );
  }
}
