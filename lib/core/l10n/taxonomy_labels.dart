import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';

/// Display names for the closed vocabularies of the domain model.
///
/// ## Why these are not in the ARB files
///
/// The ARB files hold interface chrome — buttons, labels, error messages. These
/// are different: "scholars disagree" and "اختلاف پژوهشی" are technical
/// vocabulary, and the Persian is a term of art with an established form rather
/// than a translation choice. Keeping them next to the enums they name means a
/// new relation type cannot be added without its Persian name, which is exactly
/// the constraint a bilingual product needs.
///
/// ## Why traditions and branches are *not* here
///
/// They used to be, as two exhaustive switches over `Tradition` and
/// `PhilosophyBranch`. That made the world's philosophical vocabulary a closed
/// Dart enum: Korean, Tibetan, Ethiopian and every Indigenous tradition were
/// unnameable without a code change. They now live in `assets/content/`
/// `taxonomy.json` and are resolved through [Taxonomy.nameOf], which carries
/// the same bilingual guarantee — a term without both names fails the taxonomy
/// test — without the ceiling. See ADR-017.
///
/// The translations follow standard Persian philosophical usage. Where Persian
/// scholarship uses more than one term, the more widely taught one is used and
/// the alternative is not silently dropped but recorded in the glossary in
/// `docs/GLOSSARY.md`.
abstract final class TaxonomyLabels {
  /// How a relation reads from the subject's side, e.g. "influenced".
  static LocalizedText relationForward(RelationType type) => switch (type) {
    RelationType.influenced => const LocalizedText(
      en: 'influenced',
      fa: 'اثر گذاشت بر',
    ),
    RelationType.criticized => const LocalizedText(
      en: 'criticised',
      fa: 'نقد کرد',
    ),
    RelationType.defended => const LocalizedText(
      en: 'defended',
      fa: 'دفاع کرد از',
    ),
    RelationType.opposed => const LocalizedText(en: 'opposed', fa: 'در برابر'),
    RelationType.developed => const LocalizedText(
      en: 'developed',
      fa: 'بسط داد',
    ),
    RelationType.inspired => const LocalizedText(
      en: 'inspired',
      fa: 'الهام‌بخش بود برای',
    ),
    RelationType.respondedTo => const LocalizedText(
      en: 'responded to',
      fa: 'پاسخ داد به',
    ),
    RelationType.wrote => const LocalizedText(en: 'wrote', fa: 'نوشت'),
    RelationType.belongsTo => const LocalizedText(
      en: 'belongs to',
      fa: 'تعلق دارد به',
    ),
    RelationType.taught => const LocalizedText(
      en: 'taught',
      fa: 'آموزش داد به',
    ),
    RelationType.founded => const LocalizedText(
      en: 'founded',
      fa: 'بنیان گذاشت',
    ),
    RelationType.succeeded => const LocalizedText(
      en: 'succeeded',
      fa: 'جانشین شد',
    ),
    RelationType.commentedOn => const LocalizedText(
      en: 'wrote a commentary on',
      fa: 'شرح نوشت بر',
    ),
    RelationType.translated => const LocalizedText(
      en: 'translated',
      fa: 'ترجمه کرد',
    ),
    RelationType.preserved => const LocalizedText(
      en: 'preserved',
      fa: 'حفظ کرد',
    ),
    RelationType.synthesized => const LocalizedText(
      en: 'synthesised',
      fa: 'تلفیق کرد',
    ),
    RelationType.reinterpreted => const LocalizedText(
      en: 'reinterpreted',
      fa: 'بازتفسیر کرد',
    ),
    RelationType.anticipated => const LocalizedText(
      en: 'anticipated',
      fa: 'پیش‌بینی کرد',
    ),
    RelationType.presupposes => const LocalizedText(
      en: 'presupposes',
      fa: 'مستلزم پیش‌فرضِ',
    ),
    RelationType.entails => const LocalizedText(
      en: 'entails',
      fa: 'در پی دارد',
    ),
    RelationType.contradicts => const LocalizedText(
      en: 'contradicts',
      fa: 'در تناقض با',
    ),
    RelationType.generalizes => const LocalizedText(
      en: 'generalises',
      fa: 'تعمیم می‌دهد',
    ),
    RelationType.exemplifies => const LocalizedText(
      en: 'exemplifies',
      fa: 'نمونه‌ای است از',
    ),
    RelationType.attributedTo => const LocalizedText(
      en: 'attributed to',
      fa: 'منسوب به',
    ),
    RelationType.corresponded => const LocalizedText(
      en: 'corresponded with',
      fa: 'مکاتبه داشت با',
    ),
    RelationType.contemporaryOf => const LocalizedText(
      en: 'contemporary of',
      fa: 'هم‌روزگار با',
    ),
    RelationType.relatedTo => const LocalizedText(
      en: 'related to',
      fa: 'مرتبط با',
    ),
  };

