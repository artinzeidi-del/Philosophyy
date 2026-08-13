import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';

/// What every addressable article in the product has in common.
///
/// Search, the knowledge graph, recommendation and the "surprise me" discovery
/// mode all need to treat a philosopher, a concept and a work uniformly. This
/// interface is what lets them do that without a chain of type checks, and it
/// is deliberately small: anything specific to one kind of entity belongs on
/// that class, not here.
abstract interface class KnowledgeEntity {
  /// Identifier, unique within this entity's kind.
  String get id;

  /// A typed pointer to this entity.
  EntityRef get ref;

  /// The display name or title.
  LocalizedText get name;

  /// A single sentence a newcomer can understand, used in cards, search
  /// results and previews. Every entity must have one — an entry that cannot
  /// be summarised in a sentence has not been thought through.
  LocalizedText get oneLine;

  /// The traditions this entity belongs to.
  Set<Tradition> get traditions;

  /// The branches of philosophy this entity falls under.
  Set<PhilosophyBranch> get branches;

  /// The authored prose.
  Article get article;

  /// Sources for the entry as a whole, beyond those attached to individual
  /// sections.
  List<Citation> get citations;

  /// Every string that should be indexed for search, in every language.
  ///
  /// Implementations must include names in the original script and any
  /// transliteration, because a reader searching for `ابن‌سینا`, `Ibn Sina` and
  /// `Avicenna` is looking for the same person.
  Iterable<String> get searchableStrings;
}
