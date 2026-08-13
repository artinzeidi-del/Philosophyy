import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';

/// Display names for the content taxonomies.
///
/// ## Why these are not in the ARB files
///
/// The ARB files hold interface chrome — buttons, labels, error messages. These
/// are different: "philosophy of mind" and "فلسفهٔ ذهن" are technical vocabulary,
/// and the Persian is a term of art with an established form rather than a
/// translation choice. Keeping them next to the enums they name means a new
/// branch of philosophy cannot be added without its Persian name, which is
/// exactly the constraint a bilingual product needs.
///
/// The translations follow standard Persian philosophical usage. Where Persian
/// scholarship uses more than one term, the more widely taught one is used and
/// the alternative is not silently dropped but recorded in the glossary in
/// `docs/GLOSSARY.md`.
abstract final class TaxonomyLabels {
  /// The display name of a branch of philosophy.
  static LocalizedText branch(PhilosophyBranch branch) => switch (branch) {
    PhilosophyBranch.metaphysics => const LocalizedText(
      en: 'Metaphysics',
      fa: 'مابعدالطبیعه',
    ),
    PhilosophyBranch.epistemology => const LocalizedText(
      en: 'Epistemology',
      fa: 'معرفت‌شناسی',
    ),
    PhilosophyBranch.ethics => const LocalizedText(en: 'Ethics', fa: 'اخلاق'),
    PhilosophyBranch.logic => const LocalizedText(en: 'Logic', fa: 'منطق'),
    PhilosophyBranch.aesthetics => const LocalizedText(
      en: 'Aesthetics',
      fa: 'زیبایی‌شناسی',
    ),
    PhilosophyBranch.politicalPhilosophy => const LocalizedText(
      en: 'Political Philosophy',
      fa: 'فلسفهٔ سیاسی',
    ),
    PhilosophyBranch.philosophyOfMind => const LocalizedText(
      en: 'Philosophy of Mind',
      fa: 'فلسفهٔ ذهن',
    ),
    PhilosophyBranch.philosophyOfLanguage => const LocalizedText(
      en: 'Philosophy of Language',
      fa: 'فلسفهٔ زبان',
    ),
    PhilosophyBranch.philosophyOfScience => const LocalizedText(
      en: 'Philosophy of Science',
      fa: 'فلسفهٔ علم',
    ),
    PhilosophyBranch.philosophyOfReligion => const LocalizedText(
      en: 'Philosophy of Religion',
      fa: 'فلسفهٔ دین',
    ),
    PhilosophyBranch.socialPhilosophy => const LocalizedText(
      en: 'Social Philosophy',
      fa: 'فلسفهٔ اجتماعی',
    ),
    PhilosophyBranch.existentialPhilosophy => const LocalizedText(
      en: 'Existential Philosophy',
      fa: 'فلسفهٔ اگزیستانس',
    ),
    PhilosophyBranch.philosophyOfTechnology => const LocalizedText(
      en: 'Philosophy of Technology',
      fa: 'فلسفهٔ فناوری',
    ),
    PhilosophyBranch.philosophyOfLaw => const LocalizedText(
      en: 'Philosophy of Law',
      fa: 'فلسفهٔ حقوق',
    ),
    PhilosophyBranch.philosophyOfEducation => const LocalizedText(
      en: 'Philosophy of Education',
      fa: 'فلسفهٔ آموزش و پرورش',
    ),
    PhilosophyBranch.philosophyOfHistory => const LocalizedText(
      en: 'Philosophy of History',
      fa: 'فلسفهٔ تاریخ',
    ),
    PhilosophyBranch.philosophyOfMathematics => const LocalizedText(
      en: 'Philosophy of Mathematics',
      fa: 'فلسفهٔ ریاضیات',
    ),
    PhilosophyBranch.philosophyOfEconomics => const LocalizedText(
      en: 'Philosophy of Economics',
      fa: 'فلسفهٔ اقتصاد',
    ),
  };

  /// The display name of a tradition.
  static LocalizedText tradition(Tradition tradition) => switch (tradition) {
    Tradition.ancientGreek => const LocalizedText(
      en: 'Ancient Greek',
      fa: 'یونان باستان',
    ),
    Tradition.roman => const LocalizedText(en: 'Roman', fa: 'رومی'),
    Tradition.hellenistic => const LocalizedText(
      en: 'Hellenistic',
      fa: 'هلنیستی',
    ),
    Tradition.medieval => const LocalizedText(en: 'Medieval', fa: 'قرون وسطا'),
    Tradition.islamic => const LocalizedText(en: 'Islamic', fa: 'اسلامی'),
    Tradition.persian => const LocalizedText(en: 'Persian', fa: 'ایرانی'),
    Tradition.jewish => const LocalizedText(en: 'Jewish', fa: 'یهودی'),
    Tradition.christian => const LocalizedText(en: 'Christian', fa: 'مسیحی'),
    Tradition.indian => const LocalizedText(en: 'Indian', fa: 'هندی'),
    Tradition.chinese => const LocalizedText(en: 'Chinese', fa: 'چینی'),
    Tradition.japanese => const LocalizedText(en: 'Japanese', fa: 'ژاپنی'),
    Tradition.african => const LocalizedText(en: 'African', fa: 'آفریقایی'),
    Tradition.latinAmerican => const LocalizedText(
      en: 'Latin American',
      fa: 'آمریکای لاتین',
    ),
    Tradition.european => const LocalizedText(en: 'European', fa: 'اروپایی'),
    Tradition.american => const LocalizedText(en: 'American', fa: 'آمریکایی'),
    Tradition.contemporary => const LocalizedText(
      en: 'Contemporary',
      fa: 'معاصر',
    ),
  };

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
    RelationType.relatedTo => const LocalizedText(
      en: 'related to',
      fa: 'مرتبط با',
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
