import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/thematic_index_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/quran_provider.dart';
import '../theme/theme.dart';
import '../widgets/quran_view_widget.dart';
import 'sheet_header.dart';

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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: provider.rootNodes.length,
                      itemBuilder: (context, index) {
                        final node = provider.rootNodes[index];
                        return _ThemeNodeCard(node: node, provider: provider);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubthemeItem(BuildContext context, ThematicNode subNode) {
    final verses = subNode.verseRefs;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 12),
      title: Text(subNode.label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        '${verses.length} ajete: ${verses.take(3).join(", ")}${verses.length > 3 ? "..." : ""}',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => _showVersesList(context, subNode.label, verses),
    );
  }

  void _showVersesList(BuildContext context, String subthemeName, List<dynamic> verses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => BottomSheetWrapper(
        padding: EdgeInsets.only(
          left: context.spaceLg,
          right: context.spaceLg,
          top: context.spaceSm,
          bottom: MediaQuery.of(context).viewInsets.bottom + context.spaceLg,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              SheetHeader(
                title: subthemeName,
                subtitle: '${verses.length} ajete',
                leadingIcon: Icons.topic,
                onClose: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: verses.length,
                  separatorBuilder: (_, __) => SizedBox(height: context.spaceXs),
                  itemBuilder: (context, index) {
                    final verseRef = verses[index] as String;
                    return Card(
                      child: ListTile(
                        title: Text(
                          verseRef,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          _getVerseDescription(verseRef),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
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
    // Supports formats: "2:255" or "37:168-170" (hyphen or en dash)
  final parts = verseRef.trim().split(':');
    if (parts.length == 2) {
      final surahNumber = int.tryParse(parts[0]);
      final versePart = parts[1];
      final rangeSep = versePart.contains('–') ? '–' : '-';
      if (versePart.contains(rangeSep)) {
        final range = versePart.split(rangeSep);
        final start = int.tryParse(range[0]);
        final end = int.tryParse(range[1]);
        if (surahNumber != null && start != null && end != null) {
          return 'Surja $surahNumber, Ajetet $start–$end';
        }
      } else {
        final verseNumber = int.tryParse(versePart);
        if (surahNumber != null && verseNumber != null) {
          return 'Surja $surahNumber, Ajeti $verseNumber';
        }
      }
    }
    return verseRef;
  }

  void _navigateToVerse(BuildContext context, String verseRef) {
    // Parse verse reference and navigate to the specific verse or range start
  final parts = verseRef.trim().split(':');
    if (parts.length != 2) return;
    final surahNumber = int.tryParse(parts[0]);
    if (surahNumber == null) return;
    final versePart = parts[1];
    final rangeSep = versePart.contains('–') ? '–' : '-';
    int? startVerse;
    if (versePart.contains(rangeSep)) {
      final range = versePart.split(rangeSep);
      startVerse = int.tryParse(range[0]);
    } else {
      startVerse = int.tryParse(versePart);
    }
    if (startVerse == null) return;
    // Use QuranProvider to open surah at verse
    final q = context.read<QuranProvider>();
    q.openSurahAtVerse(surahNumber, startVerse);
    _openQuranStandalone(context);
  }

  void _openQuranStandalone(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Kurani')),
          body: const Padding(
            padding: EdgeInsets.only(bottom: 0),
            child: QuranViewWrapper(),
          ),
        ),
      ),
    );
  }
}

class _ThemeNodeCard extends StatelessWidget {
  final ThematicNode node;
  final ThematicIndexProvider provider;
  const _ThemeNodeCard({required this.node, required this.provider});
  @override
  Widget build(BuildContext context) {
    final expanded = provider.isThemeExpanded(node.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            title: Text(node.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${node.children.isEmpty ? '...' : node.children.length} nën-tema'),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () async => provider.toggleThemeExpansion(node.id),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (node.children.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Align(alignment: Alignment.centerLeft, child: SizedBox(height:16,width:16, child: CircularProgressIndicator(strokeWidth:2))),
              )
            else SizedBox(
              // Constrain height to avoid unbounded expansion; approximate item height ~72
              height: (node.children.length * 72).clamp(0, 400).toDouble(),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: node.children.length,
                itemBuilder: (ctx, i) => _ThemeSubthemeTile(subNode: node.children[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeSubthemeTile extends StatelessWidget {
  final ThematicNode subNode;
  const _ThemeSubthemeTile({required this.subNode});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 12),
      title: Text(subNode.label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        '${subNode.verseRefs.length} ajete: ${subNode.verseRefs.take(3).join(", ")}${subNode.verseRefs.length > 3 ? "..." : ""}',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => BottomSheetWrapper(
          padding: EdgeInsets.only(
            left: context.spaceLg,
            right: context.spaceLg,
            top: context.spaceSm,
            bottom: MediaQuery.of(context).viewInsets.bottom + context.spaceLg,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                SheetHeader(
                  title: subNode.label,
                  subtitle: '${subNode.verseRefs.length} ajete',
                  leadingIcon: Icons.topic,
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: subNode.verseRefs.length,
                    separatorBuilder: (_, __) => SizedBox(height: context.spaceXs),
                    itemBuilder: (c, i) {
                      final ref = subNode.verseRefs[i];
                      return Card(
                        child: ListTile(
                          title: Text(ref, style: Theme.of(context).textTheme.titleMedium),
                          subtitle: Text(
                            _describeRef(ref),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                ),
                          ),
                          trailing: const Icon(Icons.open_in_new, size: 16),
                          onTap: () {
                            Navigator.pop(context);
                            _openRef(context, ref);
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
      ),
    );
  }

  String _describeRef(String verseRef) {
  final parts = verseRef.trim().split(':');
    if (parts.length == 2) {
      final surahNumber = int.tryParse(parts[0]);
      final versePart = parts[1];
      final rangeSep = versePart.contains('–') ? '–' : '-';
      if (versePart.contains(rangeSep)) {
        final range = versePart.split(rangeSep);
        final start = int.tryParse(range[0]);
        final end = int.tryParse(range[1]);
        if (surahNumber != null && start != null && end != null) {
          return 'Surja $surahNumber, Ajetet $start–$end';
        }
      } else {
        final verseNumber = int.tryParse(versePart);
        if (surahNumber != null && verseNumber != null) {
          return 'Surja $surahNumber, Ajeti $verseNumber';
        }
      }
    }
    return verseRef;
  }

  void _openRef(BuildContext context, String verseRef) {
    final parts = verseRef.split(':');
    if (parts.length != 2) return;
    final surahNumber = int.tryParse(parts[0]);
    if (surahNumber == null) return;
    final versePart = parts[1];
    final rangeSep = versePart.contains('–') ? '–' : '-';
    int? startVerse;
    if (versePart.contains(rangeSep)) {
      final range = versePart.split(rangeSep);
      startVerse = int.tryParse(range[0]);
    } else {
      startVerse = int.tryParse(versePart);
    }
    if (startVerse == null) return;
    final q = context.read<QuranProvider>();
    q.openSurahAtVerse(surahNumber, startVerse);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Kurani')),
          body: const QuranViewWrapper(),
        ),
      ),
    );
  }
}

// A thin wrapper to embed QuranViewWidget on a standalone page.
class QuranViewWrapper extends StatelessWidget {
  const QuranViewWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return const QuranViewWidget();
  }
}