  /// How a relation reads from the object's side, e.g. "influenced by".
  static LocalizedText relationInverse(RelationType type) => switch (type) {
    RelationType.influenced => const LocalizedText(
      en: 'influenced by',
      fa: 'متأثر از',
    ),
    RelationType.criticized => const LocalizedText(
      en: 'criticised by',
      fa: 'نقد شد توسط',
    ),
    RelationType.defended => const LocalizedText(
      en: 'defended by',
      fa: 'دفاع شد توسط',
    ),
    RelationType.opposed => const LocalizedText(en: 'opposed', fa: 'در برابر'),
    RelationType.developed => const LocalizedText(
      en: 'developed by',
      fa: 'بسط یافت توسط',
    ),
    RelationType.inspired => const LocalizedText(
      en: 'inspired by',
      fa: 'الهام گرفته از',
    ),
    RelationType.respondedTo => const LocalizedText(
      en: 'answered by',
      fa: 'پاسخ گرفت از',
    ),
    RelationType.wrote => const LocalizedText(en: 'written by', fa: 'نوشتهٔ'),
    RelationType.belongsTo => const LocalizedText(
      en: 'includes',
      fa: 'دربرگیرندهٔ',
    ),
    RelationType.taught => const LocalizedText(
      en: 'studied under',
      fa: 'شاگردِ',
    ),
    RelationType.founded => const LocalizedText(
      en: 'founded by',
      fa: 'بنیان‌گذاری شد توسط',
    ),
    RelationType.succeeded => const LocalizedText(
      en: 'was succeeded by',
      fa: 'جانشین او شد',
    ),
    RelationType.commentedOn => const LocalizedText(
      en: 'has a commentary by',
      fa: 'شرح دارد از',
    ),
    RelationType.translated => const LocalizedText(
      en: 'translated by',
      fa: 'ترجمه شد توسط',
    ),
    RelationType.preserved => const LocalizedText(
      en: 'preserved by',
      fa: 'حفظ شد توسط',
    ),
    RelationType.synthesized => const LocalizedText(
      en: 'synthesised by',
      fa: 'تلفیق شد توسط',
    ),
    RelationType.reinterpreted => const LocalizedText(
      en: 'reinterpreted by',
      fa: 'بازتفسیر شد توسط',
    ),
    RelationType.anticipated => const LocalizedText(
      en: 'anticipated by',
      fa: 'پیش‌بینی شد توسط',
    ),
    RelationType.presupposes => const LocalizedText(
      en: 'presupposed by',
      fa: 'پیش‌فرضِ',
    ),
    RelationType.entails => const LocalizedText(
      en: 'entailed by',
      fa: 'نتیجهٔ',
    ),
    RelationType.contradicts => const LocalizedText(
      en: 'contradicts',
      fa: 'در تناقض با',
    ),
    RelationType.generalizes => const LocalizedText(
      en: 'a special case of',
      fa: 'حالت خاصی از',
    ),
    RelationType.exemplifies => const LocalizedText(
      en: 'exemplified by',
      fa: 'نمونه دارد در',
    ),
    RelationType.attributedTo => const LocalizedText(
      en: 'has attributed work',
      fa: 'اثر منسوب دارد',
    ),
    RelationType.corresponded => const LocalizedText(
      en: 'corresponded with',
      fa: 'مکاتبه داشت با',
    ),
    RelationType.contemporaryOf => const LocalizedText(
      en: 'contemporary of',
      fa: 'هم‌روزگار با',
    ),
    RelationType.relatedTo => const LocalizedText(
      en: 'related to',
      fa: 'مرتبط با',
    ),
  };

  /// The short label for how well established a graph connection is.
  static LocalizedText relationConfidence(RelationConfidence confidence) =>
      switch (confidence) {
        RelationConfidence.documented => const LocalizedText(
          en: 'Documented',
          fa: 'مستند',
        ),
        RelationConfidence.accepted => const LocalizedText(
          en: 'Accepted',
          fa: 'پذیرفته',
        ),
        RelationConfidence.probable => const LocalizedText(
          en: 'Probable',
          fa: 'محتمل',
        ),
        RelationConfidence.contested => const LocalizedText(
          en: 'Contested',
          fa: 'محل مناقشه',
        ),
        RelationConfidence.speculative => const LocalizedText(
          en: 'Speculative',
          fa: 'گمانی',
        ),
      };

  /// A sentence explaining what a connection's confidence means, shown to a
  /// reader who taps the badge. A badge on its own teaches nobody anything.
  static LocalizedText relationConfidenceExplanation(
    RelationConfidence confidence,
  ) => switch (confidence) {
    RelationConfidence.documented => const LocalizedText(
      en: 'A text says so — their own statement, or an ancient report.',
      fa: 'متنی چنین می‌گوید — گفتهٔ خودش یا گزارشی کهن.',
    ),
    RelationConfidence.accepted => const LocalizedText(
      en: 'Standard in the scholarship, without resting on one passage.',
      fa: 'در پژوهش متعارف است، بی‌آنکه بر بندی مشخص تکیه کند.',
    ),
    RelationConfidence.probable => const LocalizedText(
      en: 'Argued for and generally found persuasive, but a reading.',
      fa: 'برایش استدلال شده و عموماً پذیرفتنی است، اما یک قرائت است.',
    ),
    RelationConfidence.contested => const LocalizedText(
      en: 'Scholars actively disagree that this connection holds.',
      fa: 'پژوهشگران در برقراری این پیوند اختلاف دارند.',
    ),
    RelationConfidence.speculative => const LocalizedText(
      en: 'Suggested on thin evidence. Recorded, not relied on.',
      fa: 'بر پایهٔ شواهدی اندک پیشنهاد شده است. ثبت شده، اما تکیه‌گاه نیست.',
    ),
  };

