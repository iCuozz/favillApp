import '../services/settings_service.dart';

/// Localizzazione leggera basata su ValueNotifier in SettingsService.language.
/// Usare con `ValueListenableBuilder(valueListenable: SettingsService.language, ...)`
/// per reagire al cambio runtime della lingua.
class AppStrings {
  static AppLanguage get _lang => SettingsService.language.value;

  static String _t(String it, String en) =>
      _lang == AppLanguage.english ? en : it;

  static String get tapToStart => _t('Inizia', 'Start');
  static String get appTagline => _t(
      'La supermamma che combatte il caos quotidiano tra scuola, pannolini, bug domestici e missioni impossibili.',
      'The supermom who fights daily chaos between school, diapers, household bugs and impossible missions.');
  static String continueLabel(String episodeTitle) =>
      _t('Continua: $episodeTitle', 'Continue: $episodeTitle');
  static String get settings => _t('Impostazioni', 'Settings');

  static String get episodesTitle => _t('Tutti gli episodi', 'All episodes');
  static String get completed => _t('Completato', 'Completed');
  static String get toBeContinued => _t('Continua…', 'To be continued…');
  static String get newEpisodesSoon =>
      _t('Nuovi episodi in arrivo', 'New episodes coming soon');

  static String pageOf(int current, int total) =>
      _t('Pagina $current/$total', 'Page $current/$total');
  static String get tapToContinue =>
      _t('Tocca per continuare', 'Tap to continue');
  static String get jumpToPage => _t('Salta a pagina', 'Jump to page');
  static String get episodeCompletedTitle =>
      _t('Missione completata', 'Mission complete');
  static String episodeCompletedBody(String title) =>
      _t('Hai completato "$title".', 'You completed "$title".');
  static String get share => _t('Condividi', 'Share');
  static String get backToEpisodes =>
      _t('Torna agli episodi', 'Back to episodes');
  static String get hapticsTooltip => _t('Vibrazione', 'Haptics');

  static String get readingSection => _t('Lettura', 'Reading');
  static String get hapticsTitle => _t('Vibrazione al tap', 'Tap haptics');
  static String get hapticsSubtitle => _t(
      'Piccola vibrazione quando appare un dialogo',
      'Small vibration when a dialogue appears');
  static String get fullscreenTitle =>
      _t('Lettura a schermo intero', 'Fullscreen reading');
  static String get fullscreenSubtitle => _t(
      'Nasconde le barre di sistema durante la lettura',
      'Hides system bars while reading');
  static String get textSpeedTitle =>
      _t('Velocità del testo', 'Text speed');

  static String get languageSection => _t('Lingua', 'Language');
  static String get languageTitle => _t('Lingua', 'Language');
  static String get languageSubtitle => _t(
      'Cambia la lingua dell\'app e dei fumetti',
      'Change app and comic language');

  static String get shareSection => _t('Condividi', 'Share');
  static String get shareApp => _t('Condividi l\'app', 'Share the app');
  static String get shareAppSubtitle => _t(
      'Invita i tuoi amici a leggere Favilla Blaze',
      'Invite your friends to read Favilla Blaze');
  static String get rateApp =>
      _t('Lascia una recensione', 'Leave a review');
  static String get rateAppSubtitle => _t(
      'Apri la scheda sul Play Store', 'Open the Play Store listing');

  static String get progressSection => _t('Progresso', 'Progress');
  static String get resetProgress =>
      _t('Azzera il progresso', 'Reset progress');
  static String get resetProgressSubtitle => _t(
      'Cancella episodi completati e ripresa lettura',
      'Clear completed episodes and resume position');
  static String get resetProgressConfirmTitle =>
      _t('Sicuro?', 'Are you sure?');
  static String get resetProgressConfirmBody => _t(
      'Tutti i progressi verranno cancellati. Vuoi continuare?',
      'All progress will be deleted. Continue?');
  static String get resetProgressDone =>
      _t('Progresso azzerato', 'Progress reset');
  static String get cancel => _t('Annulla', 'Cancel');
  static String get ok => _t('OK', 'OK');
  static String get reset => _t('Azzera', 'Reset');

  static String get infoSection => _t('Informazioni', 'About');
  static String get version => _t('Versione', 'Version');

  static String shareAppMessage(String url) => _t(
      'Sto leggendo Favilla Blaze, il fumetto interattivo della supermamma! Scaricalo gratis: $url',
      'I\'m reading Favilla Blaze, the supermom interactive comic! Get it free: $url');
  static String shareEpisodeMessage(String title, String url) => _t(
      'Ho appena letto "$title" su Favilla Blaze! 🦸‍♀️ Provalo anche tu: $url',
      'I just read "$title" on Favilla Blaze! 🦸‍♀️ Try it too: $url');
}
