import 'package:flutter/material.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabStats)),
      body: Center(child: Text(l10n.comingSoon)),
    );
  }
}
