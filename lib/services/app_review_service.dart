import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

abstract class AppReviewClient {
  bool get supported;
  Future<bool> isAvailable();
  Future<void> requestReview();
  Future<void> openStoreListing();
}

class NativeAppReviewClient implements AppReviewClient {
  static const appStoreId = '6821670098';

  @override
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.iOS,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform);

  @override
  Future<bool> isAvailable() async =>
      supported && await InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();

  @override
  Future<void> openStoreListing() =>
      InAppReview.instance.openStoreListing(appStoreId: appStoreId);
}

/// Local engagement and request attempts, never a claim that a review was left.
class AppReviewHistory {
  final studyDays = <String>{};
  final attempts = <DateTime>[];
  DateTime? lastStoreVisit;

  void restore(Map<String, dynamic>? json) {
    studyDays.clear();
    attempts.clear();
    for (final value in json?['studyDays'] as List? ?? const []) {
      if (value is String && DateTime.tryParse(value) != null) {
        studyDays.add(value);
      }
    }
    for (final value in json?['attempts'] as List? ?? const []) {
      final date = value is String ? DateTime.tryParse(value) : null;
      if (date != null) attempts.add(date);
    }
    lastStoreVisit = DateTime.tryParse(
      json?['lastStoreVisit'] as String? ?? '',
    );
  }

  bool eligible(DateTime now, int completedSessions) {
    if (studyDays.where((day) => !DateTime.parse(day).isAfter(now)).length <
            3 ||
        completedSessions < 3) {
      return false;
    }
    final recent = attempts.where(
      (date) => now.difference(date) < const Duration(days: 365),
    );
    if (recent.length >= 3) return false;
    return [
      ...attempts,
      ?lastStoreVisit,
    ].every((date) => now.difference(date) >= const Duration(days: 90));
  }

  Map<String, dynamic> toJson() => {
    'studyDays': studyDays.toList()..sort(),
    'attempts': attempts.map((date) => date.toIso8601String()).toList(),
    'lastStoreVisit': lastStoreVisit?.toIso8601String(),
  };
}
