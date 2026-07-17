import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// PDF theme backed by the bundled Roboto family — the base-14 PDF fonts
/// only cover WinAnsi, which free text (food names, custom symptom names)
/// can easily exceed.
Future<pw.ThemeData> loadReportTheme() async {
  Future<pw.Font> load(String file) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/$file'));
  return pw.ThemeData.withFont(
    base: await load('Roboto-Regular.ttf'),
    bold: await load('Roboto-Bold.ttf'),
    italic: await load('Roboto-Italic.ttf'),
    boldItalic: await load('Roboto-BoldItalic.ttf'),
  );
}
