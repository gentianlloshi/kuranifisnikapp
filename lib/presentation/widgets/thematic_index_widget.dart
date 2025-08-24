import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/thematic_index_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/quran_provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/bookmark_provider.dart';
import '../theme/theme.dart';
import '../widgets/quran_view_widget.dart';
import 'sheet_header.dart';
import 'thematic_index_utils.dart';

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
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Gabim në ngarkimin e indeksit tematik', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(provider.error!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => provider.loadThematicIndex(), child: const Text('Provo Përsëri')),
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
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Text('Indeksi Tematik', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  const SizedBox(height: 8),
                  Text('Gjej ajete sipas temave dhe koncepteve', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('Nuk u gjetën tema', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Text('Provo një term tjetër kërkimi', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: provider.rootNodes.length,
                      itemBuilder: (context, index) {
                        final node = provider.rootNodes[index];
                        return _ThemeNodeCard(node: node, provider: provider, searchQuery: provider.searchQuery);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeNodeCard extends StatelessWidget {
  final ThematicNode node;
  final ThematicIndexProvider provider;
  final String searchQuery;
  const _ThemeNodeCard({required this.node, required this.provider, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final bool expanded = provider.isThemeExpanded(node.id) || (searchQuery.trim().isNotEmpty);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(iconForThemeLabel(node.label), color: Theme.of(context).colorScheme.primary, size: 18),
            ),
            title: searchQuery.trim().isEmpty
                ? Text(
                    node.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : _HighlightedText(
                    text: node.label,
                    query: searchQuery,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
            subtitle: Text('${node.children.isEmpty ? '...' : node.children.length} nën-tema • ${provider.totalVersesForTheme(node.id)} ajete'),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => provider.toggleThemeExpansion(node.id),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (node.children.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              SizedBox(
                height: (MediaQuery.of(context).size.height * 0.4).clamp(200.0, 500.0),
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
    final query = context.read<ThematicIndexProvider>().searchQuery;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 12),
      title: (query.trim().isEmpty)
          ? Text(
              subNode.label,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
            )
          : _HighlightedText(
              text: subNode.label,
              query: query,
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
            ),
      subtitle: Text(
        '${subNode.verseRefs.length} ajete: ${subNode.verseRefs.take(3).join(", ")}${subNode.verseRefs.length > 3 ? "..." : ""}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => _openSubthemeSheet(context, subNode),
    );
  }

  void _openSubthemeSheet(BuildContext context, ThematicNode sub) {
    showModalBottomSheet(
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
                title: sub.label,
                subtitle: '${sub.verseRefs.length} ajete',
                leadingIcon: Icons.topic,
                onClose: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: sub.verseRefs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text('Kjo nën-temë nuk ka ajete të listuara.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: sub.verseRefs.length,
                        separatorBuilder: (_, __) => SizedBox(height: context.spaceXs),
                        itemBuilder: (c, i) {
                          final ref = sub.verseRefs[i];
                          final preview = _buildPreview(context, ref);
                          final title = _describeRef(ref);
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _openRef(context, ref);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                                        Icon(Icons.open_in_new, size: 16, color: Theme.of(context).colorScheme.primary),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      preview ?? 'Parapamje e shpejtë jo e disponueshme',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: preview == null ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8) : null,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _copyRef(context, ref),
                                          icon: const Icon(Icons.copy, size: 16),
                                          label: const Text('Kopjo'),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () => _favoriteRef(context, ref),
                                          icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                                          label: const Text('Ruaj'),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _openRef(context, ref);
                                          },
                                          child: const Text('Hap'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
  int? endVerse;
  if (versePart.contains(rangeSep)) {
    final range = versePart.split(rangeSep);
    startVerse = int.tryParse(range[0]);
    endVerse = int.tryParse(range[1]);
  } else {
    startVerse = int.tryParse(versePart);
  }
  if (startVerse == null) return;
  final q = context.read<QuranProvider>();
  if (endVerse != null && endVerse >= startVerse) {
    q.openSurahAtRange(surahNumber, startVerse, endVerse);
  } else {
    q.openSurahAtVerse(surahNumber, startVerse);
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text('Kurani', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700)),
        ),
        body: const QuranViewWrapper(),
      ),
    ),
  );
}

String? _buildPreview(BuildContext context, String ref) {
  final q = context.read<QuranProvider>();
  return buildRefPreview(ref, resolveTextForRef: (r) {
    final v = q.resolveVerseByRef(r);
    return v == null ? null : (v.textTranslation ?? v.textArabic);
  });
}

void _copyRef(BuildContext context, String ref) {
  final v = context.read<QuranProvider>().resolveVerseByRef(ref);
  final text = v?.textTranslation ?? v?.textArabic ?? ref;
  Clipboard.setData(ClipboardData(text: '$text\n($ref)'));
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('U kopjua')));
}

void _favoriteRef(BuildContext context, String ref) {
  final v = context.read<QuranProvider>().resolveVerseByRef(ref);
  if (v == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Versi do të hapet për t\'u ruajtur')));
    return;
  }
  context.read<BookmarkProvider>().toggleBookmark(v.verseKey);
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('U përditësuan të preferuarat')));
}

class QuranViewWrapper extends StatelessWidget {
  const QuranViewWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return const QuranViewWidget();
  }
}

/// Renders [text] with [query] occurrences highlighted case-insensitively.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  const _HighlightedText({required this.text, required this.query, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        );
    final highlight = base?.copyWith(
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
      fontWeight: FontWeight.w600,
    );
    if (query.trim().isEmpty) return Text(text, style: base);
    final q = query.toLowerCase();
    final t = text;
    final lower = t.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(q, start);
      if (idx < 0) {
        spans.add(TextSpan(text: t.substring(start), style: base));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: t.substring(start, idx), style: base));
      }
      spans.add(TextSpan(text: t.substring(idx, idx + q.length), style: highlight));
      start = idx + q.length;
      if (start >= t.length) break;
    }
    return RichText(text: TextSpan(children: spans));
  }
}
