import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/memorization_provider.dart';

class VerseMemorizationIndicator extends StatelessWidget {
  final String verseKey;
  final bool showLabel;

  const VerseMemorizationIndicator({
    super.key,
    required this.verseKey,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MemorizationProvider>(
      builder: (context, memorizationProvider, child) {
        final isMemorized = memorizationProvider.isVerseMemorizedSync(verseKey);
        
        return GestureDetector(
          onTap: () => memorizationProvider.toggleVerseMemorization(verseKey),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMemorized 
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMemorized 
                    ? Colors.green
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMemorized ? Icons.school : Icons.school_outlined,
                  size: 16,
                  color: isMemorized ? Colors.green : Colors.grey,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 4),
                  Text(
                    isMemorized ? 'Memorizuar' : 'Memorizo',
                    style: TextStyle(
                      fontSize: 12,
                      color: isMemorized ? Colors.green : Colors.grey,
                      fontWeight: isMemorized ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

