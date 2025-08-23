import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../theme/theme.dart';

class NotificationsWidget extends StatefulWidget {
  const NotificationsWidget({super.key});

  @override
  State<NotificationsWidget> createState() => _NotificationsWidgetState();
}

class _NotificationsWidgetState extends State<NotificationsWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadRandomPrayer();
      context.read<NotificationProvider>().loadRandomHadith();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(context.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Settings Card
              Card(
                child: Padding(
                  padding: EdgeInsets.all(context.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cilësimet e Njoftimeve',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: context.spaceLg),
                      
                      SwitchListTile(
                        title: const Text('Aktivizo njoftime ditore'),
                        subtitle: const Text('Lutje në 04:00 dhe hadithe në 20:00'),
                        value: notificationProvider.notificationsEnabled,
                        onChanged: notificationProvider.isLoading 
                            ? null 
                            : (value) => notificationProvider.toggleNotifications(value),
                      ),
                      
                      SizedBox(height: context.spaceLg),
                      
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: notificationProvider.isLoading
                                  ? null
                                  : () => notificationProvider.showTestNotification(),
                              icon: const Icon(Icons.notifications),
                              label: const Text('Test Njoftimi'),
                            ),
                          ),
                          SizedBox(width: context.spaceLg),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: notificationProvider.isLoading
                                  ? null
                                  : () => notificationProvider.setupNotifications(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Rifresko'),
                            ),
                          ),
                        ],
                      ),
                      
                      if (notificationProvider.isLoading)
                        Padding(
                          padding: EdgeInsets.only(top: context.spaceLg),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                      
                      if (notificationProvider.error != null)
                        Padding(
                          padding: EdgeInsets.only(top: context.spaceLg),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    notificationProvider.error!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => notificationProvider.clearError(),
                                  icon: const Icon(Icons.close),
                                  iconSize: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: context.spaceLg),
              
              // Current Prayer Card
              if (notificationProvider.currentPrayer != null)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(context.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.wb_sunny,
                              color: Theme.of(context).primaryColor,
                            ),
                            SizedBox(width: context.spaceSm),
                            Text(
                              'Lutja e Ditës',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => notificationProvider.loadRandomPrayer(),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        SizedBox(height: context.spaceMd),
                        _FormattedBlock(text: notificationProvider.currentPrayer!),
                      ],
                    ),
                  ),
                ),
              
              SizedBox(height: context.spaceLg),
              
              // Current Hadith Card
              if (notificationProvider.currentHadith != null)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(context.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.nights_stay,
                              color: Theme.of(context).primaryColor,
                            ),
                            SizedBox(width: context.spaceSm),
                            Text(
                              'Hadithi i Ditës',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => notificationProvider.loadRandomHadith(),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        SizedBox(height: context.spaceMd),
                        _FormattedBlock(text: notificationProvider.currentHadith!),
                      ],
                    ),
                  ),
                ),
              
              SizedBox(height: context.spaceLg),
              
              // Information Card
              Card(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                child: Padding(
                  padding: EdgeInsets.all(context.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: context.spaceSm),
                          Text(
                            'Informacion',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.spaceMd),
                      const Text(
                        '• Njoftime për lutje dërgohen çdo ditë në orën 04:00\n'
                        '• Njoftime për hadithe dërgohen çdo ditë në orën 20:00\n'
                        '• Përmbajtja e njoftimeve ndryshon çdo ditë\n'
                        '• Mund t\'i aktivizoni ose çaktivizoni njoftime në çdo kohë',
                        style: TextStyle(height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FormattedBlock extends StatelessWidget {
  final String text;
  const _FormattedBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    // Our provider joins parts with \n; try to identify optional header/footer lines.
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    TextStyle body = Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.6);
    TextStyle title = Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w600);
    TextStyle caption = Theme.of(context).textTheme.bodySmall!.copyWith(color: Theme.of(context).hintColor);

    final children = <Widget>[];
    if (lines.isNotEmpty) {
      // If first line looks like a short title (<= 40 chars), show as title
      if (lines.first.length <= 40 && RegExp(r'^(Lutje|Hadith|Autori:|Titulli:)', caseSensitive: false).hasMatch(lines.first)) {
        children.add(Text(lines.first, style: title));
        lines.removeAt(0);
        children.add(SizedBox(height: context.spaceSm));
      }
      // If last line looks like a source
      String? sourceLine;
      if (lines.isNotEmpty && (lines.last.startsWith('Burimi:') || lines.last.length <= 40 && RegExp(r'[,\.]\s*\d').hasMatch(lines.last))) {
        sourceLine = lines.removeLast();
      }
      if (lines.isNotEmpty) {
        children.add(Text(lines.join('\n'), style: body));
      }
      if (sourceLine != null) {
        children.add(SizedBox(height: context.spaceSm));
        children.add(Text(sourceLine, style: caption));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
