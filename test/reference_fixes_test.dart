import 'helpers/premium_fixture.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:german_vocabulary/models/vocabulary.dart';
import 'package:german_vocabulary/services/progress_storage.dart';
import 'package:german_vocabulary/state/app_controller.dart';
import 'package:german_vocabulary/ui/screens/practice_screen.dart';
import 'package:german_vocabulary/ui/theme.dart';
import 'package:german_vocabulary/ui/word_grammar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Catalog catalog;
  Word term(String value) =>
      catalog.words.values.firstWhere((w) => w.term == value);
  setUpAll(() async {
    catalog = await Catalog.load();
    final loader = FontLoader('Geist');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Geist-$weight.ttf'));
    }
    await loader.load();
  });
  test('imported grammar includes irregular, reflexive, modal and regional guidance', () {
    expect(
      catalog.words.values.where((w) => w.verbGrammar != null).length,
      greaterThanOrEqualTo(324),
    );
    expect(
      catalog.words.values.where((w) => w.patterns.isNotEmpty).length,
      greaterThanOrEqualTo(135),
    );
    expect(term('aufstehen').verbGrammar!.perfect, 'ist aufgestanden');
    expect(term('sich bewerben').verbGrammar!.preterite, 'bewarb sich');
    expect(term('sich bewerben').verbGrammar!.perfect, 'hat sich beworben');
    expect(term('hängen').verbGrammar!.participle, 'gehangen');
    expect(term('hängen').verbGrammar!.noteEn, contains('hängte'));
    expect(term('stehen').verbGrammar!.noteEn, contains('southern Germany'));
    expect(term('müssen').verbGrammar!.noteEn, contains('another infinitive'));
    expect(term('möchten').verbGrammar!.participle, isNull);
    expect(
      term('möchten').verbGrammar!.noteEn,
      contains('no separate past participle'),
    );
  });
  test('singulars and number usage distinguish plural headwords from plural-only nouns', () {
    final groceries = term('die Lebensmittel');
    expect(groceries.singular, 'das Lebensmittel');
    expect(groceries.gender, 'neuter');
    expect(groceries.pluralOnly, isFalse);
    expect(groceries.formAnswer, contains('Singular: das Lebensmittel'));
    expect(groceries.formAnswer, isNot(contains('die · neuter')));
    expect(term('die Eltern').pluralOnly, isTrue);
    expect(term('die Eltern').singular, isNull);
    expect(term('der Februar').pluralRare, isTrue);
    expect(term('auf').hasForms, isTrue);
    expect(term('auf').formAnswer, contains('Dativ'));
    expect(term('auf').formAnswer, contains('Akkusativ'));
  });
  test('corrected meanings preserve the two Bank senses and simpler A1 definitions', () {
    final banks = catalog.words.values
        .where((w) => w.term == 'die Bank')
        .toList();
    expect(banks.length, 2);
    expect(
      banks.singleWhere((w) => w.translation == 'bench').plural,
      'die Bänke',
    );
    expect(
      banks
          .singleWhere((w) => w.translation.contains('financial institution'))
          .plural,
      'die Banken',
    );
    expect(term('heißen').definition, 'Einen Namen haben.');
    expect(
      catalog.words['name']!.definition,
      'So heißt eine Person oder Sache.',
    );
  });
  test('formal pronouns and nouns return explicit capitalisation feedback', () {
    for (final word in [term('Sie'), term('Ihr')]) {
      expect(word.accepts(word.term), isTrue);
      final feedback = word.checkSpelling(word.term.toLowerCase());
      expect(feedback.status, SpellingStatus.capitalisation);
      expect(feedback.expected, word.term);
    }
    expect(catalog.words['a1-pro-sie']!.accepts('sie'), isTrue);
    expect(
      catalog.words['a1-pro-sie']!.checkSpelling('Sie').status,
      SpellingStatus.capitalisation,
    );
    final name = catalog.words['name']!;
    expect(name.accepts('Name'), isTrue);
    expect(name.accepts('Der Name'), isTrue);
    expect(name.checkSpelling('name').status, SpellingStatus.capitalisation);
    expect(name.checkSpelling('die Name').status, SpellingStatus.incorrect);
    expect(name.checkSpelling('Namme').status, SpellingStatus.incorrect);
    expect(term('die Bäckerei').accepts('Ba\u0308ckerei'), isTrue);
  });
  test(
    'meaning quizzes exclude a different sense of the same headword',
    () async {
      final banks = catalog.words.values.where((w) => w.term == 'die Bank');
      final bench = banks.singleWhere((w) => w.translation == 'bench');
      final financial = banks.singleWhere((w) => w.id != bench.id);
      final words = [
        ...banks,
        catalog.words['apfel']!,
        catalog.words['brot']!,
        term('der Zug'),
      ];
      final c = AppController(
        catalog: Catalog(words: {for (final w in words) w.id: w}, lessons: []),
        storage: MemoryProgressStorage(),
        purchases: await premiumFixture(),
      );
      c.startSession([bench], PracticeMode.quiz, 'Bank senses');
      final choices = c.quizOptions(bench);
      expect(choices, hasLength(4));
      expect(choices, contains('bench'));
      expect(choices, isNot(contains(financial.translation)));
      await c.flush();
      c.dispose();
    },
  );
  test(
    'sentence gaps use only reviewed choices and keep their order on resume',
    () async {
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
        purchases: await premiumFixture(),
      );
      final february = term('der Februar');
      c.startSession([term('der Name'), february], PracticeMode.quiz, 'Quiz');
      c.grade(true);
      c.nextWord();
      expect(february.contextSentence, 'Der Monat nach Januar heißt ________.');
      final choices = c.quizOptions(february, context: true);
      expect(choices.toSet(), {'Februar', 'Mai', 'August', 'Oktober'});
      expect(c.quizOptions(february, context: true), choices);
      await c.flush();
      final restored = AppController(catalog: catalog, storage: c.storage);
      await restored.load();
      expect(restored.quizOptions(february, context: true), choices);
      expect(term('der Name').contextSentence, isNull);
      expect(c.quizOptions(term('der Name'), context: true), contains('name'));
      for (final word in catalog.words.values.where(
        (w) => w.contextQuiz != null,
      )) {
        expect(word.contextQuiz!.validFor(word.bareTerm), isTrue);
      }
      c.dispose();
      restored.dispose();
    },
  );
  test('removed duplicate migrates favourites, lists, recall, days and session position', () async {
    const old = 'b1-adj-regelmaessig', current = 'telc-a1-adv-regelmaessig';
    final storage = MemoryProgressStorage();
    await storage.write({
      'schema': 1,
      'saved': [old, current],
      'lists': {
        'My words': [old],
      },
      'progress': {
        old: {
          'box': 3,
          'correct': 3,
          'attempts': 4,
          'reviewed': true,
          'due': '2026-10-15T19:00:00.000',
        },
      },
      'days': {
        '2026-10-08': [old, current],
      },
      'session': {
        'title': 'Earlier quiz',
        'mode': 'quiz',
        'wordIds': [old, current, 'name'],
        'index': 2,
        'seed': 7,
        'results': {old: true},
        'answer': 'a draft',
        'lessonId': 'b1-life-stories',
      },
    });
    final c = AppController(
      catalog: catalog,
      storage: storage,
      clock: () => DateTime(2026, 10, 8, 19),
    );
    await c.load();
    expect(c.storageError, isNull);
    expect(c.saved, {current});
    expect(c.lists['My words'], {current});
    expect(c.progress[current]!.box, 3);
    expect(c.progress[current]!.correct, 3);
    expect(c.progress[current]!.attempts, 4);
    expect(c.todayCount, 1);
    expect(c.session!.wordIds, [current, 'name']);
    expect(c.session!.currentId, 'name');
    expect(c.session!.index, 1);
    expect(c.session!.results, {current: true});
    expect(c.session!.answer, 'a draft');
    c.changed();
    await c.flush();
    final restored = AppController(catalog: catalog, storage: storage);
    await restored.load();
    expect(restored.saved, {current});
    expect(restored.session!.currentId, 'name');
    expect(restored.progress[current]!.box, 3);
    c.dispose();
    restored.dispose();
  });
  test(
    'explicit canonical recall wins regardless of legacy record ordering',
    () async {
      const old = 'b1-adj-regelmaessig', current = 'telc-a1-adv-regelmaessig';
      for (final reverse in [false, true]) {
        final entries = [
          MapEntry(old, {'box': 3}),
          MapEntry(current, {'box': 2}),
        ];
        final storage = MemoryProgressStorage();
        await storage.write({
          'schema': 1,
          'progress': Map.fromEntries(reverse ? entries.reversed : entries),
        });
        final c = AppController(catalog: catalog, storage: storage);
        await c.load();
        expect(c.progress[current]!.box, 2);
        expect(c.progress.length, 1);
        c.dispose();
      }
    },
  );
  testWidgets('spelling displays specific feedback for lowercase formal sie', (
    tester,
  ) async {
    final c = AppController(
      catalog: catalog,
      storage: MemoryProgressStorage(),
      purchases: await premiumFixture(),
    );
    c.startSession([term('Sie')], PracticeMode.spelling, 'Formal pronouns');
    await tester.pumpWidget(
      MaterialApp(
        theme: Garden.theme,
        home: PracticeScreen(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sie');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check my answer'));
    await tester.pumpAndSettle();
    expect(
      find.text('Formal Sie must start with a capital letter. Write: Sie'),
      findsOneWidget,
    );
    expect(c.session!.result, isFalse);
    expect(c.progress[term('Sie').id]!.learned, isFalse);
    await tester.pumpWidget(const SizedBox());
    await c.flush();
    c.dispose();
  });
  testWidgets(
    'grammar details render participle, auxiliary, exception note and case patterns',
    (tester) async {
      final word = term('hängen');
      await tester.pumpWidget(
        MaterialApp(
          theme: Garden.theme,
          home: Scaffold(
            body: SingleChildScrollView(child: WordGrammarDetails(word: word)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('hing'), findsOneWidget);
      expect(find.text('gehangen'), findsOneWidget);
      expect(find.text('haben'), findsOneWidget);
      expect(find.text(word.verbGrammar!.noteEn!), findsOneWidget);
      expect(find.text(word.patterns.first), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'past-tense and case drills keep their grading controls visible',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final c = AppController(
        catalog: catalog,
        storage: MemoryProgressStorage(),
        purchases: await premiumFixture(),
      );
      for (final value in ['sich bewerben', 'möchten', 'auf']) {
        final word = term(value);
        c.startSession([word], PracticeMode.forms, 'Grammar practice');
        await tester.pumpWidget(
          MaterialApp(
            theme: Garden.theme,
            home: PracticeScreen(controller: c),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reveal word forms'));
        await tester.pumpAndSettle();
        expect(find.text(word.formAnswer), findsOneWidget);
        expect(find.text('Got it').hitTestable(), findsOneWidget);
        final scroll = find
            .descendant(
              of: find.byKey(const ValueKey('practice-content-scroll')),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(
          tester.state<ScrollableState>(scroll).position.maxScrollExtent,
          lessThanOrEqualTo(1),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await c.flush();
      c.dispose();
    },
  );
}
