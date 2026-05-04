import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_strings.dart';
import '../../services/ai/mission_generator_service.dart';
import '../../services/settings_service.dart';
import 'mission_viewer_page.dart';

class MyMissionsPage extends StatefulWidget {
  const MyMissionsPage({super.key});

  @override
  State<MyMissionsPage> createState() => _MyMissionsPageState();
}

class _MyMissionsPageState extends State<MyMissionsPage> {
  final MissionGeneratorService _service = MissionGeneratorService.instance;
  List<GeneratedMission> _missions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final list = await _service.loadCollection();
    if (!mounted) return;
    setState(() {
      _missions = list;
      _loading = false;
    });
  }

  Future<void> _delete(GeneratedMission m) async {
    SettingsService.tapFeedback();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.missionDeleteConfirm),
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
    await _service.delete(m.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.missionMyCollection)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _missions.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _missions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final m = _missions[i];
                    return Card(
                      child: ListTile(
                        title: Text(
                          m.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          m.situation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: AppStrings.share,
                              icon: const Icon(Icons.share, size: 20),
                              onPressed: () {
                                SettingsService.tapFeedback();
                                Share.share(m.toShareText());
                              },
                            ),
                            IconButton(
                              tooltip: AppStrings.cancel,
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _delete(m),
                            ),
                          ],
                        ),
                        onTap: () {
                          SettingsService.tapFeedback();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MissionViewerPage(mission: m),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📚', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              AppStrings.missionCollectionEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade300),
            ),
          ],
        ),
      ),
    );
  }
}
