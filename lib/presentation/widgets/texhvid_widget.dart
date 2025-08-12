import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kurani_fisnik_app/presentation/providers/texhvid_provider.dart';
import 'package:kurani_fisnik_app/domain/entities/texhvid_rule.dart';

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
                      onPressed: provider.isQuizMode ? null : () => provider.startQuiz(),
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
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Pyetja ${provider.currentQuestionIndex + 1} nga ${provider.totalQuestions}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Question
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                question.question,
                style: Theme.of(context).textTheme.titleMedium,
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

        return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: backgroundColor,
                  child: ListTile(
          title: Text(optionText, style: TextStyle(color: textColor)),
                    trailing: icon != null ? Icon(icon, color: textColor) : null,
          onTap: showResult ? null : () => provider.selectAnswer(optionText),
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
            ElevatedButton(
              onPressed: provider.nextQuestion,
              child: Text(
                provider.isLastQuestion ? 'Përfundo Kuizin' : 'Pyetja Tjetër',
              ),
            ),
          ] else if (provider.selectedAnswer != null) ...[
            ElevatedButton(
              onPressed: provider.submitAnswer,
              child: const Text('Konfirmo Përgjigjen'),
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rule.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      
                      if (rule.examples.isNotEmpty) ...[
                        Text(
                          'Shembuj:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...rule.examples.map((example) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
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
}
