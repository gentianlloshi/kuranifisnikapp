import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/texhvid_provider.dart';
import 'package:kurani_fisnik_app/domain/entities/texhvid_rule.dart';
import '../theme/theme.dart';
import 'sheet_header.dart';

class TexhvidWidget extends StatefulWidget {
  const TexhvidWidget({super.key});

  @override
  State<TexhvidWidget> createState() => _TexhvidWidgetState();
}

class _TexhvidWidgetState extends State<TexhvidWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TexhvidProvider>().loadTexhvidRules();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TexhvidProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Gabim në ngarkimin e rregullave të Texhvidit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  provider.error!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadTexhvidRules(),
                  child: const Text('Provo Përsëri'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Rregullat e Texhvidit',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mëso rregullat e duhura të leximit të Kuranit',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // Quiz Mode Toggle
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: provider.isQuizMode ? null : () => _openStartQuizDialog(context, provider),
                      icon: const Icon(Icons.quiz),
                      label: const Text('Fillo Kuizin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: provider.isQuizMode ? () => provider.exitQuiz() : null,
                      icon: const Icon(Icons.close),
                      label: const Text('Dil nga Kuizi'),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: provider.isQuizMode
                  ? _buildQuizView(context, provider)
                  : _buildRulesView(context, provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRulesView(BuildContext context, TexhvidProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.categories.length,
      itemBuilder: (context, index) {
        final category = provider.categories[index];
        final rules = provider.getRulesByCategory(category);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(
              category,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text('${rules.length} rregulla'),
            children: rules.map((rule) => _buildRuleItem(context, rule)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildRuleItem(BuildContext context, TexhvidRule rule) {
    return ListTile(
      title: Text(rule.title),
      subtitle: Text(
        rule.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showRuleDetails(context, rule),
    );
  }

  Widget _buildQuizView(BuildContext context, TexhvidProvider provider) {
    if (provider.currentQuestion == null) {
      return const Center(
        child: Text('Nuk ka pyetje të disponueshme'),
      );
    }

    final question = provider.currentQuestion!;
    final progress = (provider.currentQuestionIndex + 1) / provider.totalQuestions;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress
          Semantics(
            label: 'Progres kuizi ${(progress * 100).toStringAsFixed(0)} përqind',
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Pyetja ${provider.currentQuestionIndex + 1} nga ${provider.totalQuestions}',
            child: Text(
              'Pyetja ${provider.currentQuestionIndex + 1} nga ${provider.totalQuestions}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Question
          Semantics(
            label: 'Pyetje kuizi',
            child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                question.question,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ),
          ),
          const SizedBox(height: 16),

          // Options
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                final optionText = question.options[index];
                final isSelected = provider.selectedAnswer == optionText;
                final isCorrect = index == question.correctAnswer;
                final showResult = provider.hasAnswered;

                Color? backgroundColor;
                Color? textColor;
                IconData? icon;

                if (showResult) {
                  if (isCorrect) {
                    backgroundColor = Colors.green[100];
                    textColor = Colors.green[800];
                    icon = Icons.check_circle;
                  } else if (isSelected && !isCorrect) {
                    backgroundColor = Colors.red[100];
                    textColor = Colors.red[800];
                    icon = Icons.cancel;
                  }
                } else if (isSelected) {
                  backgroundColor = Theme.of(context).primaryColor.withOpacity(0.1);
                  textColor = Theme.of(context).primaryColor;
                }

  return Semantics(
      button: !showResult,
      label: 'Opsion ${index + 1}${isSelected ? ', i zgjedhur' : ''}${showResult && isCorrect ? ', i saktë' : ''}',
      child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: backgroundColor,
                  child: ListTile(
          title: Text(optionText, style: TextStyle(color: textColor)),
                    trailing: icon != null ? Icon(icon, color: textColor) : null,
          onTap: showResult ? null : () => provider.selectAnswer(optionText),
                  ),
      ),
                );
              },
            ),
          ),

          // Action Buttons
          if (provider.hasAnswered) ...[
            if (provider.currentQuestion!.explanation != null && provider.currentQuestion!.explanation!.isNotEmpty)
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shpjegimi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(provider.currentQuestion!.explanation!, style: TextStyle(color: Colors.blue[700])),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: provider.isLastQuestion ? 'Përfundo kuizin' : 'Pyetja tjetër',
              child: ElevatedButton(
              onPressed: provider.isLastQuestion
                  ? () async {
                      final result = await provider.finishQuiz();
                      if (!mounted) return;
                      _showQuizSummary(context, provider, result);
                    }
                  : provider.nextQuestion,
              child: Text(
                provider.isLastQuestion ? 'Përfundo Kuizin' : 'Pyetja Tjetër',
              ),
              ),
            ),
          ] else if (provider.selectedAnswer != null) ...[
            Semantics(
              button: true,
              label: 'Konfirmo përgjigjen',
              child: ElevatedButton(
              onPressed: provider.submitAnswer,
              child: const Text('Konfirmo Përgjigjen'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRuleDetails(BuildContext context, TexhvidRule rule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => BottomSheetWrapper(
        padding: EdgeInsets.only(
          left: context.spaceLg,
          right: context.spaceLg,
          top: context.spaceSm,
          bottom: MediaQuery.of(context).viewInsets.bottom + context.spaceLg,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              SheetHeader(
                title: rule.title,
                subtitle: 'Rregull i Texhvidit',
                leadingIcon: Icons.school,
                onClose: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      SizedBox(height: context.spaceLg),
                      if (rule.examples.isNotEmpty) ...[
                        Text(
                          'Shembuj:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        SizedBox(height: context.spaceSm),
                        ...rule.examples.map((example) => Padding(
                              padding: EdgeInsets.only(bottom: context.spaceXs),
                              child: Text(
                                '• $example',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStartQuizDialog(BuildContext context, TexhvidProvider provider) {
    String? selectedCategory;
    int? limit;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Fillo Kuizin'),
          content: StatefulBuilder(
            builder: (ctx, setState) {
              final categories = ['Të gjitha', ...provider.categories];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: categories
                        .map((c) => DropdownMenuItem<String>(
                              value: c == 'Të gjitha' ? null : c,
                              child: Text(c),
                            ))
                        .toList(),
                    decoration: const InputDecoration(labelText: 'Kategoria'),
                    onChanged: (val) => setState(() => selectedCategory = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: limit,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 pyetje')),
                      DropdownMenuItem(value: 10, child: Text('10 pyetje')),
                      DropdownMenuItem(value: 20, child: Text('20 pyetje')),
                    ],
                    decoration: const InputDecoration(labelText: 'Numri i pyetjeve (opsionale)'),
                    onChanged: (val) => setState(() => limit = val),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anulo'),
            ),
            ElevatedButton(
              onPressed: () {
                provider.startQuiz(category: selectedCategory, limit: limit, shuffle: true);
                Navigator.of(ctx).pop();
              },
              child: const Text('Fillo'),
            ),
          ],
        );
      },
    );
  }
}

void _showQuizSummary(BuildContext context, TexhvidProvider provider, QuizResult result) {
  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Përmbledhje e Kuizit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rezultati: ${result.correct}/${result.total} (${(result.accuracy * 100).toStringAsFixed(0)}%)'),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text('Totali i kuizeve: ${provider.totalQuizzes}'),
            Text('Saktësia gjithsej: ${(provider.lifetimeAccuracy * 100).toStringAsFixed(0)}%'),
            if (provider.lastQuizAt != null) Text('Kuizi i fundit: ${provider.lastQuizAt}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mbyll'),
          ),
        ],
      );
    },
  );
}
