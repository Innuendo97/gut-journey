import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/router.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMore)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.restaurant_outlined),
            title: Text(l10n.moreFoodLibrary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.moreFoods),
          ),
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: Text(l10n.moreMedications),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.moreMedications),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: Text(l10n.fodmapTile),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.moreFodmap),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.moreSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.moreSettings),
          ),
        ],
      ),
    );
  }
}
