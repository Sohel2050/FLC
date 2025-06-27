import 'package:flutter/material.dart';

class MainAppButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isFullWidth;

  const MainAppButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.isPrimary = true,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor:
              isPrimary
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSecondaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
            Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color:
                    isPrimary
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
