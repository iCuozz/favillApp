import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/ai/ai_client.dart';
import '../../services/ai/ai_rate_limiter.dart';
import '../../services/ai/ask_favilla_service.dart';
import '../../services/settings_service.dart';
import '../../services/tts/tts_service.dart';

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
        _messages = _messages.sublist(0, _messages.length - 1);
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
        ],
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
        return _ChatBubble(
          message: m,
          onSpeak: m.role == ChatRole.model ? () => _speak(m.text) : null,
        );
      },
    );
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

  const _ChatBubble({required this.message, this.onSpeak});

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
