import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme.dart';
import '../providers/bookmark_provider.dart';
import '../providers/quran_provider.dart';
import '../../domain/entities/bookmark.dart';

class BookmarksWidget extends StatelessWidget {
  const BookmarksWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<BookmarkProvider, QuranProvider>(
      builder: (context, bookmarkProvider, quranProvider, child) {
        if (bookmarkProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (bookmarkProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                SizedBox(height: context.spaceLg),
                Text(
                  'Gabim në ngarkimin e favoriteve',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: context.spaceSm),
                Text(
                  bookmarkProvider.error!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.spaceLg),
                ElevatedButton(
                  onPressed: () => bookmarkProvider.loadBookmarks(),
                  child: const Text('Provo përsëri'),
                ),
              ],
            ),
          );
        }

        final bookmarks = bookmarkProvider.bookmarks;
        
        if (bookmarks.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(context.spaceLg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: Theme.of(context).colorScheme.outline.withOpacity(0.6)),
                  SizedBox(height: context.spaceLg),
                  Text(
                    'Nuk keni favorit të ruajtur',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  SizedBox(height: context.spaceSm),
                  Text(
                    'Shtoni ajete në favorit duke klikuar ikonën e bookmark-ut',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(context.spaceLg),
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return BookmarkItem(
              bookmark: bookmark,
              onTap: () => _navigateToVerse(context, bookmark, quranProvider),
              onDelete: () => _deleteBookmark(context, bookmark, bookmarkProvider),
            );
          },
        );
      },
    );
  }

  void _navigateToVerse(BuildContext context, Bookmark bookmark, QuranProvider quranProvider) {
    final parts = bookmark.verseKey.split(':');
    if (parts.length == 2) {
      final surahNumber = int.tryParse(parts[0]);
      if (surahNumber != null) {
        quranProvider.loadSurah(surahNumber);
        DefaultTabController.of(context).animateTo(1);
        // TODO: Scroll to the specific verse
      }
    }
  }

  void _deleteBookmark(BuildContext context, Bookmark bookmark, BookmarkProvider bookmarkProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fshi favorit'),
        content: const Text('Jeni të sigurt që doni të fshini këtë favorit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anulo'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              bookmarkProvider.toggleBookmark(bookmark.verseKey);
            },
            child: const Text('Fshi'),
          ),
        ],
      ),
    );
  }
}

class BookmarkItem extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const BookmarkItem({
    super.key,
    required this.bookmark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = bookmark.verseKey.split(':');
    final surahNumber = parts.isNotEmpty ? parts[0] : '';
    final verseNumber = parts.length > 1 ? parts[1] : '';
    
    final scheme = theme.colorScheme;
    final bool dark = scheme.brightness == Brightness.dark;
    return Card(
      margin: EdgeInsets.only(bottom: context.spaceMd),
      color: scheme.surfaceElevated(1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(context.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with verse reference and actions
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.spaceSm, vertical: context.spaceXs),
                    decoration: ShapeDecoration(
                      color: scheme.primary.withOpacity(dark ? 0.20 : 0.10),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      'Sure $surahNumber, Ajeti $verseNumber',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimaryContainer,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
              
              // Bookmark date
              SizedBox(height: context.spaceSm),
              Text(
                'Ruajtur më ${_formatDate(bookmark.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              
              // Note (if exists)
              if (bookmark.note != null && bookmark.note!.isNotEmpty) ...[
                SizedBox(height: context.spaceSm),
                Container(
                  padding: EdgeInsets.all(context.spaceSm),
                  decoration: BoxDecoration(
                    // Unified elevated tonal background for note container across themes.
                    // We start from an elevated surface (level 2 in dark for extra separation, 1 in light)
                    // then softly tint with primary for contextual accent.
                    color: () {
                      final base = scheme.surfaceElevated(dark ? 2 : 1);
                      final tintOpacity = dark ? 0.08 : 0.05;
                      return Color.alphaBlend(scheme.primary.withOpacity(tintOpacity), base);
                    }(),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 16,
                        color: scheme.onSurfaceVariant.withOpacity(0.75),
                      ),
                      SizedBox(width: context.spaceSm),
                      Expanded(
                        child: Text(
                          bookmark.note!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'sot';
    } else if (difference.inDays == 1) {
      return 'dje';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ditë më parë';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

