import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/vocabulary.dart';
import 'services/progress_storage.dart';
import 'services/billing_factory.dart';
import 'state/app_controller.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';
import 'ui/garden_motion.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Garden.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  // Decode the brand before the animated splash's first frame. The platform
  // shows only a matching background while Flutter is starting.
  await _warmBrandMark();
  runApp(const WortgartenApp());
  binding.addPostFrameCallback((_) => binding.allowFirstFrame());
}

Future<void> _warmBrandMark() async {
  final ready = Completer<void>();
  final stream = const AssetImage('assets/brand/wortgarten-v1.png')
      .resolve(const ImageConfiguration());
  final listener = ImageStreamListener(
    (image, _) {
      image.dispose();
      if (!ready.isCompleted) ready.complete();
    },
    onError: (_, _) {
      if (!ready.isCompleted) ready.complete();
    },
  );
  stream.addListener(listener);
  try {
    await ready.future;
  } finally {
    stream.removeListener(listener);
  }
}

class WortgartenApp extends StatefulWidget {
  const WortgartenApp({super.key, this.controller, this.showSplash});
  final AppController? controller;

  /// Allows the real startup transition to be exercised with preview/test data.
  final bool? showSplash;
  @override
  State<WortgartenApp> createState() => _WortgartenAppState();
}

class _WortgartenAppState extends State<WortgartenApp> {
  AppController? _controller;
  bool _failed = false;
  bool _splash = true;
  @override
  void initState() {
    super.initState();
    _splash = widget.showSplash ?? widget.controller == null;
    _load();
  }

  Future<void> _load() async {
    try {
      final purchases = widget.controller == null
          ? createBillingController()
          : null;
      final controller =
          widget.controller ??
          AppController(
            catalog: await Catalog.load(),
            storage: LocalProgressStorage(),
            purchases: purchases,
          );
      if (widget.controller == null) await controller.load();
      if (purchases != null) unawaited(purchases.initialize());
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Wortgarten · German vocabulary',
    debugShowCheckedModeBanner: false,
    theme: Garden.theme,
    builder: (context, child) {
      final media = MediaQuery.of(context);
      final tablet = media.size.shortestSide >= 700;
      return ColoredBox(
        color: const Color(0xFFEEF0E8),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tablet ? 1080 : 600),
            child: MediaQuery(
              data: tablet
                  ? media.copyWith(
                      textScaler: media.textScaler.scale(1) < 1.15
                          ? const TextScaler.linear(1.15)
                          : media.textScaler,
                    )
                  : media,
              child: child!,
            ),
          ),
        ),
      );
    },
    home: Stack(
      fit: StackFit.expand,
      children: [
        if (_controller != null)
          ExcludeFocus(
            excluding: _splash,
            child: ExcludeSemantics(
              excluding: _splash,
              child: IgnorePointer(
                ignoring: _splash,
                child: AppShell(controller: _controller!),
              ),
            ),
          ),
        if (_splash || _controller == null)
          SplashScreen(
            key: const ValueKey('startup-splash'),
            ready: _controller != null,
            failed: _failed,
            onFinished: () {
              if (mounted) setState(() => _splash = false);
            },
            onRetry: () {
              setState(() => _failed = false);
              _load();
            },
          ),
      ],
    ),
  );
}
