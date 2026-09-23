import 'package:flutter/material.dart';

/// A submission's cover image, bundled under assets/covers/.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.asset, this.width = 120});

  final String asset;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/covers/$asset',
        width: width,
        height: width * 9 / 16,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: width * 9 / 16,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
