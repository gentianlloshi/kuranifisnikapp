import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/thematic_index_provider.dart';

class ThematicIndexWidget extends StatefulWidget {
  const ThematicIndexWidget({super.key});

  @override
  State<ThematicIndexWidget> createState() => _ThematicIndexWidgetState();
}

class _ThematicIndexWidgetState extends State<ThematicIndexWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ThematicIndexProvider>().loadThematicIndex();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThematicIndexProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Gabim në ngarkimin e indeksit tematik',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  provider.error!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadThematicIndex(),
                  child: const Text('Provo Përsëri'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Indeksi Tematik',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gjej ajete sipas temave dhe koncepteve',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Kërko në tema...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: provider.searchThemes,
              ),
            ),

            // Content
            Expanded(
              child: provider.filteredThemes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nuk u gjetën tema',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Provo një term tjetër kërkimi',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.filteredThemes.length,
                      itemBuilder: (context, index) {
                        final themeName = provider.filteredThemes[index];
                        final themeData = provider.thematicIndex[themeName];
                        if (themeData is Map<String, dynamic>) {
                          return _buildThemeCard(context, themeName, themeData, provider);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeCard(BuildContext context, String themeName, Map<String, dynamic> themeData, ThematicIndexProvider provider) {
  final subthemes = themeData['subthemes'] as Map<String, dynamic>? ?? {};
  final isExpanded = provider.isThemeExpanded(themeName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(
              themeName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text('${subthemes.length} nën-tema'),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => provider.toggleThemeExpansion(themeName),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            ...subthemes.entries.map((entry) => _buildSubthemeItem(
              context,
              entry.key,
              entry.value as List<dynamic>,
              provider,
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildSubthemeItem(
    BuildContext context,
    String subthemeName,
    List<dynamic> verses,
    ThematicIndexProvider provider,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      title: Text(
        subthemeName,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '${verses.length} ajete: ${verses.take(3).join(", ")}${verses.length > 3 ? "..." : ""}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => _showVersesList(context, subthemeName, verses),
    );
  }

  void _showVersesList(BuildContext context, String subthemeName, List<dynamic> verses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subthemeName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '${verses.length} ajete',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const Divider(),
              
              // Verses List
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: verses.length,
                  itemBuilder: (context, index) {
                    final verseRef = verses[index] as String;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          verseRef,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          _getVerseDescription(verseRef),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToVerse(context, verseRef);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getVerseDescription(String verseRef) {
    // Parse verse reference like "2:255" to get surah and verse
    final parts = verseRef.split(':');
    if (parts.length == 2) {
      final surahNumber = int.tryParse(parts[0]);
      final verseNumber = int.tryParse(parts[1]);
      
      if (surahNumber != null && verseNumber != null) {
        // You could load surah names from your data
        return 'Surja $surahNumber, Ajeti $verseNumber';
      }
    }
    return verseRef;
  }

  void _navigateToVerse(BuildContext context, String verseRef) {
    // Parse verse reference and navigate to the specific verse
    final parts = verseRef.split(':');
    if (parts.length == 2) {
      final surahNumber = int.tryParse(parts[0]);
      final verseNumber = int.tryParse(parts[1]);
      
      if (surahNumber != null && verseNumber != null) {
        // Navigate to QuranView with specific surah and verse
        // This would depend on your navigation setup
        Navigator.pushNamed(
          context,
          '/quran',
          arguments: {
            'surahNumber': surahNumber,
            'verseNumber': verseNumber,
          },
        );
      }
    }
  }
}
