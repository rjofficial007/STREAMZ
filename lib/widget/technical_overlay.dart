import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// A Brutalist-style technical overlay for monitoring playback and system stats.
class TechnicalOverlay extends StatelessWidget {
  final Map<String, String> stats;
  final VoidCallback onClose;

  const TechnicalOverlay({
    super.key,
    required this.stats,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DS.bg.withValues(alpha: 0.85),
      padding: const EdgeInsets.all(DS.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SYSTEM_STATS // V1.0',
                style: DS.labelLg.copyWith(color: DS.accent),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: DS.accent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: DS.s24),
          const Divider(color: DS.borderStrong, height: 1),
          const SizedBox(height: DS.s24),
          Expanded(
            child: ListView.separated(
              itemCount: stats.length,
              separatorBuilder: (context, index) => const SizedBox(height: DS.s12),
              itemBuilder: (context, index) {
                final key = stats.keys.elementAt(index);
                final value = stats[key];
                return Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        key.toUpperCase(),
                        style: DS.labelMd.copyWith(color: DS.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value ?? 'N/A',
                        style: DS.labelMd.copyWith(
                          color: DS.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: DS.s24),
          const Divider(color: DS.borderStrong, height: 1),
          const SizedBox(height: DS.s12),
          Text(
            'LOG_STREAM: [OK] STREAMING_DATA_RECEIVING...',
            style: DS.labelSm.copyWith(color: DS.success),
          ),
        ],
      ),
    );
  }
}
