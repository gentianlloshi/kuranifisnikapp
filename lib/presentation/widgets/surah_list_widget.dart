import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quran_provider.dart';
import '../providers/audio_provider.dart';
import '../../domain/entities/surah.dart';

class SurahListWidget extends StatelessWidget {
  const SurahListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<QuranProvider>(
      builder: (context, quranProvider, child) {
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

        final surahs = quranProvider.surahs;
        if (surahs.isEmpty) {
          return const Center(
            child: Text('Nuk u gjetën sure'),
          );
        }

        return ListView.builder(
          itemCount: surahs.length,
          itemBuilder: (context, index) {
            final surah = surahs[index];
            return SurahListItem(
              surah: surah,
              onTap: () => _onSurahTap(context, surah),
            );
          },
        );
      },
    );
  }

  void _onSurahTap(BuildContext context, Surah surah) {
    // Load the selected surah and switch to the reading tab
    _loadSurah(context, surah);
  }

  void _loadSurah(BuildContext context, Surah surah) {
    context.read<QuranProvider>().loadSurah(surah.number);
  // Removed tab animation: in the current layout the list and reader share the same view
  // and calling DefaultTabController here caused an exception when no controller was present.
  }
}

class SurahListItem extends StatelessWidget {
  final Surah surah;
  final VoidCallback onTap;

  const SurahListItem({
    super.key,
    required this.surah,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.primaryColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              surah.number.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.nameTranslation,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    surah.nameTransliteration,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              surah.nameArabic,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'AmiriQuran',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Icon(
              surah.revelation == 'Mekke' ? Icons.location_city : Icons.location_on,
              size: 16,
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              '${surah.revelation} • ${surah.versesCount} ajete',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _playSurah(context, surah),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _playSurah(BuildContext context, Surah surah) {
    context.read<AudioProvider>().playSurah(surah.verses);
  }
}

