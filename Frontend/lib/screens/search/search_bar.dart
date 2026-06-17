import 'package:flutter/material.dart';

/// Top search bar of the search page: back button, text field, submit button.
///
/// Extracted from `search_screen.dart` with identical layout and behavior:
/// - The suffix icon toggles between a clear button (when text is present) and
///   a search glyph (when empty).
/// - The trailing 「搜索」button is only shown when the field is non-empty.
///
/// The host owns the [controller] / [focusNode] lifecycle and the submit
/// logic. To keep the suffix icon and submit button in sync with the text
/// regardless of how the host rebuilds, this widget listens to [controller]
/// via a [ValueListenableBuilder]; the [onChanged] / [onClear] callbacks are
/// still invoked so any host-side state updates continue to fire as before.
class SearchBarHeader extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  /// Placeholder text for the current search type.
  final String? hintText;

  /// Invoked when the field is submitted (keyboard action or 「搜索」button).
  final ValueChanged<String> onSubmitted;

  /// Invoked on every text change (mirrors the original `onChanged` hook).
  final ValueChanged<String> onChanged;

  /// Invoked when the clear (x) button is tapped, after clearing the field.
  final VoidCallback onClear;

  /// Invoked when the back button is tapped.
  final VoidCallback onBack;

  const SearchBarHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSubmitted,
    required this.onChanged,
    required this.onClear,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: Icon(Icons.arrow_back, color: scheme.onSurface),
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),

          // 搜索输入框
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle:
                          TextStyle(color: scheme.onSurface.withOpacity(0.6)),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      suffixIcon: value.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  size: 20, color: scheme.onSurface),
                              onPressed: () {
                                controller.clear();
                                onClear();
                              },
                            )
                          : Icon(Icons.search,
                              color: scheme.onSurface.withOpacity(0.6),
                              size: 20),
                    ),
                    style: TextStyle(color: scheme.onSurface),
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                  );
                },
              ),
            ),
          ),

          // 搜索按钮
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => onSubmitted(controller.text),
                child: Text('搜索', style: TextStyle(color: scheme.primary)),
              );
            },
          ),
        ],
      ),
    );
  }
}
