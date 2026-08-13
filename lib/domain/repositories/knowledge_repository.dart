import 'package:philosophyy/data/content/knowledge_base.dart';

/// Supplies the corpus.
///
/// The interface is one method because the corpus is loaded whole. That is a
/// deliberate constraint rather than an oversight: it keeps every screen's data
/// access synchronous once loading has finished, which removes per-screen
/// loading states from most of the product. If the corpus later has to be
/// paged, the change is confined to implementations of this interface and the
/// providers that expose it.
abstract interface class KnowledgeRepository {
  /// Loads and validates the corpus.
  ///
  /// Throws a content exception when a record cannot be read, and an integrity
  /// exception when the corpus is internally inconsistent.
  Future<KnowledgeBase> load();
}
