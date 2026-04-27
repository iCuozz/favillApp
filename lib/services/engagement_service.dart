import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

class EngagementService {
  static const String packageId = 'it.cuozzo.favilla';
  static const String _kReviewRequested = 'engagement.reviewRequested';
  static const String _kCompletedCount = 'engagement.completedCount';
  static const int _reviewThreshold = 2;

  static String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$packageId';

  static Future<void> shareApp() async {
    await Share.share(
      AppStrings.shareAppMessage(playStoreUrl),
      subject: 'Favilla Blaze',
    );
  }

  static Future<void> shareEpisode(String episodeTitle) async {
    await Share.share(
      AppStrings.shareEpisodeMessage(episodeTitle, playStoreUrl),
      subject: 'Favilla Blaze - $episodeTitle',
    );
  }

  /// Da chiamare quando l'utente completa un episodio. Mostra il prompt
  /// nativo di review dopo [_reviewThreshold] episodi completati,
  /// una sola volta.
  static Future<void> onEpisodeCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kReviewRequested) ?? false) return;

    final count = (prefs.getInt(_kCompletedCount) ?? 0) + 1;
    await prefs.setInt(_kCompletedCount, count);

    if (count < _reviewThreshold) return;

    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await prefs.setBool(_kReviewRequested, true);
      await inAppReview.requestReview();
    }
  }

  static Future<void> openStoreListing() async {
    final inAppReview = InAppReview.instance;
    await inAppReview.openStoreListing(appStoreId: packageId);
  }
}
