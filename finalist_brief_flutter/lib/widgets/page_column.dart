import 'package:flutter/material.dart';

/// Centers page content at a readable width with a phone-friendly gutter.
class PageColumn extends StatelessWidget {
  const PageColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
