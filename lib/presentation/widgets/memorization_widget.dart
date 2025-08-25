import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/memorization_provider.dart';
import '../providers/quran_provider.dart';
import '../theme/theme.dart';

class MemorizationWidget extends StatefulWidget {
  const MemorizationWidget({super.key});

  @override
  State<MemorizationWidget> createState() => _MemorizationWidgetState();
}

class _MemorizationWidgetState extends State<MemorizationWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MemorizationProvider>().loadMemorizationList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MemorizationProvider, QuranProvider>(
      builder: (context, memorizationProvider, quranProvider, child) {
        if (memorizationProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (memorizationProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Gabim: ${memorizationProvider.error}',
                  style: const TextStyle(color: Colors.red),
                ),
                ElevatedButton(
                  onPressed: () {
                    memorizationProvider.clearError();
                    memorizationProvider.loadMemorizationList();
                  },
                  child: const Text('Provo përsëri'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(context.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMemorizationStats(memorizationProvider),
              SizedBox(height: context.spaceXl + context.spaceSm),
              _buildMemorizationList(memorizationProvider, quranProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemorizationStats(MemorizationProvider provider) {
  final stats = provider.getMemorizationStats();
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistikat e Memorizimit',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: context.spaceMd),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Ajete të memorizuara',
                    '${stats['memorized']}',
                    Icons.bookmark,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(width: context.spaceMd),
                Expanded(
                  child: _buildStatCard(
                    'Sure me memorizim',
                    '${stats['total']}',
                    Icons.book,
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(context.spaceMd),
      decoration: BoxDecoration(
  color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(context.radiusSmall.x),
  border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: context.spaceSm),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMemorizationList(MemorizationProvider memorizationProvider, QuranProvider quranProvider) {
    if (memorizationProvider.memorizationList.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(context.spaceXl),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.school, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                SizedBox(height: context.spaceLg),
                Text(
                  'Nuk keni ajete të memorizuara',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).textTheme.titleMedium?.color?.withValues(alpha: 0.75)),
                ),
                SizedBox(height: context.spaceSm),
                Text(
                  'Shtoni ajete në memorizim duke klikuar ikonën e memorizimit në çdo ajet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Group verses by surah
    final Map<int, List<String>> versesBySurah = {};
    for (final verseKey in memorizationProvider.memorizationList) {
      final parts = verseKey.split(':');
      if (parts.length == 2) {
        final surahNumber = int.tryParse(parts[0]);
        if (surahNumber != null) {
          versesBySurah[surahNumber] ??= [];
          versesBySurah[surahNumber]!.add(verseKey);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ajetet e Memorizuara',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: context.spaceMd),
        ...versesBySurah.entries.map((entry) {
          final surahNumber = entry.key;
          final verses = entry.value;
          
          return Card(
            margin: EdgeInsets.only(bottom: context.spaceSm),
            child: ExpansionTile(
        title: Text('Sure $surahNumber'),
        subtitle: Text('${verses.length} ajete të memorizuara'),
    children: verses.map<Widget>((verseKey) {
                final parts = verseKey.split(':');
                final verseNumber = parts.length == 2 ? parts[1] : '';
                
    return ListTile(
                  leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    child: Text(
                      verseNumber,
                      style: const TextStyle(
            color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text('Ajeti $verseNumber'),
                  trailing: IconButton(
          icon: Icon(Icons.remove_circle, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _showRemoveConfirmation(context, verseKey, memorizationProvider),
                  ),
                  onTap: () {
                    final sn = int.tryParse(parts[0]);
                    final vn = int.tryParse(verseNumber);
                    if (sn != null && vn != null) {
                      quranProvider.openSurahAtVerse(sn, vn);
                      context.read<AppStateProvider>().enqueueSnack('U hap Sure $sn, Ajeti $vn');
                    }
                  },
                );
  }).toList(),
            ),
          );
  }),
      ],
    );
  }

  void _showRemoveConfirmation(BuildContext context, String verseKey, MemorizationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hiq nga memorizimi'),
        content: Text('A jeni të sigurt që dëshironi të hiqni ajeti $verseKey nga lista e memorizimit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anulo'),
          ),
          TextButton(
            onPressed: () {
              provider.removeVerseFromMemorization(verseKey);
              Navigator.of(context).pop();
            },
            child: const Text('Hiq', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

