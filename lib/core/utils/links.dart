import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in an in-app browser (terms, privacy policy...) or, with
/// [mode], somewhere else (e.g. the system browser).
Future<void> openLink(
  BuildContext context,
  String url, {
  LaunchMode mode = LaunchMode.inAppBrowserView,
}) async {
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(url), mode: mode);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Não foi possível abrir $url')),
    );
  }
}
