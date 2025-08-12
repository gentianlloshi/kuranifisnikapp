import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/memorization_provider.dart';
import '../../domain/entities/surah.dart';

class SurahMemorizationProgress extends StatelessWidget {
  final Surah surah;
  final bool showPercentage;

  const SurahMemorizationProgress({
    super.key,
    required this.surah,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MemorizationProvider>(
      builder: (context, memorizationProvider, child) {
        final memorizedCount = memorizationProvider.getMemorizationProgressForSurah(
          surah.number,
        );
        final percentage = memorizationProvider.getMemorizationPercentageForSurah(
          surah.number,
        );

        if (memorizedCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.school,
                size: 14,
                color: Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                showPercentage 
                    ? '${percentage.toStringAsFixed(0)}%'
                    : '$memorizedCount/${surah.versesCount}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
