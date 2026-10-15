import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/vocabulary.dart';
import '../state/app_controller.dart';
import 'theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: Image.asset(
        'assets/brand/wortgarten-v1.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    ),
  );
}

class GardenIllustration extends StatelessWidget {
  const GardenIllustration(
    this.name, {
    super.key,
    this.width = 150,
    this.height = 150,
  });
  final String name;
  final double width, height;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/generated/$name-v1.png',
    width: width,
    height: height,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.medium,
    cacheWidth: (width * 3).round(),
  );
}

class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.color = Garden.mint,
    this.foregroundColor = Garden.green,
    this.size = 42,
  });
  final IconData icon;
  final Color color;
  final Color foregroundColor;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(icon, color: foregroundColor, size: size * .52),
  );
}

class Artwork extends StatelessWidget {
  const Artwork(
    this.kind, {
    super.key,
    this.size = 90,
    this.height,
    this.assetPath,
    this.framed = false,
  });
  final String kind;
  final double size;
  final double? height;
  final String? assetPath;
  final bool framed;
  @override
  Widget build(BuildContext context) {
    Widget fallback() =>
        SvgPicture.asset('assets/artwork/$kind.svg', fit: BoxFit.contain);
    return ExcludeSemantics(
      child: _ArtworkFrame(
        width: size,
        height: height ?? size * .78,
        framed: framed,
        child: assetPath == null
            ? fallback()
            : Image.asset(
                assetPath!,
                fit: BoxFit.contain,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .ceil()
                    .clamp(1, 512),
                errorBuilder: (_, _, _) => fallback(),
              ),
      ),
    );
  }
}

class WordArtwork extends StatelessWidget {
  const WordArtwork(
    this.word, {
    super.key,
    this.size = 100,
    this.enlargeable = false,
  });
  final Word word;
  final double size;
  final bool enlargeable;
  @override
  Widget build(BuildContext context) {
    final image = ExcludeSemantics(
      child: _ArtworkFrame(
        width: size,
        height: size,
        framed: true,
        child: word.imageAsset == null
            ? Artwork(word.artwork, size: size, height: size)
            : Image.asset(
                word.imageAsset!,
                fit: BoxFit.contain,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .ceil()
                    .clamp(1, 512),
                errorBuilder: (_, _, _) =>
                    Artwork(word.artwork, size: size, height: size),
              ),
      ),
    );
    if (!enlargeable) return image;
    return Semantics(
      button: true,
      label: 'Enlarge image of ${word.term}',
      child: Tooltip(
        message: 'Enlarge image',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showArtworkPreview(context, word),
          child: Stack(
            children: [
              image,
              Positioned(
                bottom: 8,
                right: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.open_in_full_rounded,
                      size: 17,
                      color: Garden.green,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkFrame extends StatelessWidget {
  const _ArtworkFrame({
    required this.width,
    required this.height,
    required this.child,
    required this.framed,
  });
  final double width, height;
  final Widget child;
  final bool framed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: framed
        ? ClipRRect(
            borderRadius: BorderRadius.circular(width < 100 ? 14 : 20),
            child: ColoredBox(color: Garden.background, child: child),
          )
        : child,
  );
}

void showArtworkPreview(BuildContext context, Word word) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Close image preview',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
            title: Text(word.term),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 3,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: WordArtwork(
                          word,
                          size: MediaQuery.sizeOf(context).width - 36,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        word.translation,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pinch to zoom',
                        style: TextStyle(fontSize: 12, color: Garden.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

class GardenCard extends StatelessWidget {
  const GardenCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.borderColor = Garden.border,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });
  final Widget child;
  final Color color;
  final Color borderColor;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: borderColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = Garden.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      color: color,
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = Garden.mint});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Garden.ink,
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          child: Text(
            action!,
            style: const TextStyle(fontSize: 12, color: Garden.green),
          ),
        ),
    ],
  );
}

class LessonTile extends StatelessWidget {
  const LessonTile({
    super.key,
    required this.lesson,
    required this.controller,
    required this.onTap,
  });
  final Lesson lesson;
  final AppController controller;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final value = controller.lessonProgress(lesson);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GardenCard(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Garden.pastel(lesson.color),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Artwork(
                lesson.artwork,
                size: 92,
                height: 92,
                framed: true,
                assetPath: controller.catalog.topicImages[lesson.artwork],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lesson.germanTitle,
                    style: const TextStyle(fontSize: 11, color: Garden.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${lesson.wordIds.length} words',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Garden.muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${lesson.level}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Garden.green,
                        ),
                      ),
                      if (value > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${(value * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Garden.green,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Garden.muted,
              size: 20,
            ),
            if (!controller.canAccessLesson(lesson)) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.lock_outline_rounded,
                color: Garden.goldInk,
                size: 15,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData modeIcon(PracticeMode mode) => switch (mode) {
  PracticeMode.review => Icons.menu_book_rounded,
  PracticeMode.flashcards => Icons.style_outlined,
  PracticeMode.spelling => Icons.edit_outlined,
  PracticeMode.quiz => Icons.quiz_outlined,
  PracticeMode.forms => Icons.category_outlined,
};

class EmptyGarden extends StatelessWidget {
  const EmptyGarden(
    this.title,
    this.description, {
    super.key,
    this.artwork = 'growth',
    this.action,
  });
  final String title, description, artwork;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 26),
    child: Column(
      children: [
        Artwork(artwork, size: 150),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 9),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Garden.muted, height: 1.6),
        ),
        if (action != null) ...[const SizedBox(height: 22), action!],
      ],
    ),
  );
}

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class PageHeader extends StatelessWidget {
  const PageHeader(
    this.title,
    this.subtitle, {
    super.key,
    this.trailing,
    this.compact = false,
  });
  final String title, subtitle;
  final Widget? trailing;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: compact ? 4 : 10, bottom: compact ? 14 : 26),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(fontSize: compact ? 26 : 34),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  color: Garden.muted,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
