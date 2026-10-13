import '../models/vocabulary.dart';

/// Stable introductory topics. Their published IDs are retained by the importer.
class ContentAccess {
  ContentAccess(Catalog catalog) {
    for (final level in levels) {
      for (final exam in <String?>[null, 'goethe', 'telc']) {
        final topics = catalog.collections(level, exam: exam);
        if (topics.isNotEmpty) {
          if (exam == null) sampleLessonIds[level] = topics.first.id;
          freeLessonIds.add(topics.first.id);
          freeWordIds.addAll(topics.first.wordIds);
        }
      }
    }
  }
  final freeLessonIds = <String>{}, freeWordIds = <String>{};
  final sampleLessonIds = <String, String>{};
}
