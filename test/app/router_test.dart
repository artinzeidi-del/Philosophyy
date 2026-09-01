import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// Checks that every link the app can generate is a link the app can follow.
///
/// [EntityRef.route] builds paths from [EntityKind.routeSegment], and the router
/// registers its routes from the same enum. Nothing stops the two drifting apart
/// if a kind is added to one and not the other, and the failure mode is a reader
/// tapping something and landing on the not-found screen — invisible to the
/// compiler and to every other test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  group('Route coverage', () {
    test('every entity in the corpus is of a routable kind', () {
      final routable = AppRouter.articleKinds.toSet();
      for (final entity in corpus.allEntities) {
        expect(
          routable.contains(entity.ref.kind),
          isTrue,
          reason:
              '${entity.ref} is in the corpus and shown in lists, but '
              '${entity.ref.kind.id} has no article route, so tapping it '
              'would lead nowhere',
        );
      }
    });

    test('every routable kind has entities to show', () {
      // A registered route with nothing behind it means a section of the
      // product that can only ever render an empty screen.
      for (final kind in AppRouter.articleKinds) {
        final count = corpus.allEntities
            .where((entity) => entity.ref.kind == kind)
            .length;
        expect(
          count,
          greaterThan(0),
          reason: 'the ${kind.id} route has no content behind it',
        );
      }
    });

    test('generated routes match the pattern the router registers', () {
      for (final entity in corpus.allEntities) {
        final route = entity.ref.route;
        expect(
          route,
          '/${entity.ref.kind.routeSegment}/${entity.ref.id}',
          reason: 'the route for ${entity.ref} is not what the router expects',
        );
        expect(route.split('/').length, 3, reason: 'unexpected path depth');
      }
    });

    test('route segments are unique across kinds', () {
      // Two kinds sharing a segment would make one of them unreachable.
      final segments = EntityKind.values
          .map((kind) => kind.routeSegment)
          .toList();
      expect(segments.toSet().length, segments.length);
    });

    test('identifiers do not need escaping to appear in a path', () {
      // Identifiers are authored by hand. One containing a slash or a space
      // would silently produce a route that cannot be matched.
      final safe = RegExp(r'^[a-z0-9-]+$');
      for (final entity in corpus.allEntities) {
        expect(
          safe.hasMatch(entity.id),
          isTrue,
          reason:
              '"${entity.id}" is not URL-safe; identifiers must be lowercase '
              'with hyphens so they can be used in routes and deep links',
        );
      }
    });
  });

  group('Kinds deliberately excluded from routing', () {
    test('are shown inside other articles rather than being unreachable', () {
      final routable = AppRouter.articleKinds.toSet();
      final excluded = EntityKind.values
          .where((kind) => !routable.contains(kind))
          .toSet();

      // This is the current editorial decision: quotations and sources appear
      // within an article rather than on pages of their own. The assertion
      // exists so that adding a kind forces that decision to be made again
      // rather than defaulting to "unreachable" — and it worked: arguments
      // were on this list until they grew articles of their own, at which
      // point leaving them unroutable meant a reader could read about the
      // ontological argument on Anselm's page and had nowhere to follow it to.
      //
      // Quotations and sources stay off it for a reason that still holds. A
      // quotation is a sentence, and a page whose whole content is one sentence
      // plus its provenance is a worse home for it than the entry it
      // illustrates; a source is a bibliographic record, and its page would be
      // the citation the reader has already been shown.
      expect(excluded, <EntityKind>{EntityKind.quote, EntityKind.source});
    });
  });
}
