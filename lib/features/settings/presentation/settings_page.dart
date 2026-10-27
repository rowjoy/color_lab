import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/l10n.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: IconButton(
        tooltip: context.l10n.back,
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
