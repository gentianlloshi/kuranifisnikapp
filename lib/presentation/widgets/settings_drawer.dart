import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../../core/utils/constants.dart';
import '../pages/help_page.dart'; // Import the HelpPage

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          final settings = appState.settings;
          
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Kurani Fisnik',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Cilësimet',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Theme settings
              ExpansionTile(
                leading: const Icon(Icons.palette),
                title: const Text('Tema'),
                children: [
                  ...AppConstants.availableThemes.map((theme) => RadioListTile<String>(
                    title: Text(_getThemeName(theme)),
                    value: theme,
                    groupValue: settings.theme,
                    onChanged: (value) {
                      if (value != null) {
                        appState.updateTheme(value);
                      }
                    },
                  )),
                ],
              ),
              
              // Font size settings
              ExpansionTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Madhësia e shkronjave'),
                children: [
                  ListTile(
                    title: const Text('Teksti arabisht'),
                    subtitle: Slider(
                      // Clamp in case vlera e ruajtur është jashtë diapazonit të ri
                      value: settings.fontSizeArabic.clamp(18, 60),
                      min: 18,
                      max: 60,
                      divisions: 21, // (60-18)/2 ≈ 21 hapa prej 2pt
                      label: settings.fontSizeArabic.toStringAsFixed(0),
                      onChanged: (value) => appState.updateArabicFontSize(value),
                    ),
                  ),
                  ListTile(
                    title: const Text('Përkthimi'),
                    subtitle: Slider(
                      value: settings.fontSizeTranslation.clamp(12, 36),
                      min: 12,
                      max: 36,
                      divisions: 12,
                      label: settings.fontSizeTranslation.toStringAsFixed(0),
                      onChanged: (value) => appState.updateTranslationFontSize(value),
                    ),
                  ),
                ],
              ),
              
              // Translation settings
              ExpansionTile(
                leading: const Icon(Icons.translate),
                title: const Text('Përkthimi'),
                children: [
                  ...AppConstants.availableTranslations.entries.map((entry) => 
                    RadioListTile<String>(
                      title: Text(entry.value),
                      value: entry.key,
                      groupValue: settings.selectedTranslation,
                      onChanged: (value) {
                        if (value != null) {
                          appState.updateTranslation(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              
              // Display options
              ExpansionTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Opsionet e shfaqjes'),
                children: [
                  SwitchListTile(
                    title: const Text('Shfaq tekstin arabisht'),
                    value: settings.showArabic,
                    onChanged: (value) {
                      appState.updateDisplayOptions(showArabic: value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Shfaq përkthimin'),
                    value: settings.showTranslation,
                    onChanged: (value) {
                      appState.updateDisplayOptions(showTranslation: value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Shfaq transliterimin'),
                    value: settings.showTransliteration,
                    onChanged: (value) {
                      appState.updateDisplayOptions(showTransliteration: value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Shfaq fjalë për fjalë'),
                    value: settings.showWordByWord,
                    onChanged: (value) {
                      appState.updateDisplayOptions(showWordByWord: value);
                    },
                  ),
                ],
              ),

              // Audio settings
              ExpansionTile(
                leading: const Icon(Icons.audiotrack),
                title: const Text('Audio'),
                children: [
                  ListTile(
                    title: const Text('Recituesi i preferuar'),
                    subtitle: DropdownButton<String>(
                      value: settings.preferredReciter == 'default' ? null : settings.preferredReciter,
                      hint: const Text('Auto (fallback)'),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'Alafasy_128kbps', child: Text('Alafasy (128kbps)')),
                        DropdownMenuItem(value: 'Abdul_Basit_Mujawwad', child: Text('Abdul Basit (Mujawwad)')),
                        DropdownMenuItem(value: 'AbdulSamad_64kbps', child: Text('Abdul Samad (64kbps)')),
                      ],
                      onChanged: (value) {
                        appState.updatePreferredReciter(value ?? 'default');
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Prefetch audio para luajtjes'),
                    value: appState.settings.enableAudio, // placeholder repurpose
                    onChanged: (_) {}, // real implementation would toggle a dedicated setting
                    subtitle: const Text('Shkarkon ajetin përpara luajtjes për stabilitet'),
                  ),
                ],
              ),
              
              const Divider(),
              
              // About section
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Rreth aplikacionit'),
                onTap: () => _showAboutDialog(context),
              ),
              
              // Help section
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Ndihma'),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpPage()),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _getThemeName(String theme) {
    switch (theme) {
      case 'light':
        return 'E ndritshme';
      case 'dark':
        return 'E errët';
      case 'sepia':
        return 'Sepia';
      case 'midnight':
        return 'Mesnatë';
      default:
        return theme;
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Kurani Fisnik',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.book, size: 48),
      children: const [
        Text('Një aplikacion për leximin dhe studimin e Kuranit Fisnik në gjuhën shqipe.'),
        SizedBox(height: 16),
        Text('Zhvilluar me Flutter dhe dashuri për komunitetin mysliman shqiptar.'),
      ],
    );
  }
}
