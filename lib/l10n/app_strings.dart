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

  static String get ttsSection => _t('Voce e lettura', 'Voice & narration');
  static String get ttsEnabledTitle =>
      _t('Lettura ad alta voce', 'Read aloud');
  static String get ttsEnabledSubtitle => _t(
      'Attiva il pulsante 🔊 nei pannelli per ascoltare i dialoghi',
      'Enables the 🔊 button on panels to hear the dialogue');
  static String get ttsAutoplayTitle =>
      _t('Avvio automatico', 'Auto play');
  static String get ttsAutoplaySubtitle => _t(
      'Inizia la lettura non appena apri una pagina',
      'Start reading as soon as you open a page');
  static String get ttsPlayTooltip =>
      _t('Leggi ad alta voce', 'Read aloud');
  static String get ttsStopTooltip =>
      _t('Ferma la lettura', 'Stop reading');

  // === Ask Favilla ===
  static String get askFavillaTitle =>
      _t('Chiedi a Favilla', 'Ask Favilla');
  static String get askFavillaSubtitle => _t(
      'Chatta con la supermamma in persona',
      'Chat with the supermom herself');
  static String get askFavillaHint =>
      _t('Scrivi a Favilla…', 'Write to Favilla…');
  static String get askFavillaSend => _t('Invia', 'Send');
  static String get askFavillaEmptyState => _t(
      'Sta a Favilla scegliere se rispondere con saggezza, sarcasmo o entrambi.\nIniziamo?',
      'Favilla decides whether to answer with wisdom, sarcasm, or both.\nLet\'s start?');
  static String get askFavillaThinking =>
      _t('Favilla sta pensando…', 'Favilla is thinking…');
  static String get askFavillaNewChat =>
      _t('Nuova conversazione', 'New conversation');
  static String get askFavillaNewChatConfirm => _t(
      'Cancellare la conversazione attuale?',
      'Delete the current conversation?');
  static String askFavillaQuotaLeft(int n) => _t(
      'Quota di oggi: $n risposte rimanenti',
      'Today\'s quota: $n replies left');
  static String get askFavillaQuotaExceeded => _t(
      'Hai esaurito le domande di oggi. Torna domani! 💫',
      'You used all of today\'s questions. Come back tomorrow! 💫');
  static String get askFavillaError => _t(
      'Favilla è impegnata in una missione. Riprova tra poco.',
      'Favilla is busy with a mission. Try again shortly.');
  static String get askFavillaDisabled => _t(
      'AI non disponibile in questa build.',
      'AI not available in this build.');
  static String get askFavillaSafetyDeflect => _t(
      'Mmh, su questo non posso aiutarti. Cambiamo storia?',
      'Hmm, can\'t help with that. Let\'s change story?');

  // === AI Hub ===
  static String get aiHubTitle => _t('Studio AI', 'AI Studio');
  static String get aiHubIntro => _t(
      'Esperienze interattive con la voce e l\'estro di Favilla, generate al volo dall\'AI.',
      'Interactive experiences with Favilla\'s voice and flair, generated on the fly by AI.');

  // === Mission generator ===
  static String get missionTitle =>
      _t('Genera missione', 'Generate mission');
  static String get missionSubtitle => _t(
      'Trasforma il tuo caos quotidiano in un mini-fumetto.',
      'Turn your daily chaos into a mini comic.');
  static String get missionMyCollection =>
      _t('Le mie missioni', 'My missions');
  static String get missionMyCollectionSubtitle => _t(
      'Riapri o condividi le missioni che hai salvato.',
      'Reopen or share the missions you saved.');
  static String get missionIntro => _t(
      'Descrivi una scena vera della tua giornata. Favilla la trasformerà in un mini-fumetto in 3-4 pannelli.',
      'Describe a real scene from your day. Favilla will turn it into a 3-4 panel mini comic.');
  static String get missionInputHint => _t(
      'Es. "I bambini non vogliono dormire e tirano i cuscini"',
      'E.g. "The kids refuse to sleep and throw pillows"');
  static String get missionGenerate =>
      _t('Genera missione', 'Generate mission');
  static String get missionGenerating =>
      _t('Favilla sta scrivendo…', 'Favilla is writing…');
  static String missionPanelLabel(int i, int total) => _t(
      'PANNELLO $i / $total', 'PANEL $i / $total');
  static String get missionSave => _t('Salva', 'Save');
  static String get missionSavedShort => _t('Salvata', 'Saved');
  static String get missionSaved =>
      _t('Missione salvata nella collezione.', 'Mission saved to collection.');
  static String get missionDeleteConfirm => _t(
      'Eliminare questa missione?', 'Delete this mission?');
  static String get missionCollectionEmpty => _t(
      'Non hai ancora salvato missioni. Generane una!',
      'No saved missions yet. Generate one!');
  static String missionFromSituation(String s) => _t(
      'Dalla situazione: $s', 'From situation: $s');
  static String missionQuotaLeft(int n) => _t(
      'Quota di oggi: $n missioni rimanenti',
      'Today\'s quota: $n missions left');
  static String get missionQuotaExceeded => _t(
      'Hai esaurito le missioni di oggi. Torna domani! ✨',
      'You used all today\'s missions. Come back tomorrow! ✨');
  static String get missionError => _t(
      'Favilla è impegnata. Riprova tra poco.',
      'Favilla is busy. Try again shortly.');
  static String get missionSituationTooShort => _t(
      'Aggiungi qualche dettaglio in più sulla situazione.',
      'Add a little more detail to the situation.');

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
