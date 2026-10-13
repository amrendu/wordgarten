import 'dart:convert';

import 'package:flutter/services.dart';

const levels = ['A1', 'A2', 'B1', 'B2', 'C1'];

// The reference merged this duplicate without changing its surviving ID.
String canonicalWordId(String id) =>
    id == 'b1-adj-regelmaessig' ? 'telc-a1-adv-regelmaessig' : id;

String normalizeVocabularyText(String input) {
  var text = input.trim().replaceAll(RegExp(r'\s+'), ' ');
  const composed = {
    'a\u0308': 'ä',
    'o\u0308': 'ö',
    'u\u0308': 'ü',
    'A\u0308': 'Ä',
    'O\u0308': 'Ö',
    'U\u0308': 'Ü',
    'e\u0301': 'é',
    'E\u0301': 'É',
  };
  for (final entry in composed.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text;
}

enum SpellingStatus { correct, capitalisation, incorrect }

class SpellingFeedback {
  const SpellingFeedback(this.status, this.expected);
  final SpellingStatus status;
  final String expected;
}

class VerbGrammar {
  const VerbGrammar({
    this.preterite,
    this.participle,
    this.auxiliary,
    this.perfect,
    this.noteEn,
    this.noteDe,
  });
  factory VerbGrammar.fromJson(Map<String, dynamic> json) => VerbGrammar(
    preterite: json['preterite'],
    participle: json['participle'],
    auxiliary: json['auxiliary'],
    perfect: json['perfect'],
    noteEn: json['note']?['en'],
    noteDe: json['note']?['de'],
  );
  final String? preterite, participle, auxiliary, perfect, noteEn, noteDe;
}

class ContextQuiz {
  const ContextQuiz({required this.sentence, required this.choices});
  factory ContextQuiz.fromJson(Map<String, dynamic> json) => ContextQuiz(
    sentence: json['sentence'],
    choices: List<String>.from(json['choices']),
  );
  final String sentence;
  final List<String> choices;
  bool validFor(String answer) =>
      sentence.contains('________') &&
      choices.length == 4 &&
      choices
              .map((v) => normalizeVocabularyText(v).toLowerCase())
              .toSet()
              .length ==
          4 &&
      choices.contains(answer);
}

enum PracticeMode {
  review('Review', 'Explore words and examples'),
  flashcards('Flashcards', 'Reveal, recall, remember'),
  spelling('Spelling', 'Write the German word'),
  quiz('Quiz', 'Find the meaning in context'),
  forms('Word forms', 'Articles, plurals and verbs');

  const PracticeMode(this.label, this.description);
  final String label;
  final String description;
}

class Word {
  const Word({
    required this.id,
    required this.term,
    required this.translation,
    required this.definition,
    required this.example,
    required this.exampleTranslation,
    required this.artwork,
    required this.part,
    this.gender,
    this.plural,
    this.forms,
    this.pronunciation,
    this.answers = const [],
    this.singular,
    this.numberUsage,
    this.pluralRare = false,
    this.pluralOnly = false,
    this.properName = false,
    this.verbGrammar,
    this.patterns = const [],
    this.contextQuiz,
    this.imageAsset,
    this.audioAssets = const {},
    this.sense,
  });

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    id: json['id'],
    term: json['term'],
    translation: json['translation'],
    definition: json['definition'],
    example: json['example'],
    exampleTranslation: json['exampleTranslation'],
    artwork: json['artwork'],
    part: json['part'],
    gender: json['gender'],
    plural: json['plural'],
    forms: json['forms'],
    pronunciation: json['pronunciation'],
    answers: List<String>.from(json['answers'] ?? []),
    singular: json['singular'],
    numberUsage: json['numberUsage'],
    pluralRare: json['pluralRare'] == true,
    pluralOnly: json['pluralOnly'] == true,
    properName: json['properName'] == true,
    verbGrammar: json['verbGrammar'] == null
        ? null
        : VerbGrammar.fromJson(json['verbGrammar']),
    patterns: List<String>.from(json['patterns'] ?? []),
    contextQuiz: json['contextQuiz'] == null
        ? null
        : ContextQuiz.fromJson(json['contextQuiz']),
    imageAsset: json['imageAsset'],
    audioAssets: Map<String, String>.from(json['audioAssets'] ?? {}),
    sense: json['sense'],
  );

  final String id,
      term,
      translation,
      definition,
      example,
      exampleTranslation,
      artwork,
      part;
  final String? gender, plural, forms, pronunciation;
  final List<String> answers;
  final String? singular, numberUsage;
  final bool pluralRare, pluralOnly, properName;
  final VerbGrammar? verbGrammar;
  final List<String> patterns;
  final ContextQuiz? contextQuiz;
  final String? imageAsset, sense;
  final Map<String, String> audioAssets;
  String get bareTerm => term.replaceFirst(RegExp(r'^(der|die|das) '), '');
  bool get hasForms =>
      gender != null ||
      forms != null ||
      plural != null ||
      verbGrammar != null ||
      patterns.isNotEmpty;
  String get formAnswer => [
    if (singular != null)
      'Singular: $singular'
    else if (gender != null)
      '${term.split(' ').first} · $gender',
    if (plural != null) '${pluralRare ? 'Rare plural' : 'Plural'}: $plural',
    if (numberUsage == 'usuallyPlural') 'Usually used in the plural',
    if (numberUsage == 'pluralHeadword') 'Plural entry; a singular exists',
    ?forms,
    if (verbGrammar?.preterite != null) 'Präteritum: ${verbGrammar!.preterite}',
    if (verbGrammar?.perfect != null) 'Perfekt: ${verbGrammar!.perfect}',
    if (part != 'verb') ...patterns,
  ].join('\n');
  SpellingFeedback checkSpelling(String input) {
    final value = normalizeVocabularyText(input);
    final valid = {term, ...answers};
    if (part == 'noun') {
      for (final form in valid.toList()) {
        if (RegExp(r'^(der|die|das) ').hasMatch(form)) {
          valid.add(form[0].toUpperCase() + form.substring(1));
        }
      }
    }
    if (value.isNotEmpty &&
        valid.any((a) => normalizeVocabularyText(a) == value)) {
      return SpellingFeedback(SpellingStatus.correct, term);
    }
    for (final answer in valid) {
      if (value.isNotEmpty &&
          normalizeVocabularyText(answer).toLowerCase() ==
              value.toLowerCase()) {
        return SpellingFeedback(SpellingStatus.capitalisation, answer);
      }
    }
    return SpellingFeedback(SpellingStatus.incorrect, term);
  }

  bool accepts(String input) =>
      checkSpelling(input).status == SpellingStatus.correct;
  String? get contextSentence =>
      contextQuiz?.validFor(bareTerm) == true ? contextQuiz!.sentence : null;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.level,
    required this.title,
    required this.germanTitle,
    required this.description,
    required this.artwork,
    required this.color,
    required this.wordIds,
    this.exam,
    this.coverage = 'starter',
    this.source = 'Wortgarten editorial starter pack',
  });
  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['slug'],
    level: json['level'] ?? 'A1',
    title: json['title']['en'],
    germanTitle: json['title']['de'],
    description: json['description']['en'],
    artwork: json['artwork'],
    color: json['color'],
    exam: json['exam'],
    coverage: json['coverage'] ?? 'starter',
    source: json['source'] ?? '',
    wordIds: List<String>.from(json['wordIds']),
  );
  final String id,
      level,
      title,
      germanTitle,
      description,
      artwork,
      color,
      coverage,
      source;
  final String? exam;
  final List<String> wordIds;
}

