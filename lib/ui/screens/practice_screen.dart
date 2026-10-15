import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/vocabulary.dart';
import '../../services/speech_service.dart';
import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets.dart';
import '../word_grammar.dart';
import 'paywall_screen.dart';

void openPractice(BuildContext context, AppController c) {
  final session = c.session;
  if (session != null &&
      session.wordIds.skip(session.index).any((id) => !c.canAccessWord(id))) {
    showPaywall(context, c, reason: 'Unlock the words in your saved session.');
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => PracticeScreen(controller: c)),
  );
}

void startPractice(
  BuildContext context,
  AppController c,
  List<Word> words,
  PracticeMode mode,
  String title, {
  String? lessonId,
}) {
  if (words.where((w) => mode != PracticeMode.forms || w.hasForms).isEmpty) {
    toast(context, 'There are no words for this mode yet.');
    return;
  }
  if (lessonId != null) {
    final lesson = c.catalog.lessons.where((l) => l.id == lessonId).firstOrNull;
    if (lesson != null && !c.canAccessLesson(lesson)) {
      showPaywall(
        context,
        c,
        reason: 'Unlock $title and every exam collection.',
      );
      return;
    }
  }
  if (!c.startSession(words, mode, title, lessonId: lessonId)) {
    showPaywall(context, c, reason: 'Unlock all the words in this collection.');
    return;
  }
  openPractice(context, c);
}

