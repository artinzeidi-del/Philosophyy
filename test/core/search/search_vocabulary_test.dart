import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/search/search_index.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';

/// Asserts that the words a reader will actually type find something.
///
/// ## Why this exists
///
/// Every other search test checks ranking: given that a query matches several
/// entries, does the right one come first. None of them could catch the defect
/// this file was written for, which is a query matching *nothing at all*.
///
/// A sweep of ordinary vocabulary found thirty-six such queries. Some were
/// honest — the corpus has no entry on Gettier cases, so an empty result is the
/// truth. But `tao` returned nothing while the app carries a concept, a school
/// and the Daodejing; `chuang tzu` returned nothing beside a full entry on
/// Zhuangzi; `dasein`, `ubermensch`, `ubuntu`, `intersectionality`, `satori`
/// and `absurdism` all returned nothing next to entries about exactly those
/// things. The entity was there. The name the reader knows it by was not on the
/// record, and an empty screen tells a reader the app has nothing — which is
/// the worst possible answer when it has an article.
///
/// So this is a canary list: terms whose subject the corpus genuinely covers,
/// each of which must return at least one entry or one glossary term. Adding a
/// romanisation, a coinage or a school's other name to this list is cheap;
/// discovering by accident that the app looks empty on Daoism is not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;
  late SearchIndex index;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
    index = SearchIndex.build(corpus);
  });

  /// Words a reader is likely to type, for subjects the corpus covers.
  ///
  /// Grouped only for readability. A term belongs here when the app has
  /// something real to show for it — never as a wish list.
  const vocabulary = <String, List<String>>{
    'alternative romanisations': <String>[
      'tao',
      'taoism',
      'tao te ching',
      'lao tzu',
      'chuang tzu',
      'mo tzu',
      'hsun tzu',
      'kongzi',
      'chan buddhism',
    ],
    'the Latin names of Islamic philosophers': <String>[
      'avicenna',
      'averroes',
      'algazel',
      'alhazen',
      'avempace',
      'abubacer',
      'rhazes',
    ],
    'coinages an entry is famous for': <String>[
      'dasein',
      'ubermensch',
      'noumenon',
      'thing-in-itself',
      'banality of evil',
      'veil of ignorance',
      'invisible hand',
      'double consciousness',
      'trolley problem',
      'categorical imperative',
    ],
    'names a school is usually called': <String>[
      'satori',
      'madhyamika',
      'mind-only',
      'advaita',
      'negritude',
      'kyoto school',
      'neo-confucianism',
    ],
    'terms with no entry of their own': <String>[
      'dukkha',
      'anatta',
      'anicca',
      'samsara',
      'nirvana',
      'moksha',
      'atman',
      'brahman',
      'bodhisattva',
      'karma',
      'dharma',
      'maya',
      'tawhid',
      'kalam',
      'falsafa',
      'qi',
      'yin',
      'junzi',
      'logos',
      'nous',
      'qualia',
      'solipsism',
      'alienation',
      'authenticity',
      'universals',
      'atomism',
      'structuralism',
      'postmodernism',
      'verificationism',
      'sense data',
      'deontology',
      'a priori',
    ],
    'ideas by the word most people use': <String>[
      'ubuntu',
      'intersectionality',
      'absurdism',
      'effective altruism',
      'scientific method',
      'wu wei',
      'epicureanism',
    ],
    'Persian, which is the language this is mainly for': <String>[
      'افلاطون',
      'ارسطو',
      'کانت',
      'نیچه',
      'مولوی',
      'ابن سینا',
      'سهروردی',
      'ملاصدرا',
      'خیام',
      'فارابی',
      'اگزیستانسیالیسم',
      'پدیدارشناسی',
      'رواقی',
      'عرفان',
      'کارما',
      'نیروانا',
    ],
  };

  for (final group in vocabulary.entries) {
    test('search finds something for ${group.key}', () {
      final silent = <String>[];
      for (final query in group.value) {
        final entities = index.search(query);
        final terms = corpus.glossaryMatching(query);
        if (entities.isEmpty && terms.isEmpty) silent.add(query);
      }
      expect(
        silent,
        isEmpty,
        reason:
            'these return an empty screen, which tells the reader the app has '
            'nothing on the subject:\n  ${silent.join('\n  ')}\n'
            'Fix by adding the word to the entity\'s alsoKnownAs, or by '
            'giving it a glossary entry — not by working it into prose.',
      );
    });
  }
}
