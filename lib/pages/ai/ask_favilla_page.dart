import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/ai/ai_client.dart';
import '../../services/ai/ai_rate_limiter.dart';
import '../../services/ai/ask_favilla_service.dart';
import '../../services/inbox_service.dart';
import '../../services/settings_service.dart';
import '../../services/tts/tts_service.dart';
import 'inbox_page.dart';

class AskFavillaPage extends StatefulWidget {
  const AskFavillaPage({super.key});

  @override
  State<AskFavillaPage> createState() => _AskFavillaPageState();
}

class _AskFavillaPageState extends State<AskFavillaPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AskFavillaService _service = AskFavillaService.instance;

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  int _remaining = 20;
  String? _errorBanner;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final history = await _service.loadHistory();
    final remaining = await _service.limiter.remaining();
    if (!mounted) return;
    setState(() {
      _messages = history;
      _remaining = remaining;
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? overrideText]) async {
    if (_sending) return;
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty) return;

    if (!AiClient.instance.enabled) {
      setState(() => _errorBanner = AppStrings.askFavillaDisabled);
      return;
    }

    SettingsService.tapFeedback();
    setState(() {
      _sending = true;
      _errorBanner = null;
      _messages = [..._messages, ChatMessage(role: ChatRole.user, text: text)];
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final reply = await _service.send(
        userMessage: text,
        currentHistory: _messages.sublist(0, _messages.length - 1),
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, reply];
      });
      _remaining = await _service.limiter.remaining();
      if (mounted) setState(() {});
    } on AiQuotaExceeded {
      if (!mounted) return;
      setState(() {
        _errorBanner = AppStrings.askFavillaQuotaExceeded;
        _messages = _messages.sublist(0, _messages.length - 1);
      });
    } on AiException catch (e) {
      if (!mounted) return;
      String banner;
      if (e.code == 'ai_disabled') {
        banner = AppStrings.askFavillaDisabled;
      } else if (e.code == 'quota_exceeded') {
        banner = AppStrings.askFavillaQuotaExceeded;
      } else {
        banner = AppStrings.askFavillaError;
        assert(() {
          banner = '${AppStrings.askFavillaError}\n[debug: ${e.code} '
              '${e.status ?? ''} ${e.message}]';
          return true;
        }());
      }
      setState(() {
        _errorBanner = banner;
        // Manteniamo il messaggio utente in cronologia (non lo rimuoviamo):
        // così l'utente vede che la sua domanda è registrata e può usare
        // la CTA "Chiedi a Favilla reale" come fallback. Solo per quota
        // esaurita rimuoviamo il msg, perché in quel caso il fallback
        // non aggiunge valore (si è già speso il tentativo).
        if (e.code == 'quota_exceeded' || e.code == 'ai_disabled') {
          _messages = _messages.sublist(0, _messages.length - 1);
        }
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _confirmNewChat() async {
    SettingsService.tapFeedback();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.askFavillaNewChatConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.reset),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.clearHistory();
    if (!mounted) return;
    setState(() => _messages = []);
  }

  void _speak(String text) {
    SettingsService.tapFeedback();
    if (TtsService.instance.isSpeaking.value) {
      TtsService.instance.stop();
    } else {
      TtsService.instance
          .speakAsFavilla(text, language: SettingsService.language.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.askFavillaTitle),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: InboxService.instance.unreadCount,
            builder: (context, unread, _) {
              return IconButton(
                tooltip: AppStrings.inboxOpenTooltip,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.mail_outline),
                    if (unread > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  SettingsService.tapFeedback();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const InboxPage(),
                  ));
                },
              );
            },
          ),
          IconButton(
            tooltip: AppStrings.askRealCta,
            icon: const Icon(Icons.auto_awesome),
            color: Colors.amberAccent.shade100,
            onPressed: _openSendToRealSheetStandalone,
          ),
          IconButton(
            tooltip: AppStrings.askFavillaNewChat,
            icon: const Icon(Icons.refresh),
            onPressed: _messages.isEmpty ? null : _confirmNewChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorBanner != null)
              Container(
                width: double.infinity,
                color: Colors.redAccent.withAlpha(40),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorBanner!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _errorBanner = null),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_messages.isEmpty ? _buildEmpty() : _buildList()),
            ),
            _buildQuota(),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final suggestions = _service.suggestions();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🦸‍♀️',
            style: TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.askFavillaEmptyState,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map((s) => ActionChip(
                      label: Text(s),
                      onPressed: _sending ? null : () => _send(s),
                    ))
                .toList(),
          ),
          const SizedBox(height: 32),
          _buildAskRealCard(),
        ],
      ),
    );
  }

  Widget _buildAskRealCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.shade700.withAlpha(60),
            Colors.deepOrange.shade400.withAlpha(60),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amberAccent.shade100, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.askRealCta,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.amberAccent.shade100,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.askRealEmptyHint,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey.shade300,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: () => _openSendToRealSheetStandalone(),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(AppStrings.askRealCta),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSendToRealSheetStandalone() async {
    SettingsService.tapFeedback();
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _SendToRealSheet(
        question: '',
        aiAnswer: null,
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (_sending && index == _messages.length) {
          return _ThinkingBubble();
        }
        final m = _messages[index];
        final canSendToReal = m.role == ChatRole.model &&
            !m.sentToReal &&
            index > 0 &&
            _messages[index - 1].role == ChatRole.user;
        // Se un messaggio utente non ha una risposta model successiva
        // (tipico dopo un errore AI) e non è già stato inoltrato, offriamo
        // la CTA "Chiedi a Favilla reale" come fallback diretto.
        final isOrphanUser = m.role == ChatRole.user &&
            !m.sentToReal &&
            !_sending &&
            (index == _messages.length - 1 ||
                _messages[index + 1].role != ChatRole.model);
        return _ChatBubble(
          message: m,
          onSpeak: m.role == ChatRole.model ? () => _speak(m.text) : null,
          onSendToReal: canSendToReal
              ? () => _openSendToRealSheet(index)
              : (isOrphanUser ? () => _openSendToRealSheetForUser(index) : null),
        );
      },
    );
  }

  Future<void> _openSendToRealSheetForUser(int userIndex) async {
    SettingsService.tapFeedback();
    final question = _messages[userIndex].text;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SendToRealSheet(
        question: question,
        aiAnswer: null,
      ),
    );
    if (sent != true || !mounted) return;

    final updated = [..._messages];
    updated[userIndex] = updated[userIndex].copyWith(sentToReal: true);
    setState(() => _messages = updated);
    await _service.persist(updated);
  }

  Future<void> _openSendToRealSheet(int modelIndex) async {
    SettingsService.tapFeedback();
    final question = _messages[modelIndex - 1].text;
    final aiAnswer = _messages[modelIndex].text;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SendToRealSheet(
        question: question,
        aiAnswer: aiAnswer,
      ),
    );
    if (sent != true || !mounted) return;

    final updated = [..._messages];
    updated[modelIndex] = updated[modelIndex].copyWith(sentToReal: true);
    setState(() => _messages = updated);
    await _service.persist(updated);
  }

  Widget _buildQuota() {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService.ttsEnabled,
      builder: (context, _, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              AppStrings.askFavillaQuotaLeft(_remaining),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    final canSend = !_sending && AiClient.instance.enabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(60),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              enabled: canSend,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: AppStrings.askFavillaHint,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: AppStrings.askFavillaSend,
            onPressed: canSend ? () => _send() : null,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onSpeak;
  final VoidCallback? onSendToReal;

  const _ChatBubble({
    required this.message,
    this.onSpeak,
    this.onSendToReal,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser
        ? Colors.pinkAccent.shade200
        : Colors.deepPurple.shade400;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Favilla Blaze',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withAlpha(220),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              if (onSpeak != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: SettingsService.ttsEnabled,
                    builder: (context, ttsOn, _) {
                      if (!ttsOn) return const SizedBox.shrink();
                      return ValueListenableBuilder<bool>(
                        valueListenable: TtsService.instance.isSpeaking,
                        builder: (context, speaking, _) {
                          return IconButton(
                            tooltip: speaking
                                ? AppStrings.ttsStopTooltip
                                : AppStrings.ttsPlayTooltip,
                            iconSize: 16,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: Icon(
                              speaking
                                  ? Icons.stop_circle_outlined
                                  : Icons.volume_up_outlined,
                              color: Colors.white,
                            ),
                            onPressed: onSpeak,
                          );
                        },
                      );
                    },
                  ),
                ),
              if (onSendToReal != null || message.sentToReal)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: message.sentToReal
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.white.withAlpha(180),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppStrings.askRealAlreadySent,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withAlpha(180),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          )
                        : InkWell(
                            onTap: onSendToReal,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(
                                AppStrings.askRealCta,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amberAccent.shade100,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor:
                                      Colors.amberAccent.shade100,
                                ),
                              ),
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

class _ThinkingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade400.withAlpha(120),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              AppStrings.askFavillaThinking,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendToRealSheet extends StatefulWidget {
  final String question;
  final String? aiAnswer;

  const _SendToRealSheet({
    required this.question,
    required this.aiAnswer,
  });

  @override
  State<_SendToRealSheet> createState() => _SendToRealSheetState();
}

class _SendToRealSheetState extends State<_SendToRealSheet> {
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _questionCtrl = TextEditingController();
  bool _sending = false;
  String? _error;

  bool get _composeMode => widget.question.isEmpty;

  @override
  void dispose() {
    _contactCtrl.dispose();
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final question =
        _composeMode ? _questionCtrl.text.trim() : widget.question;
    if (question.isEmpty) {
      setState(() => _error = AppStrings.askRealError);
      return;
    }
    SettingsService.tapFeedback();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final remaining = await AskFavillaService.instance.submitToReal(
        question: question,
        aiAnswer: widget.aiAnswer,
        contact: _contactCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.askRealSent} '
              '(${AppStrings.askRealQuotaLeft(remaining)})'),
        ),
      );
      Navigator.pop(context, true);
    } on AiQuotaExceeded {
      if (!mounted) return;
      setState(() {
        _error = AppStrings.askRealQuotaExceeded;
        _sending = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'quota_exceeded'
            ? AppStrings.askRealQuotaExceeded
            : AppStrings.askRealError;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              AppStrings.askRealSheetTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.askRealSheetIntro,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_composeMode)
              TextField(
                controller: _questionCtrl,
                enabled: !_sending,
                minLines: 3,
                maxLines: 6,
                maxLength: 600,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppStrings.askRealComposeHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.shade400),
                ),
                child: Text(
                  widget.question,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _contactCtrl,
              enabled: !_sending,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: AppStrings.askRealContactLabel,
                hintText: AppStrings.askRealContactHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(AppStrings.askRealSubmit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