void showModePicker(
  BuildContext context,
  AppController c,
  List<Word> words,
  String title, {
  String? lessonId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * .9,
  ),
  builder: (sheetContext) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How would you like to learn?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '$title · ${words.length} words',
              style: const TextStyle(fontSize: 12, color: Garden.muted),
            ),
            const SizedBox(height: 16),
            for (final mode in PracticeMode.values)
              if (mode != PracticeMode.forms || words.any((w) => w.hasForms))
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Garden.mint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(modeIcon(mode), color: Garden.green, size: 21),
                  ),
                  title: Text(
                    mode.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    mode.description,
                    style: const TextStyle(fontSize: 11, color: Garden.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    startPractice(
                      context,
                      c,
                      words,
                      mode,
                      title,
                      lessonId: lessonId,
                    );
                  },
                ),
          ],
        ),
      ),
    ),
  ),
);

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.controller, this.speech});
  final AppController controller;
  final SpeechService? speech;
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with WidgetsBindingObserver {
  late final SpeechService _speech;
  final _input = TextEditingController();
  final _focus = FocusNode();
  int _autoplayEpoch = 0;
  String? _spokenFlashcard;
  Timer? _reviewTimer;
  StudySession? _reviewSession;
  bool _foreground = true;
  bool _autoplay = false, _hint = false;
  bool _keyboardOpen = false;
  double _bodyHeight = 0, _bodyWidth = 0;
  AppController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    _speech = widget.speech ?? SpeechService();
    _input.text = c.session?.answer ?? '';
    final session = c.session;
    _autoplay =
        session != null &&
        !session.complete &&
        session.mode == PracticeMode.review &&
        c.canAccessWord(session.currentId);
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_accessChanged);
    _queueFlashcardAudio();
    _queueReviewPrompt();
    if (_autoplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _foreground) _schedule();
      });
    }
  }

  void _accessChanged() {
    final s = c.session;
    if (s != null && !s.complete && !c.canAccessWord(s.currentId)) {
      _autoplayEpoch++;
      _speech.stop();
      if (_autoplay && mounted) setState(() => _autoplay = false);
      return;
    }
    _queueFlashcardAudio();
    _queueReviewPrompt();
  }

  void _queueReviewPrompt() {
    final session = c.session;
    if (!_foreground ||
        session == null ||
        !session.complete ||
        !c.eligibleForReview ||
        identical(_reviewSession, session)) {
      return;
    }
    _reviewSession = session;
    _reviewTimer?.cancel();
    _reviewTimer = Timer(const Duration(seconds: 2), () {
      _reviewTimer = null;
      bool canPresent() =>
          mounted &&
          _foreground &&
          ModalRoute.of(context)?.isCurrent == true &&
          identical(c.session, session) &&
          session.complete;
      unawaited(c.requestReviewAfterSession(canPresent: canPresent));
    });
  }

  void _queueFlashcardAudio() {
    final session = c.session;
    if (!_foreground ||
        session == null ||
        session.complete ||
        session.mode != PracticeMode.flashcards ||
        !c.canAccessWord(session.currentId)) {
      return;
    }
    final card = '${session.seed}-${session.index}-${session.currentId}';
    if (_spokenFlashcard == card) return;
    _spokenFlashcard = card;
    final epoch = ++_autoplayEpoch;
    final word = c.catalog.words[session.currentId]!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_foreground ||
          epoch != _autoplayEpoch ||
          c.session?.currentId != word.id ||
          !c.canAccessWord(word.id)) {
        return;
      }
      _speak(word);
    });
  }

  @override
  void dispose() {
    _reviewTimer?.cancel();
    _autoplayEpoch++;
    _speech.stop();
    _input.dispose();
    _focus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_accessChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      if (_reviewTimer != null) {
        _reviewTimer!.cancel();
        _reviewTimer = null;
        _reviewSession = null;
      }
      _autoplayEpoch++;
      _speech.stop();
      if (mounted) setState(() => _autoplay = false);
    } else {
      _queueReviewPrompt();
    }
  }

  void _schedule() {
    if (c.session?.mode != PracticeMode.review) return;
    final epoch = ++_autoplayEpoch;
    if (!_autoplay) {
      _speech.stop();
      return;
    }
    final session = c.session;
    if (session == null ||
        session.complete ||
        !c.canAccessWord(session.currentId)) {
      return;
    }
    final word = c.catalog.words[session.currentId]!;
    _speech.playWord(word, kind: AudioKind.card, rate: c.speechRate).then((
      result,
    ) {
      if (!mounted ||
          epoch != _autoplayEpoch ||
          !_autoplay ||
          c.session?.currentId != word.id) {
        return;
      }
      if (result == PlaybackResult.completed) {
        _next();
      } else {
        setState(() => _autoplay = false);
        if (result == PlaybackResult.failed) {
          toast(context, 'Audio could not play. Your place is saved.');
        }
      }
    });
  }

  void _next() {
    _autoplayEpoch++;
    _focus.unfocus();
    _speech.stop();
    c.nextWord();
    _input.clear();
    setState(() => _hint = false);
    _schedule();
  }

  Future<void> _speak(Word word, {AudioKind kind = AudioKind.term}) async {
    _autoplayEpoch++;
    if (_autoplay) setState(() => _autoplay = false);
    final result = await _speech.playWord(word, kind: kind, rate: c.speechRate);
    if (result == PlaybackResult.failed && mounted) {
      toast(
        context,
        'Audio is unavailable. Install a German system voice for words without a recording.',
      );
    }
  }

  void _grade(bool correct) {
    HapticFeedback.lightImpact();
    c.grade(correct);
  }

  void _insert(String character) {
    final text = _input.text;
    final selection = _input.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    _input.value = TextEditingValue(
      text: text.replaceRange(start, end, character),
      selection: TextSelection.collapsed(offset: start + character.length),
    );
    c.saveDraft(_input.text);
    _focus.requestFocus();
  }

  String? _context(Word word) => word.contextSentence;

  String _feedbackText(Word word, StudySession session) {
    if (session.result == true) return 'Nicely remembered!';
    if (session.mode == PracticeMode.spelling) {
      final feedback = word.checkSpelling(session.answer);
      if (feedback.status == SpellingStatus.capitalisation) {
        return ['Sie', 'Ihr'].contains(word.term)
            ? 'Formal ${word.term} must start with a capital letter. Write: ${feedback.expected}'
            : 'Check the capitalisation. Write: ${feedback.expected}';
      }
    }
    return '${word.term} · ${word.translation}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final session = c.session;
      if (session == null) {
        return const Scaffold(
          body: Center(child: Text('Your session has finished.')),
        );
      }
      if (session.complete) return _summary(session);
      final word = c.catalog.words[session.currentId]!;
      if (!c.canAccessWord(word.id)) {
        return Scaffold(
          appBar: AppBar(title: const Text('Your place is saved')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: PremiumInvitation(
                controller: c,
                title: 'Keep your garden growing.',
                description: 'Restore or renew Premium to continue these words. Your progress is kept.',
              ),
            ),
          ),
        );
      }
      final result = session.result;
      _keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Garden.background,
          leading: IconButton(
            tooltip: 'Close and save session',
            icon: const Icon(Icons.close_rounded, size: 23),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Column(
            children: [
              Text(
                session.mode.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Garden.muted),
              ),
            ],
          ),
          actions: [
            if (session.mode != PracticeMode.flashcards)
              IconButton(
                tooltip: c.saved.contains(word.id)
                    ? 'Unsave word'
                    : 'Save word',
                onPressed: () => c.toggleSaved(word.id),
                icon: Icon(
                  c.saved.contains(word.id)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  size: 22,
                  color: Garden.green,
                ),
              ),
          ],
        ),
        bottomNavigationBar: session.mode == PracticeMode.flashcards
            ? null
            : Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                    child: _actions(session),
                  ),
                ),
              ),
        body: SafeArea(
          top: false,
          bottom: session.mode == PracticeMode.flashcards,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _bodyHeight = constraints.maxHeight;
              _bodyWidth = constraints.maxWidth;
              if (session.mode == PracticeMode.flashcards) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: session.index / session.wordIds.length,
                                minHeight: 5,
                                backgroundColor: Garden.mint,
                                color: Garden.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${session.index + 1} / ${session.wordIds.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Garden.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth >= 760 ? 900 : 620,
                              maxHeight: constraints.maxWidth >= 760
                                  ? 860
                                  : double.infinity,
                            ),
                            child: _recallCard(word, session),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                key: const ValueKey('practice-content-scroll'),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: session.index / session.wordIds.length,
                              minHeight: 5,
                              backgroundColor: Garden.mint,
                              color: Garden.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${session.index + 1} / ${session.wordIds.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Garden.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (session.mode == PracticeMode.review)
                      _review(word)
                    else if (session.mode == PracticeMode.flashcards ||
                        session.mode == PracticeMode.forms)
                      _flashcard(word, session)
                    else if (session.mode == PracticeMode.spelling)
                      _spelling(word, session)
                    else
                      _quiz(word, session),
                    if (result != null &&
                        session.mode != PracticeMode.review) ...[
                      const SizedBox(height: 10),
                      GardenCard(
                        color: result ? Garden.mint : Garden.peach,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              result
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.refresh_rounded,
                              size: 20,
                              color: result ? Garden.green : Garden.red,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _feedbackText(word, session),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: result ? Garden.green : Garden.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!_keyboardOpen &&
                        (session.mode == PracticeMode.review ||
                            session.revealed ||
                            result != null))
                      TextButton.icon(
                        onPressed: () => _details(word),
                        icon: const Icon(Icons.info_outline_rounded, size: 16),
                        label: const Text(
                          'Example & word details',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
  Widget _actions(StudySession session) {
    if (session.mode == PracticeMode.review || session.result != null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _next,
          icon: Icon(
            session.index == session.wordIds.length - 1
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded,
            size: 18,
          ),
          label: Text(
            session.index == session.wordIds.length - 1
                ? 'Finish session'
                : 'Next word',
          ),
        ),
      );
    }
    if (session.mode == PracticeMode.spelling) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _input.text.trim().isEmpty
              ? null
              : () {
                  _focus.unfocus();
                  _grade(
                    c.catalog.words[session.currentId]!.accepts(_input.text),
                  );
                },
          child: const Text('Check my answer'),
        ),
      );
    }
    if (session.mode == PracticeMode.flashcards ||
        session.mode == PracticeMode.forms) {
      if (!session.revealed) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: c.reveal,
            child: Text(
              session.mode == PracticeMode.forms
                  ? 'Reveal word forms'
                  : 'Reveal meaning',
            ),
          ),
        );
      }
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _grade(false),
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Again'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _grade(true),
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Got it'),
            ),
          ),
        ],
      );
    }
    return const SizedBox(
      height: 20,
      child: Center(
        child: Text(
          'Choose an answer above',
          style: TextStyle(fontSize: 12, color: Garden.muted),
        ),
      ),
    );
  }

  void _details(Word word) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .85,
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: WordArtwork(
                word,
                size: (MediaQuery.sizeOf(context).width - 96).clamp(180, 260),
                enlargeable: true,
              ),
            ),
            const SizedBox(height: 18),
            Text(word.term, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(word.translation, style: const TextStyle(color: Garden.muted)),
            const SizedBox(height: 12),
            Text(word.definition),
            if (word.pronunciation != null) ...[
              const SizedBox(height: 8),
              Text(
                word.pronunciation!,
                style: const TextStyle(color: Garden.muted),
              ),
            ],
            const SizedBox(height: 14),
            _example(word),
            if (word.hasForms) ...[
              const SizedBox(height: 14),
              WordGrammarDetails(word: word),
            ],
          ],
        ),
      ),
    ),
  );

  // Give the artwork the space left by this card's actual text. The keyboard,
  // answer feedback, long grammar, and larger text all keep their space first.
  double _artworkSize(Word word, StudySession session) {
    final width = (_bodyWidth - 68).clamp(100.0, 500.0);
    final base = Theme.of(context).textTheme.bodyMedium!;
    double textHeight(String value, TextStyle style, {double? maxWidth}) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: base.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: maxWidth ?? width);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    const body = TextStyle(fontSize: 12);
    final title = Theme.of(context).textTheme.headlineMedium!
        .copyWith(fontSize: 26);
    var occupied =
        16 + 12 + textHeight('1 / 28', const TextStyle(fontSize: 11));
    if (session.mode == PracticeMode.review ||
        session.revealed ||
        session.result != null) {
      occupied += 48;
    }
    if (session.result != null && session.mode != PracticeMode.review) {
      occupied +=
          10 +
          24 +
          max(
            20,
            textHeight(
              _feedbackText(word, session),
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxWidth: width - 29,
            ),
          );
    }
    var maximum = 240.0, minimum = 72.0;
    switch (session.mode) {
      case PracticeMode.review:
        maximum = 220;
        occupied +=
            32 +
            48 +
            55 +
            textHeight(word.term, title) +
            textHeight(word.translation, const TextStyle(fontSize: 17)) +
            textHeight(word.definition, body) +
            textHeight(
              word.example,
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ) +
            textHeight(word.exampleTranslation, body);
      case PracticeMode.flashcards:
      case PracticeMode.forms:
        final forms = session.mode == PracticeMode.forms;
        final heading = session.revealed
            ? (forms ? word.term : word.translation)
            : (forms ? word.bareTerm : word.term);
        final prompt = session.revealed
            ? (forms ? word.formAnswer : word.definition)
            : forms
            ? (word.part == 'noun'
                  ? 'Can you recall the article and plural?'
                  : word.part == 'verb'
                  ? 'Can you recall the present and past forms?'
                  : word.patterns.isNotEmpty
                  ? 'Can you recall the preposition and case?'
                  : 'Can you recall the word forms?')
            : 'What does this word mean?';
        occupied +=
            32 +
            48 +
            30 +
            textHeight(heading, title) +
            textHeight(
              prompt,
              TextStyle(fontSize: session.revealed ? 13 : 12, height: 1.5),
            );
      case PracticeMode.spelling:
        maximum = 190;
        occupied +=
            32 +
            15 +
            26 +
            12 +
            56 +
            textHeight(word.translation, title.copyWith(fontSize: 25)) +
            textHeight(word.part, body);
        if (session.result == null) occupied += 58;
        if (_hint) occupied += 27;
      case PracticeMode.quiz:
        maximum = 160;
        minimum = 48;
        final sentence = session.index.isOdd ? _context(word) : null;
        occupied +=
            28 +
            15 +
            22 +
            12 +
            textHeight(
              sentence ?? word.term,
              title.copyWith(fontSize: sentence == null ? 24 : 20),
            ) +
            textHeight(
              sentence == null
                  ? 'Which meaning fits this word?'
                  : word.exampleTranslation,
              body,
            );
        if (sentence == null) {
          occupied +=
              6 +
              textHeight(
                word.example,
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              );
        }
        for (final option in c.quizOptions(word, context: sentence != null)) {
          occupied +=
              8 +
              22 +
              max(
                27,
                textHeight(
                  option,
                  const TextStyle(fontSize: 13),
                  maxWidth: width - 28,
                ),
              );
        }
    }
    return min(width, (_bodyHeight - occupied - 8).clamp(minimum, maximum));
  }

  Widget _review(Word word) => GardenCard(
    color: Garden.mint,
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            Tag(word.part, color: Colors.white.withValues(alpha: .6)),
            const Spacer(),
            IconButton(
              tooltip: _autoplay ? 'Pause auto-play' : 'Auto-play review',
              onPressed: () {
                setState(() => _autoplay = !_autoplay);
                _schedule();
              },
              icon: Icon(
                _autoplay
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                color: Garden.green,
              ),
            ),
            IconButton(
              tooltip: 'Listen to word',
              onPressed: () => _speak(word),
              icon: const Icon(Icons.volume_up_outlined, color: Garden.green),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, bounds) {
            final tablet = bounds.maxWidth >= 720;
            final details = Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  word.term,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  word.translation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, color: Garden.green),
                ),
                const SizedBox(height: 9),
                Text(
                  word.definition,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Garden.muted),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  word.example,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  word.exampleTranslation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Garden.muted),
                ),
              ],
            );
            if (!tablet) {
              return Column(
                children: [
                  WordArtwork(word, size: _artworkSize(word, c.session!)),
                  details,
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                children: [
                  WordArtwork(word, size: 340),
                  const SizedBox(width: 28),
                  Expanded(child: details),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
  Widget _example(Word word) => GardenCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Eyebrow('In a sentence'),
            const Spacer(),
            IconButton(
              tooltip: 'Listen to example',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: () => _speak(word, kind: AudioKind.example),
              icon: const Icon(
                Icons.volume_up_outlined,
                size: 18,
                color: Garden.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          word.example,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 7),
        Text(
          word.exampleTranslation,
          style: const TextStyle(fontSize: 12, color: Garden.muted),
        ),
      ],
    ),
  );
  Widget _recallCard(Word word, StudySession session) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final contentHeight = max(0.0, bounds.maxHeight - 110);
        final compact = contentHeight < 500;
        final gap = compact ? 8.0 : 14.0;
        final pictureSize =
            (contentHeight * (bounds.maxWidth >= 760 ? .42 : .34)).clamp(
              100.0,
              bounds.maxWidth >= 760 ? 310.0 : 230.0,
            );
        final part = word.part.isEmpty
            ? ''
            : '${word.part[0].toUpperCase()}${word.part.substring(1)}';
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.rotate(
              angle: .025,
              child: Container(
                margin: const EdgeInsets.only(top: 9, left: 5),
                decoration: BoxDecoration(
                  color: const Color(0xffe4e9dc),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              key: ValueKey('recall-${session.currentId}-${session.seed}'),
              tween: Tween(begin: 0, end: session.revealed ? pi : 0),
              duration: const Duration(milliseconds: 380),
              builder: (context, angle, _) {
                final back = angle > pi / 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .001)
                    ..rotateY(angle),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(back ? pi : 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Garden.border),
                        boxShadow: [
                          BoxShadow(
                            color: Garden.ink.withValues(alpha: .04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: Material(
                          color: Colors.white,
                          child: Column(
                            children: [
                              SizedBox(
                                height: 48,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      if (back)
                                        IconButton(
                                          tooltip: 'Word details',
                                          onPressed: () => _details(word),
                                          icon: const Icon(
                                            Icons.info_outline_rounded,
                                            size: 21,
                                            color: Garden.muted,
                                          ),
                                        ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Listen to word',
                                        onPressed: () => _speak(word),
                                        icon: const Icon(
                                          Icons.volume_up_outlined,
                                          size: 23,
                                          color: Garden.muted,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: c.saved.contains(word.id)
                                            ? 'Unsave word'
                                            : 'Save word',
                                        onPressed: () => c.toggleSaved(word.id),
                                        icon: Icon(
                                          c.saved.contains(word.id)
                                              ? Icons.bookmark_rounded
                                              : Icons.bookmark_outline_rounded,
                                          size: 23,
                                          color: Garden.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  key: const ValueKey(
                                    'practice-content-scroll',
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 16 : 24,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: contentHeight,
                                    ),
                                    child: back
                                        ? Column(
                                            children: [
                                              WordArtwork(
                                                word,
                                                size: pictureSize,
                                              ),
                                              SizedBox(height: gap),
                                              Tag(
                                                part,
                                                color: const Color(0xffedf1e6),
                                              ),
                                              SizedBox(height: gap),
                                              Text(
                                                word.translation,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium
                                                    ?.copyWith(
                                                      fontSize: compact
                                                          ? 28
                                                          : 36,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.15,
                                                    ),
                                              ),
                                              SizedBox(height: gap),
                                              Text(
                                                word.definition,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  height: 1.4,
                                                  color: Garden.muted,
                                                ),
                                              ),
                                              SizedBox(height: gap),
                                              Container(
                                                padding: EdgeInsets.all(
                                                  compact ? 12 : 16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xfff9faf6,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: Garden.border,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Eyebrow(
                                                          'In context',
                                                        ),
                                                        const Spacer(),
                                                        IconButton(
                                                          tooltip: 'Listen to example',
                                                          constraints:
                                                              const BoxConstraints(
                                                                minWidth: 40,
                                                                minHeight: 40,
                                                              ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          onPressed: () =>
                                                              _speak(
                                                                word,
                                                                kind: AudioKind
                                                                    .example,
                                                              ),
                                                          icon: const Icon(
                                                            Icons
                                                                .volume_up_outlined,
                                                            size: 19,
                                                            color: Garden.muted,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(
                                                      word.example,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      word.exampleTranslation,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Garden.muted,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => _details(word),
                                                child: const Text(
                                                  'Example & word details',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              if (session.result != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 10,
                                                      ),
                                                  child: Text(
                                                    _feedbackText(
                                                      word,
                                                      session,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: session.result!
                                                          ? Garden.green
                                                          : Garden.red,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          )
                                        : InkWell(
                                            onTap: c.reveal,
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Eyebrow(
                                                    'Flashcards · ${session.index + 1}',
                                                  ),
                                                  const SizedBox(height: 28),
                                                  Text(
                                                    word.term,
                                                    textAlign: TextAlign.center,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineMedium
                                                        ?.copyWith(
                                                          fontSize:
                                                              (bounds.maxWidth *
                                                                      .105)
                                                                  .clamp(
                                                                    28.0,
                                                                    48.0,
                                                                  ),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          height: 1.2,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Tag(
                                                    part,
                                                    color: const Color(
                                                      0xffe7eff5,
                                                    ),
                                                  ),
                                                  if (word
                                                          .pronunciation
                                                          ?.isNotEmpty ==
                                                      true) ...[
                                                    const SizedBox(height: 18),
                                                    Text(
                                                      word.pronunciation!,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        color: Garden.muted,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 60,
                                child: session.result != null
                                    ? Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: _actions(session),
                                      )
                                    : !back
                                    ? SizedBox(
                                        width: double.infinity,
                                        child: TextButton.icon(
                                          style: TextButton.styleFrom(
                                            backgroundColor: Garden.green,
                                            foregroundColor: Colors.white,
                                            shape:
                                                const RoundedRectangleBorder(),
                                          ),
                                          onPressed: c.reveal,
                                          icon: const Icon(
                                            Icons.flip_rounded,
                                            size: 22,
                                          ),
                                          label: const Text(
                                            'Reveal meaning',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: _recallGrade(
                                              'Practise again',
                                              Icons.refresh_rounded,
                                              false,
                                            ),
                                          ),
                                          Expanded(
                                            child: _recallGrade(
                                              'I knew it',
                                              Icons.check_rounded,
                                              true,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _recallGrade(String label, IconData icon, bool correct) => SizedBox(
    height: double.infinity,
    child: TextButton.icon(
      onPressed: () => _grade(correct),
      style: TextButton.styleFrom(
        backgroundColor: correct ? const Color(0xffe4eedb) : Garden.peach,
        foregroundColor: correct ? Garden.green : Garden.red,
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _flashcard(Word word, StudySession session) {
    final forms = session.mode == PracticeMode.forms;
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey('${session.currentId}-${session.seed}'),
          tween: Tween(begin: 0, end: session.revealed ? pi : 0),
          duration: const Duration(milliseconds: 380),
          builder: (context, angle, _) {
            final back = angle > pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .001)
                ..rotateY(angle),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..rotateY(back ? pi : 0),
                child: GardenCard(
                  color: back ? Garden.lavender : Garden.mint,
                  padding: const EdgeInsets.all(16),
                  onTap: session.result == null && !session.revealed
                      ? c.reveal
                      : null,
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Eyebrow(
                                back
                                    ? 'The meaning'
                                    : 'Give your memory a moment',
                              ),
                            ),
                            IconButton(
                              tooltip: 'Listen to word',
                              onPressed: () => _speak(word),
                              icon: const Icon(
                                Icons.volume_up_outlined,
                                size: 22,
                                color: Garden.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        WordArtwork(word, size: _artworkSize(word, session)),
                        const SizedBox(height: 12),
                        Text(
                          back
                              ? (forms ? word.term : word.translation)
                              : (forms ? word.bareTerm : word.term),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontSize: 26),
                        ),
                        const SizedBox(height: 10),
                        if (back)
                          Text(
                            forms ? word.formAnswer : word.definition,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Garden.green,
                              height: 1.5,
                            ),
                          )
                        else
                          Text(
                            forms
                                ? (word.part == 'noun'
                                      ? 'Can you recall the article and plural?'
                                      : word.part == 'verb'
                                      ? 'Can you recall the present and past forms?'
                                      : word.patterns.isNotEmpty
                                      ? 'Can you recall the preposition and case?'
                                      : 'Can you recall the word forms?')
                                : 'What does this word mean?',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Garden.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _spelling(Word word, StudySession session) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GardenCard(
        color: Garden.peach,
        padding: EdgeInsets.all(_keyboardOpen ? 12 : 16),
        child: Column(
          children: [
            const Eyebrow('Find the German word'),
            if (!_keyboardOpen) ...[
              const SizedBox(height: 8),
              WordArtwork(word, size: _artworkSize(word, session)),
              const SizedBox(height: 8),
            ],
            Text(
              word.translation,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontSize: _keyboardOpen ? 20 : 25),
            ),
            const SizedBox(height: 10),
            Text(
              word.part,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Garden.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _input,
        focusNode: _focus,
        enabled: session.result == null,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onChanged: c.saveDraft,
        onSubmitted: (v) {
          if (v.trim().isNotEmpty && session.result == null) {
            _grade(word.accepts(v));
          }
        },
        decoration: const InputDecoration(hintText: 'Type the German word…'),
      ),
      if (session.result == null) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            for (final ch in ['ä', 'ö', 'ü', 'ß'])
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: SizedBox(
                  width: 43,
                  height: 37,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => _insert(ch),
                    child: Text(ch),
                  ),
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _hint = true),
              child: const Text('Hint', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        if (_hint)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Text(
              'Starts with “${word.bareTerm[0]}” · ${word.bareTerm.length} letters',
              style: const TextStyle(fontSize: 12, color: Garden.green),
            ),
          ),
      ],
    ],
  );
  Widget _quiz(Word word, StudySession session) {
    final sentence = session.index.isOdd ? _context(word) : null;
    final answer = sentence == null ? word.translation : word.bareTerm;
    final options = c.quizOptions(word, context: sentence != null);
    return Column(
      children: [
        GardenCard(
          color: Garden.lavender,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Eyebrow(
                sentence == null
                    ? 'Choose the meaning'
                    : 'Complete the sentence',
              ),
              const SizedBox(height: 6),
              WordArtwork(word, size: _artworkSize(word, session)),
              const SizedBox(height: 8),
              Text(
                sentence ?? word.term,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: sentence == null ? 24 : 20),
              ),
              const SizedBox(height: 8),
              if (sentence == null) ...[
                Text(
                  word.example,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                sentence == null
                    ? 'Which meaning fits this word?'
                    : word.exampleTranslation,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Garden.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GardenCard(
              color: session.result != null && options[i] == answer
                  ? Garden.mint
                  : session.result == false && session.answer == options[i]
                  ? Garden.peach
                  : Colors.white,
              padding: const EdgeInsets.all(11),
              onTap: session.result != null
                  ? null
                  : () {
                      c.saveDraft(options[i]);
                      _grade(options[i] == answer);
                    },
              child: Row(
                children: [
                  Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: Garden.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + i),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Garden.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      options[i],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (session.result != null && options[i] == answer)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 19,
                      color: Garden.green,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _summary(StudySession session) {
    final correct = session.results.values.where((v) => v).length;
    final failures = [
      for (final entry in session.results.entries)
        if (!entry.value) c.catalog.words[entry.key]!,
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close session',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (failures.isNotEmpty) ...[
                FilledButton.icon(
                  onPressed: () {
                    c.startSession(
                      failures,
                      session.mode,
                      '${session.title} · retry',
                    );
                    _input.clear();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('Revisit ${failures.length} tricky words'),
                ),
                const SizedBox(height: 12),
              ],
              if (session.mode == PracticeMode.review) ...[
                FilledButton(
                  onPressed: () => c.startSession(
                    [for (final id in session.wordIds) c.catalog.words[id]!],
                    PracticeMode.flashcards,
                    session.title,
                    lessonId: session.lessonId,
                  ),
                  child: const Text('Try these as flashcards'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: () {
                  c.session = null;
                  c.changed();
                  Navigator.pop(context);
                },
                child: const Text('Back to my words'),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          children: [
            const Center(
              child: GardenIllustration(
                'garden-achievement',
                width: 160,
                height: 125,
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: Eyebrow('Look at you grow')),
            const SizedBox(height: 12),
            Text(
              session.mode == PracticeMode.review
                  ? 'A few more words\nin your world.'
                  : 'Another little\nwin for your German.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 15),
            Text(
              session.mode == PracticeMode.review
                  ? 'You explored ${session.wordIds.length} words. Try recalling them with flashcards next.'
                  : 'You recalled $correct of ${session.wordIds.length} words. Every revisit helps them stick.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Garden.muted,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            GardenCard(
              color: Garden.mint,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${session.wordIds.length}',
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'words practised',
                        style: TextStyle(fontSize: 10, color: Garden.muted),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${c.todayCount}/${c.goal}',
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'daily goal',
                        style: TextStyle(fontSize: 10, color: Garden.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
