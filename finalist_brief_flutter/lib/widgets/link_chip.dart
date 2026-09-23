import 'package:flutter/material.dart';

import '../links.dart';

/// A small chip that opens [url] when tapped.
class LinkChip extends StatelessWidget {
  const LinkChip({
    super.key,
    required this.label,
    required this.url,
    this.icon,
  });

  final String label;
  final String url;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon ?? Icons.open_in_new, size: 16),
      label: Text(label),
      onPressed: () => openUrl(url),
    );
  }
}
