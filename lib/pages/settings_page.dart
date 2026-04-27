import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/app_strings.dart';
import '../services/engagement_service.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _versionLabel = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionLabel = '${info.version} (build ${info.buildNumber})';
    });
  }

  Future<void> _confirmReset() async {
    SettingsService.tapFeedback();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppStrings.resetProgressConfirmTitle),
          content: Text(AppStrings.resetProgressConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.reset),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ProgressService.resetAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.resetProgressDone)),
      );
    }
  }

  Future<void> _pickLanguage() async {
    SettingsService.tapFeedback();
    final selected = await showDialog<AppLanguage>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(AppStrings.languageTitle),
          children: AppLanguage.values
              .map(
                (l) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, l),
                  child: Row(
                    children: [
                      if (SettingsService.language.value == l)
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(l.label),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
    if (selected != null) {
      await SettingsService.setLanguage(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.settings),
      ),
      body: ListView(
        children: [
          _SectionHeader(AppStrings.readingSection),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.hapticsEnabled,
            builder: (context, enabled, _) {
              return SwitchListTile(
                title: Text(AppStrings.hapticsTitle),
                subtitle: Text(AppStrings.hapticsSubtitle),
                secondary: const Icon(Icons.vibration),
                value: enabled,
                onChanged: (v) {
                  SettingsService.setHapticsEnabled(v);
                  if (v) SettingsService.tapFeedback();
                },
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: SettingsService.fullscreenReading,
            builder: (context, enabled, _) {
              return SwitchListTile(
                title: Text(AppStrings.fullscreenTitle),
                subtitle: Text(AppStrings.fullscreenSubtitle),
                secondary: const Icon(Icons.fullscreen),
                value: enabled,
                onChanged: (v) {
                  SettingsService.tapFeedback();
                  SettingsService.setFullscreenReading(v);
                },
              );
            },
          ),
          ValueListenableBuilder<TextAnimationSpeed>(
            valueListenable: SettingsService.textAnimationSpeed,
            builder: (context, speed, _) {
              final lang = SettingsService.language.value;
              return ListTile(
                leading: const Icon(Icons.speed),
                title: Text(AppStrings.textSpeedTitle),
                subtitle: Text(speed.labelFor(lang)),
                trailing: PopupMenuButton<TextAnimationSpeed>(
                  initialValue: speed,
                  onSelected: (value) {
                    SettingsService.tapFeedback();
                    SettingsService.setTextAnimationSpeed(value);
                  },
                  itemBuilder: (context) => TextAnimationSpeed.values
                      .map(
                        (s) => PopupMenuItem(
                          value: s,
                          child: Text(s.labelFor(lang)),
                        ),
                      )
                      .toList(),
                  child: const Icon(Icons.arrow_drop_down),
                ),
              );
            },
          ),
          const Divider(height: 32),
          _SectionHeader(AppStrings.languageSection),
          ValueListenableBuilder<AppLanguage>(
            valueListenable: SettingsService.language,
            builder: (context, lang, _) {
              return ListTile(
                leading: const Icon(Icons.language),
                title: Text(AppStrings.languageTitle),
                subtitle: Text('${AppStrings.languageSubtitle}\n→ ${lang.label}'),
                isThreeLine: true,
                onTap: _pickLanguage,
              );
            },
          ),
          const Divider(height: 32),
          _SectionHeader(AppStrings.progressSection),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: Text(
              AppStrings.resetProgress,
              style: const TextStyle(color: Colors.redAccent),
            ),
            subtitle: Text(AppStrings.resetProgressSubtitle),
            onTap: _confirmReset,
          ),
          const Divider(height: 32),
          _SectionHeader(AppStrings.shareSection),
          ListTile(
            leading: const Icon(Icons.share),
            title: Text(AppStrings.shareApp),
            subtitle: Text(AppStrings.shareAppSubtitle),
            onTap: () {
              SettingsService.tapFeedback();
              EngagementService.shareApp();
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(AppStrings.rateApp),
            subtitle: Text(AppStrings.rateAppSubtitle),
            onTap: () {
              SettingsService.tapFeedback();
              EngagementService.openStoreListing();
            },
          ),
          const Divider(height: 32),
          _SectionHeader(AppStrings.infoSection),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(AppStrings.version),
            subtitle: Text(
              _versionLabel.isEmpty ? '...' : _versionLabel,
            ),
          ),
          const ListTile(
            leading: Icon(Icons.menu_book),
            title: Text('Favilla Blaze'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.pinkAccent.shade100,
        ),
      ),
    );
  }
}
