import 'package:flutter/material.dart';

import '../models/vocabulary.dart';
import 'theme.dart';
import 'widgets.dart';

/// Full grammar is opened on demand, keeping practice actions on screen.
class WordGrammarDetails extends StatelessWidget {
  const WordGrammarDetails({super.key, required this.word});
  final Word word;
  @override
  Widget build(BuildContext context) {
    if (!word.hasForms) return const SizedBox.shrink();
    final grammar = word.verbGrammar;
    final rows = <(String, String)>[
      if (word.singular != null) ('Singular', word.singular!),
      if (word.gender != null)
        (word.singular != null ? 'Gender (singular)' : 'Gender', word.gender!),
      if (word.plural != null)
        (word.pluralRare ? 'Rare plural' : 'Plural', word.plural!),
      if (word.forms != null)
        (
          word.part == 'verb'
              ? 'Present tense'
              : word.pluralOnly
              ? 'Number'
              : 'Forms',
          word.forms!,
        ),
      if (word.numberUsage == 'usuallyPlural')
        ('Number', 'Usually used in the plural'),
      if (word.numberUsage == 'pluralHeadword')
        ('Number', 'Plural entry; a singular exists'),
      if (grammar?.preterite != null)
        ('Präteritum · er/sie/es', grammar!.preterite!),
      if (grammar?.participle != null)
        ('Past participle · Partizip II', grammar!.participle!),
      if (grammar?.auxiliary != null)
        ('Perfect auxiliary', grammar!.auxiliary!),
      if (grammar?.perfect != null) ('Perfekt · er/sie/es', grammar!.perfect!),
    ];
    return GardenCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 18, color: Garden.green),
              SizedBox(width: 9),
              Expanded(child: Eyebrow('Grammar & usage')),
            ],
          ),
          for (final (label, value) in rows) ...[
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Garden.muted),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Garden.ink,
                height: 1.5,
              ),
            ),
          ],
          if (grammar?.noteEn != null || grammar?.noteDe != null) ...[
            const SizedBox(height: 14),
            const Text(
              'Usage note',
              style: TextStyle(fontSize: 11, color: Garden.muted),
            ),
            const SizedBox(height: 5),
            Text(
              grammar!.noteEn ?? grammar.noteDe!,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ],
          if (word.patterns.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Patterns & cases',
              style: TextStyle(fontSize: 11, color: Garden.muted),
            ),
            for (final pattern in word.patterns)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 15,
                        color: Garden.green,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        pattern,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Garden.green,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
