import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_strings.dart';
import '../../services/inbox_service.dart';
import '../../services/settings_service.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await InboxService.instance.sync();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.inboxTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.inboxMarkAllRead,
            icon: const Icon(Icons.mark_email_read_outlined),
            onPressed: () async {
              SettingsService.tapFeedback();
              await InboxService.instance.markAllRead();
            },
          ),
          IconButton(
            tooltip: AppStrings.inboxRefresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _refreshing ? null : _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<InboxReply>>(
          valueListenable: InboxService.instance.replies,
          builder: (context, list, _) {
            if (list.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💌', style: TextStyle(fontSize: 56)),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.inboxEmpty,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _ReplyCard(reply: list[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  final InboxReply reply;
  const _ReplyCard({required this.reply});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_Hm();
    return Material(
      color: reply.read
          ? Colors.deepPurple.shade900.withAlpha(60)
          : Colors.deepPurple.shade700.withAlpha(120),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (!reply.read) {
            await InboxService.instance.markRead(reply.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!reply.read)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Colors.amberAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const Text('✨', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppStrings.inboxFromFavilla,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.amberAccent.shade100,
                      ),
                    ),
                  ),
                  Text(
                    df.format(reply.answeredAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(80),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reply.question,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade300,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                reply.answer,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