  /// The label shown for a relation in whichever direction it is being read.
  static LocalizedText relation(Relation relation) => relation.isInverseReading
      ? relationInverse(relation.type)
      : relationForward(relation.type);

  /// The short label for an attribution status.
  static LocalizedText attribution(AttributionStatus status) =>
      switch (status) {
        AttributionStatus.verified => const LocalizedText(
          en: 'Verified',
          fa: 'تأییدشده',
        ),
        AttributionStatus.probable => const LocalizedText(
          en: 'Probable',
          fa: 'محتمل',
        ),
        AttributionStatus.disputed => const LocalizedText(
          en: 'Disputed',
          fa: 'محل اختلاف',
        ),
        AttributionStatus.misattributed => const LocalizedText(
          en: 'Misattributed',
          fa: 'انتساب نادرست',
        ),
        AttributionStatus.unknown => const LocalizedText(
          en: 'Unverified',
          fa: 'تأییدنشده',
        ),
      };

  /// A sentence explaining what an attribution status means, shown to a reader
  /// who taps the badge. The badge alone teaches nobody anything.
  static LocalizedText attributionExplanation(AttributionStatus status) =>
      switch (status) {
        AttributionStatus.verified => const LocalizedText(
          en: 'Traced to a specific passage in a source.',
          fa: 'به بندی مشخص در یک منبع ردیابی شده است.',
        ),
        AttributionStatus.probable => const LocalizedText(
          en: 'Accepted by scholarship, but not pinned to a located passage.',
          fa: 'مورد پذیرش پژوهش است، اما به بندی مشخص گره نخورده است.',
        ),
        AttributionStatus.disputed => const LocalizedText(
          en: 'Scholars disagree about whether these are really their words.',
          fa: 'پژوهشگران در اینکه این‌ها به‌راستی سخنان او باشند اختلاف دارند.',
        ),
        AttributionStatus.misattributed => const LocalizedText(
          en:
              'These are not their words. Shown here so the record can be '
              'corrected rather than repeated.',
          fa:
              'این‌ها سخنان او نیستند. اینجا آورده شده‌اند تا این نکته اصلاح '
              'شود، نه تکرار.',
        ),
        AttributionStatus.unknown => const LocalizedText(
          en: 'No source has been traced for this.',
          fa: 'هیچ منبعی برای این ردیابی نشده است.',
        ),
      };

  /// The label marking what kind of claim a passage makes.
  static LocalizedText claimType(ClaimType type) => switch (type) {
    ClaimType.fact => const LocalizedText(en: 'Established', fa: 'مسلّم'),
    ClaimType.interpretation => const LocalizedText(
      en: 'Interpretation',
      fa: 'تفسیر',
    ),
    ClaimType.scholarlyDisagreement => const LocalizedText(
      en: 'Scholars disagree',
      fa: 'اختلاف پژوهشی',
    ),
    ClaimType.hypothesis => const LocalizedText(en: 'Hypothesis', fa: 'فرضیه'),
    ClaimType.disputed => const LocalizedText(
      en: 'Disputed',
      fa: 'مورد مناقشه',
    ),
  };

  /// The label for a reading depth.
  static LocalizedText depth(ContentDepth depth) => switch (depth) {
    ContentDepth.quick => const LocalizedText(en: 'Quick', fa: 'کوتاه'),
    ContentDepth.standard => const LocalizedText(
      en: 'Standard',
      fa: 'استاندارد',
    ),
    ContentDepth.deep => const LocalizedText(en: 'In depth', fa: 'عمیق'),
    ContentDepth.research => const LocalizedText(en: 'Research', fa: 'پژوهشی'),
  };

  /// The label for a reader's self-declared level.
  static LocalizedText level(LearningLevel level) => switch (level) {
    LearningLevel.beginner => const LocalizedText(
      en: 'New to philosophy',
      fa: 'تازه‌وارد به فلسفه',
    ),
    LearningLevel.intermediate => const LocalizedText(
      en: 'Some background',
      fa: 'با اندکی پیشینه',
    ),
    LearningLevel.advanced => const LocalizedText(
      en: 'Reads primary texts',
      fa: 'خوانندهٔ متون اصلی',
    ),
    LearningLevel.research => const LocalizedText(
      en: 'Works in the field',
      fa: 'پژوهشگر حوزه',
    ),
  };
}
