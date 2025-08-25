/// Central registry of persistence schema versions to avoid scattering string keys.
/// When bumping a version, add a brief comment on migration intent.
class PersistenceVersions {
  PersistenceVersions._();

  // Memorization structured list (verses_v1). Next: v2 maybe adds per-verse metadata (lastReviewed).
  static const int memorization = 1;

  // Favorites / bookmarks planned v2 (e.g., add category / label). Currently only base fields.
  static const int favorites = 1; // will become 2 when extra metadata introduced.

  // Notes tagging index (future) - starting at 1 when tag search index materializes.
  static const int notesTagsIndex = 0; // 0 => not yet created.

  // Reading progress model (current simple map) - plan v2 for streak / last session length.
  static const int readingProgress = 1;

  // Export bundle schema version (mirrors DataExportService.exportVersion). v2 adds audio & reading progress enrichment fields.
  static const int exportBundle = 2;
}
