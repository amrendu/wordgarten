import 'package:flutter/material.dart';

import '../../models/vocabulary.dart';
import '../../services/speech_service.dart';
import '../../state/app_controller.dart';
import '../garden_motion.dart';
import '../theme.dart';
import '../widgets.dart';
import 'paywall_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.controller,
    this.onFinished,
  });
  final AppController controller;
  final VoidCallback? onFinished;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _revealed = false, _graded = false, _finishing = false, _playing = false;
  final _speech = SpeechService();
  AppController get c => widget.controller;
  Word get _word => c.catalog.words['guten-morgen']!;
  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _speech.stop();
    setState(() => _finishing = true);
    if (!c.premium) {
      await showPaywall(context, c, reason: 'Keep growing at your own pace.');
    }
    if (mounted) {
      c.finishOnboarding();
      widget.onFinished?.call();
    }
  }

  Future<void> _listen() async {
    if (_playing) {
      await _speech.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    final result = await _speech.playWord(_word, rate: c.speechRate);
    if (!mounted) return;
    setState(() => _playing = false);
    if (result == PlaybackResult.failed) {
      toast(context, 'Audio is unavailable right now. You can still practise.');
    }
  }

  void _grade(bool success) {
    if (_graded) return;
    c.recordMiniLesson(_word, success);
    setState(() => _graded = true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 16, 12),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      tooltip: 'Previous onboarding step',
                      onPressed: _finishing
                          ? null
                          : () => setState(() {
                              _step--;
                            }),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  const BrandMark(size: 32),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'wortgarten',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.6,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finishing
                        ? null
                        : () {
                            _speech.stop();
                            c.finishOnboarding();
                            widget.onFinished?.call();
                          },
                    child: const Text('Skip', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step ? Garden.green : Garden.mint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('onboarding-content'),
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: switch (_step) {
                      0 => _intro(context),
                      1 => _preferences(context),
                      _ => _sample(context),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_step == 2 && _revealed && !_graded)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _grade(false),
                        child: const Text('Practise again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _grade(true),
                        child: const Text('I knew it'),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _finishing
                        ? null
                        : () {
                            if (_step < 2) {
                              setState(() => _step++);
                            } else if (!_revealed) {
                              setState(() => _revealed = true);
                            } else {
                              _finish();
                            }
                          },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      _step == 0
                          ? 'Start growing'
                          : _step == 1
                          ? 'Try my first word'
                          : !_revealed
                          ? 'Reveal meaning'
                          : 'Continue',
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              const Text(
                'A free topic at every level · No account needed',
                style: TextStyle(fontSize: 10, color: Garden.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _intro(BuildContext context) => Column(
    children: [
      GrowingGarden(size: MediaQuery.sizeOf(context).height < 740 ? 230 : 290),
      const Eyebrow('A little German. Every day.'),
      const SizedBox(height: 12),
      Text(
        'Small words.\nDeep roots.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge
            ?.copyWith(fontSize: 32),
      ),
      const SizedBox(height: 12),
      const Text(
        'See a word. Hear it. Make it yours.\nGrow your German from A1 to C1.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Garden.muted),
      ),
      const SizedBox(height: 22),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (icon, label) in [
            (Icons.image_outlined, 'Pictures'),
            (Icons.volume_up_outlined, 'Audio'),
            (Icons.style_outlined, 'Practice'),
          ])
            Expanded(
              child: Column(
                children: [
                  IconBadge(icon, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Garden.green),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );
  Widget _preferences(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: const GardenIllustration(
          'garden-achievement',
          width: 135,
          height: 120,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Your level.\nYour little daily ritual.',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontSize: 28),
      ),
      const SizedBox(height: 10),
      const Text(
        'Choose a starting point. You can change it anytime.',
        style: TextStyle(fontSize: 13, color: Garden.muted),
      ),
      const SizedBox(height: 22),
      const Eyebrow('Where are you starting?'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 7,
        runSpacing: 8,
        children: [
          for (final level in levels)
            ChoiceChip(
              label: Text(level),
              selected: c.level == level,
              showCheckmark: false,
              selectedColor: Garden.green,
              labelStyle: TextStyle(
                color: c.level == level ? Colors.white : Garden.ink,
              ),
              onSelected: (_) {
                c.chooseLevel(level);
                setState(() {
                  _revealed = false;
                  _graded = false;
                });
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(switch (c.level) {
        'A1' => 'First words & everyday essentials',
        'A2' => 'Routines, travel & working life',
        'B1' => 'Experiences, decisions & opinions',
        'B2' => 'Arguments, society & the environment',
        _ => 'Nuance, academic & professional German',
      }, style: const TextStyle(fontSize: 12, color: Garden.green)),
      const SizedBox(height: 24),
      const Eyebrow('Words each day'),
      const SizedBox(height: 10),
      Row(
        children: [
          for (final goal in [5, 10, 15, 20]) ...[
            if (goal != 5) const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: SizedBox(
                  width: double.infinity,
                  child: Text('$goal', textAlign: TextAlign.center),
                ),
                selected: c.goal == goal,
                showCheckmark: false,
                selectedColor: Garden.mint,
                onSelected: (_) => c.setGoal(goal),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 14),
      const Text(
        'A few minutes today. A little more confidence tomorrow.',
        style: TextStyle(fontSize: 12, color: Garden.muted),
      ),
    ],
  );
  Widget _sample(BuildContext context) => Column(
    children: [
      const Eyebrow('Your first little win'),
      const SizedBox(height: 10),
      Text(
        _graded
            ? 'You planted your first word.'
            : 'Meet a word. Make it stick.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontSize: 26),
      ),
      const SizedBox(height: 18),
      Stack(
        children: [
          Positioned.fill(
            child: Transform.rotate(
              angle: .025,
              child: Container(
                margin: const EdgeInsets.only(top: 6, left: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffe4e9dc),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          GardenCard(
            color: Colors.white,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Tag('A1 · ${_word.part}', color: const Color(0xffe7eff5)),
                    const Spacer(),
                    IconButton(
                      tooltip: _playing
                          ? 'Stop pronunciation'
                          : 'Listen to pronunciation',
                      onPressed: _listen,
                      icon: Icon(
                        _playing
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_outlined,
                        color: Garden.muted,
                      ),
                    ),
                  ],
                ),
                if (!_revealed)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height < 740
                          ? 200
                          : 280,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _word.term,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if (_word.pronunciation?.isNotEmpty == true) ...[
                              const SizedBox(height: 18),
                              Text(
                                _word.pronunciation!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Garden.muted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            const Text(
                              'What does this word mean?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Garden.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  WordArtwork(
                    _word,
                    size: MediaQuery.sizeOf(context).height < 740 ? 140 : 200,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _word.translation,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _word.term,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Garden.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _word.definition,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Garden.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xfff9faf6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Garden.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('In context'),
                        const SizedBox(height: 10),
                        Text(
                          _word.example,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _word.exampleTranslation,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Garden.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        _graded
            ? 'A small beginning is still a beginning. Keep growing.'
            : _revealed
            ? 'Picture it, read it, then try to remember it.'
            : 'Listen, take a moment, then reveal the meaning.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Garden.muted),
      ),
    ],
  );
}
