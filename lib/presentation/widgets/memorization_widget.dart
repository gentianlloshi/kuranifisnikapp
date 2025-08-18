import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/memorization_provider.dart';
import '../providers/quran_provider.dart';

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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMemorizationStats(memorizationProvider),
              const SizedBox(height: 24),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistikat e Memorizimit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Ajete të memorizuara',
                    '${stats['memorized']}',
                    Icons.bookmark,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Sure me memorizim',
                    '${stats['total']}',
                    Icons.book,
                    Colors.blue,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
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
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMemorizationList(MemorizationProvider memorizationProvider, QuranProvider quranProvider) {
    if (memorizationProvider.memorizationList.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.school, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Nuk keni ajete të memorizuara',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Shtoni ajete në memorizim duke klikuar ikonën e memorizimit në çdo ajet.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
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
        const Text(
          'Ajetet e Memorizuara',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...versesBySurah.entries.map((entry) {
          final surahNumber = entry.key;
          final verses = entry.value;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text('Sure $surahNumber'),
              subtitle: Text('${verses.length} ajete të memorizuara'),
              children: verses.map((verseKey) {
                final parts = verseKey.split(':');
                final verseNumber = parts.length == 2 ? parts[1] : '';
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.2),
                    child: Text(
                      verseNumber,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text('Ajeti $verseNumber'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _showRemoveConfirmation(context, verseKey, memorizationProvider),
                  ),
                  onTap: () {
                    final sn = int.tryParse(parts[0]);
                    final vn = int.tryParse(verseNumber);
                    if (sn != null && vn != null) {
                      quranProvider.openSurahAtVerse(sn, vn);
                      // switch to Quran tab by popping until home uses tab index? Simpler: show snackbar
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('U hap Sure $sn, Ajeti $vn')));
                    }
                  },
                );
              }).toList(),
            ),
          );
        }).toList(),
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

