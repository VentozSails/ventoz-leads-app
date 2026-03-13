import 'package:flutter/material.dart';
import 'site_navbar.dart';
import '../l10n/locale_provider.dart';

class PublicShell extends StatelessWidget {
  final Widget child;
  const PublicShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleProvider(),
      builder: (context, _) => Scaffold(
        body: Column(
          children: [
            const SiteNavbar(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