class Catalog {
  Catalog({
    required this.words,
    required this.lessons,
    this.topicImages = const {},
  });
  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
    words: {
      for (final row in json['words']) row['id'] as String: Word.fromJson(row),
    },
    lessons: [for (final row in json['lessons']) Lesson.fromJson(row)],
    topicImages: Map<String, String>.from(json['topicImages'] ?? {}),
  );
  static Future<Catalog> load() async => Catalog.fromJson(
    jsonDecode(await rootBundle.loadString('assets/data/catalog.json')),
  );
  final Map<String, Word> words;
  final List<Lesson> lessons;
  final Map<String, String> topicImages;
  List<Word> lessonWords(Lesson lesson) => [
    for (final id in lesson.wordIds)
      if (words[id] != null) words[id]!,
  ];
  List<Lesson> collections(String level, {String? exam, String search = ''}) {
    final query = search.trim().toLowerCase();
    return lessons
        .where(
          (l) =>
              l.level == level &&
              l.exam == exam &&
              (query.isEmpty ||
                  '${l.title} ${l.germanTitle}'.toLowerCase().contains(query) ||
                  lessonWords(l).any(
                    (w) => '${w.term} ${w.translation} ${w.plural ?? ''}'
                        .toLowerCase()
                        .contains(query),
                  )),
        )
        .toList();
  }

  List<Word> levelWords(String level) => {
    for (final l in collections(level))
      for (final w in lessonWords(l)) w.id: w,
  }.values.toList();
}
