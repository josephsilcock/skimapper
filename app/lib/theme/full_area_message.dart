import 'package:flutter/material.dart';

/// A message filling its area: an icon, a heading, a line of detail and Retry.
class FullAreaMessage extends StatelessWidget {
  const FullAreaMessage({
    super.key,
    required this.icon,
    required this.heading,
    required this.detail,
    required this.onRetry,
  });

  final IconData icon;
  final String heading;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 12),
      Text(heading, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(detail, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}
