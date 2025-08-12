import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quran_provider.dart';
import '../providers/app_state_provider.dart';
import '../../domain/entities/verse.dart';

class SearchWidget extends StatefulWidget {
  const SearchWidget({super.key});

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTranslation = 'sq_ahmeti';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<QuranProvider, AppStateProvider>(
      builder: (context, quranProvider, appState, child) {
        return Column(
          children: [
            // Search input and filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Kërko në Kuran...',
                      prefixIcon: const Icon(Icons.search),
                      suffix: Consumer<QuranProvider>(
                        builder: (ctx, qp, _) => qp.isBuildingIndex
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const SizedBox.shrink(),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                quranProvider.clearSearch();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (query) {
                      setState(() {}); // Update clear icon state
                      if (query.trim().isEmpty) {
                        quranProvider.clearSearch();
                      } else {
                        quranProvider.searchVersesDebounced(query.trim());
                      }
                    },
                    onSubmitted: (query) => quranProvider.searchVerses(query.trim()),
                  ),
                  const SizedBox(height: 12),
                  
                  // Translation filter
                  Row(
                    children: [
                      const Text('Përkthimi: '),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedTranslation,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'sq_ahmeti', child: Text('Ahmeti')),
                            DropdownMenuItem(value: 'sq_mehdiu', child: Text('Mehdiu')),
                            DropdownMenuItem(value: 'sq_nahi', child: Text('Nahi')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedTranslation = value;
                              });
                              if (_searchController.text.trim().isNotEmpty) {
                                _performSearch(quranProvider, _searchController.text);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Search results
            Expanded(
              child: _buildSearchResults(quranProvider, appState),
            ),
          ],
        );
      },
    );
  }

  void _performSearch(QuranProvider quranProvider, String query) {
    quranProvider.searchVerses(query);
  }

  Widget _buildSearchResults(QuranProvider quranProvider, AppStateProvider appState) {
    // isSearching not implemented; rely on isLoading
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
              'Gabim në kërkim',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              quranProvider.error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final searchResults = quranProvider.searchResults;
    
    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Shkruani një fjalë për të kërkuar',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nuk u gjetën rezultate',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final verse = searchResults[index];
        return SearchResultItem(
          verse: verse,
          searchQuery: _searchController.text,
          settings: appState.settings,
        );
      },
    );
  }
}

class SearchResultItem extends StatelessWidget {
  final Verse verse;
  final String searchQuery;
  final dynamic settings; // AppSettings

  const SearchResultItem({
    super.key,
    required this.verse,
    required this.searchQuery,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final isDark = theme.brightness == Brightness.dark;
  return Card(
    color: isDark
      ? theme.colorScheme.surface.withOpacity(0.85)
      : Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.03), theme.colorScheme.surface),
    elevation: isDark ? 0 : 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToVerse(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verse reference
              Row(
                children: [
                  _RefChip('${verse.surahNumber}:${verse.number}'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.bookmark_border),
                    onPressed: () {
                      // TODO: Implement bookmark functionality
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Arabic text (if enabled)
              if (settings.showArabic)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    verse.textArabic,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: (settings.fontSizeArabic - 4).toDouble(),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              
              // Translation with highlighting
              if (settings.showTranslation && verse.textTranslation != null)
                RichText(
                  text: _buildHighlightedText(
                    verse.textTranslation!,
                    searchQuery,
                    theme,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _buildHighlightedText(String text, String query, ThemeData theme) {
    if (query.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Lora',
          fontSize: (settings.fontSizeTranslation - 2).toDouble(),
          height: 1.4,
        ),
      );
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    
    int start = 0;
    int index = lowerText.indexOf(lowerQuery);
    
    while (index != -1) {
      // Add text before the match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: (settings.fontSizeTranslation - 2).toDouble(),
            height: 1.4,
          ),
        ));
      }
      
      // Add highlighted match (Option A refined: soft yellow background, bold dark text)
      final highlightBg = theme.brightness == Brightness.dark
          ? theme.colorScheme.secondaryContainer.withOpacity(0.35)
          : const Color(0xFFFFF59D); // light yellow 200-ish
      final highlightColor = theme.brightness == Brightness.dark
          ? theme.colorScheme.onSecondaryContainer
          : Colors.black;
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          fontFamily: 'Lora',
          fontSize: (settings.fontSizeTranslation - 2).toDouble(),
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: highlightColor,
          backgroundColor: highlightBg,
        ),
      ));
      
      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }
    
    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(
          fontFamily: 'Lora',
          fontSize: (settings.fontSizeTranslation - 2).toDouble(),
          height: 1.4,
        ),
      ));
    }
    
    return TextSpan(children: spans);
  }

  void _navigateToVerse(BuildContext context) {
    final q = context.read<QuranProvider>();
    q.openSurahAtVerse(verse.surahNumber, verse.number);
    // If there's a higher-level tab controller, rely on parent logic (avoid crashing if none)
    try {
      final controller = DefaultTabController.maybeOf(context);
      controller?.animateTo(0); // ensure we are on reading tab (adjust index if needed)
    } catch (_) {/* ignore */}
  }
}

class _RefChip extends StatelessWidget {
  final String label;
  const _RefChip(this.label);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0,2),
          )
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

