import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/data_export_service.dart';
import '../../core/services/data_import_service.dart';
import '../../data/datasources/local/storage_data_source.dart';
import '../../data/repositories/storage_repository_impl.dart';
import '../../domain/repositories/storage_repository.dart';

/// Simple self-contained UI sheet for Data Import / Export (DATA-2 wiring).
/// Allows user to:
///  - Export current data to JSON (copy to clipboard)
///  - Paste JSON to preview diff (dry-run)
///  - Select domains & apply
class DataManagementSheet extends StatefulWidget {
  const DataManagementSheet({super.key});

  @override
  State<DataManagementSheet> createState() => _DataManagementSheetState();
}

class _DataManagementSheetState extends State<DataManagementSheet> {
  late final StorageRepository _storageRepository;
  late final DataExportService _exportService;
  late final DataImportService _importService;

  bool _loading = false;
  String? _exportJson;
  String? _error;
  String _importRaw = '';
  ImportDiff? _diff;
  DataImportResult? _applyResult;

  // Domain toggles
  bool _settings = true;
  bool _bookmarks = true;
  bool _notes = true;
  bool _memorization = true;
  bool _readingProgress = true;

  @override
  void initState() {
    super.initState();
    _storageRepository = StorageRepositoryImpl(StorageDataSourceImpl());
    _exportService = DataExportService(storageRepository: _storageRepository);
    _importService = DataImportService(storageRepository: _storageRepository);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.storage),
                  const SizedBox(width: 8),
                  Text('Menaxhimi i të dhënave', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Mbyll',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Eksporto ose importo të dhënat personale. Përdorni këtë për backup ose transferim pajisje.', style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              _sectionHeader('Eksporto'),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _onExport,
                    icon: const Icon(Icons.download),
                    label: const Text('Gjenero JSON'),
                  ),
                  const SizedBox(width: 12),
                  if (_exportJson != null)
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _exportJson));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON u kopjua')));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Kopjo'),
                    ),
                ],
              ),
              if (_exportJson != null) ...[
                const SizedBox(height: 8),
                _collapsibleJsonPreview('Rezultati', _exportJson!),
              ],
              const Divider(height: 32),
              _sectionHeader('Importo'),
              TextField(
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Ngjit JSON këtu',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() { _importRaw = v; }),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  FilterChip(label: const Text('Cilësimet'), selected: _settings, onSelected: (v)=>setState(()=>_settings=v)),
                  FilterChip(label: const Text('Favoritet'), selected: _bookmarks, onSelected: (v)=>setState(()=>_bookmarks=v)),
                  FilterChip(label: const Text('Shënimet'), selected: _notes, onSelected: (v)=>setState(()=>_notes=v)),
                  FilterChip(label: const Text('Memorizimi'), selected: _memorization, onSelected: (v)=>setState(()=>_memorization=v)),
                  FilterChip(label: const Text('Progresi Leximit'), selected: _readingProgress, onSelected: (v)=>setState(()=>_readingProgress=v)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading || _importRaw.trim().isEmpty ? null : _onAnalyze,
                    icon: const Icon(Icons.search),
                    label: const Text('Analizo'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _loading || _diff == null ? null : _onApply,
                    icon: const Icon(Icons.upload),
                    label: const Text('Apliko'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ],
              if (_diff != null) ...[
                const SizedBox(height: 16),
                _buildDiffSummary(_diff!),
              ],
              if (_applyResult != null) ...[
                const SizedBox(height: 16),
                _buildResultSummary(_applyResult!),
              ],
              if (_loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _collapsibleJsonPreview(String label, String jsonStr) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(label),
      children: [
        Container(
          width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          padding: const EdgeInsets.all(8),
          child: SelectableText(jsonStr, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildDiffSummary(ImportDiff diff) {
    final items = <_DiffRow>[];
    items.add(_DiffRow('Cilësimet', diff.settingsChange == SettingsChange.none ? 'Pa ndryshim' : 'Overwrite'));
    items.add(_DiffRow('Favoritet', '+${diff.bookmarkAdds.length} / upd ${diff.bookmarkUpdates.length}'));
    items.add(_DiffRow('Shënimet', '+${diff.noteAdds.length} / upd ${diff.noteUpdates.length}'));
    items.add(_DiffRow('Memorizimi', '+${diff.memorizationAdds.length} / ngritje ${diff.memorizationStatusUpgrades.length}'));
    items.add(_DiffRow('Leximi', '${diff.readingProgressImprovements.length} suresa më të avancuara'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Paraqitja e ndryshimeve (Dry-Run)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...items.map((r) => Row(
          children: [
            Expanded(child: Text(r.label)),
            Text(r.value, style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        )),
      ],
    );
  }

  Widget _buildResultSummary(DataImportResult res) {
    final rows = <_DiffRow>[];
    rows.add(_DiffRow('Cilësimet', res.settingsOverwritten ? 'U zëvendësuan' : '-'));
    rows.add(_DiffRow('Favoritet', '+${res.bookmarksAdded} / upd ${res.bookmarksUpdated}'));
    rows.add(_DiffRow('Shënimet', '+${res.notesAdded} / upd ${res.notesUpdated}'));
    rows.add(_DiffRow('Memorizimi', '+${res.memorizationAdded} / ngritje ${res.memorizationUpgraded}'));
    rows.add(_DiffRow('Leximi', '${res.readingProgressUpdated} suresa'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rezultati i aplikimit', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...rows.map((r) => Row(
          children: [
            Expanded(child: Text(r.label)),
            Text(r.value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        )),
        if (res.errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Gabime:', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
          ...res.errors.map((e) => Text('- $e', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))),
        ],
      ],
    );
  }

  Future<void> _onExport() async {
    setState(() { _loading = true; _error = null; _exportJson = null; });
    try {
      final jsonStr = await _exportService.exportAsJsonString(pretty: true);
      setState(() { _exportJson = jsonStr; });
    } catch (e) {
      setState(() { _error = 'Eksporti dështoi: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _onAnalyze() async {
    setState(() { _loading = true; _error = null; _diff = null; _applyResult = null; });
    try {
      final bundle = await _importService.parse(_importRaw);
      final diff = await _importService.dryRunDiff(bundle);
      setState(() { _diff = diff; });
    } catch (e) {
      setState(() { _error = 'Analiza dështoi: $e'; });
    } finally { setState(() { _loading = false; }); }
  }

  Future<void> _onApply() async {
    if (_diff == null) return;
    setState(() { _loading = true; _error = null; _applyResult = null; });
    try {
      final bundle = await _importService.parse(_importRaw);
      final options = DataImportOptions(
        overwriteSettings: _settings,
        importBookmarks: _bookmarks,
        importNotes: _notes,
        importMemorization: _memorization,
        importReadingProgress: _readingProgress,
      );
      final res = await _importService.applyImport(bundle: bundle, options: options, precomputedDiff: _diff);
      setState(() { _applyResult = res; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importi u aplikua')));
    } catch (e) {
      setState(() { _error = 'Aplikimi dështoi: $e'; });
    } finally { setState(() { _loading = false; }); }
  }
}

class _DiffRow { final String label; final String value; _DiffRow(this.label,this.value); }
