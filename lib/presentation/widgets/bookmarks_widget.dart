import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                const SizedBox(height: 16),
                Text(
                  'Gabim në ngarkimin e favoriteve',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  bookmarkProvider.error!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Nuk keni favorit të ruajtur',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Shtoni ajete në favorit duke klikuar ikonën e bookmark-ut',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with verse reference and actions
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Sure $surahNumber, Ajeti $verseNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
              const SizedBox(height: 8),
              Text(
                'Ruajtur më ${_formatDate(bookmark.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              
              // Note (if exists)
              if (bookmark.note != null && bookmark.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.dividerColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 16,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
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

