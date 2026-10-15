import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'theme.dart';
import 'widgets.dart';

class AppReviewLink extends StatefulWidget {
  const AppReviewLink({super.key, required this.controller});
  final AppController controller;

  @override
  State<AppReviewLink> createState() => _AppReviewLinkState();
}

class _AppReviewLinkState extends State<AppReviewLink> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    final opened = await widget.controller.openStoreReview();
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) {
      toast(context, 'The store could not be opened. Try again later.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.reviews.supported) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.star_outline_rounded, color: Garden.green),
      title: const Text(
        'Rate Wortgarten',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'Share your experience on the store.',
        style: TextStyle(fontSize: 12, color: Garden.muted),
      ),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: _opening ? null : _open,
    );
  }
}
