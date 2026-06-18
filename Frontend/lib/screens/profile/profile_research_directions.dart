import 'package:flutter/material.dart';

import '../../models/user_profile.dart';

/// Research-direction card shown between the header and the tabs.
class ProfileResearchDirections extends StatelessWidget {
  final UserProfile profile;

  const ProfileResearchDirections({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final directions = profile.researchDirections;
    final scheme = Theme.of(context).colorScheme;
    final cardColor = scheme.surfaceVariant;
    final textColor = scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('研究方向', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))]),
          child: directions.isEmpty
              ? Text('还没有填写研究方向', style: TextStyle(color: textColor.withOpacity(0.6)))
              : Wrap(spacing: 8, runSpacing: 8, children: directions.map((d) => _buildDirectionChip(d, scheme)).toList()),
        ),
      ]),
    );
  }

  Widget _buildDirectionChip(String label, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: scheme.surface.withOpacity(0.8), border: Border.all(color: scheme.primary.withOpacity(0.6), width: 1), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: scheme.onSurface, fontSize: 14)),
    );
  }
}
