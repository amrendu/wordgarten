"""Build the bundled catalog from the reference export and editorial packs."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
catalog = json.loads((ROOT / 'assets/data/reference.json').read_text())
word_by_id = {w['id']: w for w in catalog['words']}
reference_by_identity = {}
for reference_word in catalog['words']:
    reference_by_identity.setdefault((reference_word['term'], reference_word['part']), []).append(reference_word)
lesson_by_id = {lesson['slug']: lesson for lesson in catalog['lessons']}
editorial_lessons = []
section = None
for line in (ROOT / 'content/starter-packs.txt').read_text().splitlines():
    if not line.strip() or line.startswith('#'):
        continue
    if line.startswith('['):
        level, topic, en, de, artwork = line.strip('[]').split('|')
        section = dict(slug=f'{level.lower()}-{topic}', level=level, topic=topic,
                       title=dict(en=en, de=de),
                       description=dict(en=f'Useful {level} words for {en.lower()}.',
                                        de=f'Nützliche Wörter auf Niveau {level}: {de}.'),
                       artwork=artwork, color=['mint', 'peach', 'lavender'][len(catalog['lessons']) % 3],
                       wordIds=[], coverage='starter', source='Wortgarten editorial starter pack')
        editorial_lessons.append(section)
        continue
    term, translation, definition, example, example_translation, grammar = line.split('|')
    part, _, detail = grammar.partition(':')
    normalized = term.lower().replace('ä', 'ae').replace('ö', 'oe').replace('ü', 'ue').replace('ß', 'ss')
    word_id = f"{section['level'].lower()}-{part}-" + re.sub('[^a-z0-9]+', '-', normalized).strip('-')
    word = dict(id=word_id, term=term, translation=translation, definition=definition,
                example=example, exampleTranslation=example_translation,
                artwork=section['artwork'], part=dict(n='noun', v='verb', adj='adjective',
                adv='adverb', ex='expression')[part], answers=[term, re.sub(r'^(der|die|das) ', '', term)])
    if part == 'n':
        word['gender'] = {'der': 'masculine', 'die': 'feminine', 'das': 'neuter'}[term.split()[0]]
        word['plural'] = '—' if detail == '—' else f'die {detail}'
    elif part == 'v' and detail:
        word['forms'] = ' · '.join(f'{pronoun} {form}' for pronoun, form in zip(['ich', 'du', 'er/sie/es'], detail.split(';')))
    if word_id in word_by_id:
        existing = word_by_id[word_id]
        # Keep published IDs and prefer refreshed reference content, but never
        # silently repurpose an ID for a different term or part of speech.
        if (existing['term'], existing['part']) != (word['term'], word['part']):
            raise ValueError(f'Conflicting word identity: {word_id}')
    else:
        # Refresh equivalent legacy mobile cards too, retaining their IDs.
        # Multiple senses (for example Bank/Banken versus Bank/Bänke) must not
        # be conflated; only an unambiguous identity or exact meaning is reused.
        candidates = reference_by_identity.get((word['term'], word['part']), [])
        matches = [entry for entry in candidates if entry['translation'] == word['translation']]
        reference_word = candidates[0] if len(candidates) == 1 else matches[0] if len(matches) == 1 else None
        if reference_word is not None:
            word = {**reference_word, 'id': word_id, 'artwork': word['artwork']}
        word_by_id[word_id] = word
        catalog['words'].append(word)
    section['wordIds'].append(word_id)

for lesson in editorial_lessons:
    existing = lesson_by_id.get(lesson['slug'])
    if existing is None:
        catalog['lessons'].append(lesson)
        lesson_by_id[lesson['slug']] = lesson
    else:
        # A new reference topic can expand an existing mobile topic without
        # dropping its old words, bookmarks, or unfinished session IDs.
        additions = [word for word in lesson['wordIds'] if word not in existing['wordIds']]
        existing['wordIds'].extend(additions)
        if additions:
            existing['supplementaryWordIds'] = list(dict.fromkeys(
                existing.get('supplementaryWordIds', []) + additions))

    for exam in ['goethe', 'telc']:
        slug = f"{exam}-{lesson['slug']}"
        # Keep source-specific exam selections exact when they already exist.
        # Earlier mobile words remain available in general packs and saved lists.
        if slug not in lesson_by_id:
            exam_lesson = {**lesson, 'exam': exam, 'slug': slug}
            catalog['lessons'].append(exam_lesson)
            lesson_by_id[slug] = exam_lesson

assert len(word_by_id) == len(catalog['words'])
assert len({l['slug'] for l in catalog['lessons']}) == len(catalog['lessons'])
for lesson in catalog['lessons']:
    assert all(w in word_by_id for w in lesson['wordIds']), lesson['slug']
    assert len(set(lesson['wordIds'])) == len(lesson['wordIds']), lesson['slug']
(ROOT / 'assets/data/catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2))
print(f"Bundled {len(catalog['words'])} unique words and {len(catalog['lessons'])} lessons across A1–C1.")
