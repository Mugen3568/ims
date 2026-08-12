import 'package:flutter/material.dart';
import '../models/result_model.dart';

class ResultCard extends StatelessWidget {
  final ResultModel result;

  const ResultCard({
    super.key,
    required this.result,
  });

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.amber.shade800;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradeColor = _getGradeColor(result.grade);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.testTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (result.subject.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Subject: ${result.subject}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: gradeColor, width: 1.5),
                  ),
                  child: Text(
                    result.grade,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: gradeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Marks Obtained', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${result.marks} / ${result.maxMarks}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Percentage', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      '${result.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (result.remarks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Remarks: ${result.remarks}',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
