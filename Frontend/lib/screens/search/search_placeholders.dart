import 'package:flutter/material.dart';

/// Shared placeholder widgets for the search page sections.
///
/// Extracted verbatim from `search_screen.dart` so the history and hot-search
/// sections can render the same empty / error states without duplicating
/// layout. These widgets are purely presentational; any retry action is
/// delivered by the host through [SearchErrorState.onRetry].

/// Empty-state placeholder: a muted icon plus a message.
class SearchEmptyState extends StatelessWidget {
  final String message;

  const SearchEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Error-state placeholder: a warning icon, the message, and a retry button.
class SearchErrorState extends StatelessWidget {
  final String message;

  /// Invoked when the user taps the retry button.
  final VoidCallback onRetry;

  const SearchErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.orange[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重新加载'),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
