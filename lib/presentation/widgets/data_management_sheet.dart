import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
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
  StreamSubscription? _progressSub;
  ImportProgress? _progress;

  bool _loading = false;
  String? _exportJson;
  String? _exportHash;
  String? _error;
  String _importRaw = '';
  ImportDiff? _diff;
  DataImportResult? _applyResult;
  final Map<String, NoteConflictResolution> _conflictResolutions = {}; // noteId -> choice

  // Domain toggles
  bool _settings = true;
  bool _bookmarks = true;
  bool _notes = true;
  bool _memorization = true;
  bool _readingProgress = true;
  bool _settingsMerge = true; // if partial & user chooses merge instead of full overwrite

  @override
  void initState() {
    super.initState();
    _storageRepository = StorageRepositoryImpl(StorageDataSourceImpl());
    _exportService = DataExportService(storageRepository: _storageRepository);
    _importService = DataImportService(storageRepository: _storageRepository);
    _progressSub = _importService.progressStream.listen((p) {
      if (!mounted) return;
      setState(() { _progress = p; });
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
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
                        final data = _exportJson;
                        if (data == null) return; // safety
                        Clipboard.setData(ClipboardData(text: data));
                        context.read<AppStateProvider>().enqueueSnack('JSON u kopjua');
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Kopjo'),
                    ),
                ],
              ),
              if (_exportJson != null) ...[
                const SizedBox(height: 8),
                _collapsibleJsonPreview('Rezultati', _exportJson!),
                if (_exportHash != null) Padding(
                  padding: const EdgeInsets.only(top:4),
                  child: Text('SHA256: ${_exportHash!.substring(0,16)}…', style: theme.textTheme.bodySmall),
                ),
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
              if (_settings) _settingsStrategyRow(),
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
                  const SizedBox(width: 12),
                  if (_diff != null && _diff!.noteConflicts.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _showConflictResolver(),
                      icon: const Icon(Icons.rule_folder),
          label: Text('Konfliktet (${_resolvedConflictSummary()})'),
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
                _buildProgressUI(),
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
      final hash = sha256.convert(utf8.encode(jsonStr)).toString();
      setState(() { _exportJson = jsonStr; _exportHash = hash; });
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
      if (!_checkVersionCompatibility(bundle.version)) {
        final cont = await _showVersionDialog(bundle.version);
        if (!cont) { setState(()=>_loading=false); return; }
      }
      final diff = await _importService.dryRunDiff(bundle);
      setState(() { _diff = diff; });
    } catch (e) {
      setState(() { _error = 'Analiza dështoi: $e'; });
    } finally { setState(() { _loading = false; }); }
  }

  Future<void> _onApply() async {
    if (_diff == null) return;
    final proceed = await _confirmApply();
    if (!proceed) return;
    setState(() { _loading = true; _error = null; _applyResult = null; });
    try {
      final bundle = await _importService.parse(_importRaw);
      final options = DataImportOptions(
  overwriteSettings: _settings && !_settingsMerge,
        importBookmarks: _bookmarks,
        importNotes: _notes,
        importMemorization: _memorization,
        importReadingProgress: _readingProgress,
        noteConflictResolutions: Map.of(_conflictResolutions),
      );
      final res = await _importService.applyImport(bundle: bundle, options: options, precomputedDiff: _diff);
      setState(() { _applyResult = res; });
  context.read<AppStateProvider>().enqueueSnack('Importi u aplikua');
    } catch (e) {
      setState(() { _error = 'Aplikimi dështoi: $e'; });
    } finally { setState(() { _loading = false; _progress = null; }); }
  }

  Widget _buildProgressUI() {
    final p = _progress;
    final theme = Theme.of(context);
    final label = (){
      if (p == null) return 'Duke punuar…';
      switch (p.phase) {
        case 'init': return p.message ?? 'Përgatitje…';
        case 'settings': return p.message ?? 'Po aplikohen cilësimet…';
        case 'bookmarks': return 'Favoritet (${p.current}/${p.total})';
        case 'notes': return 'Shënimet (${p.current}/${p.total})';
        case 'memorization': return p.message ?? 'Memorizimi…';
        case 'readingProgress': return 'Progresi Leximit (${p.current}/${p.total})';
        case 'done': return p.message ?? 'Përfundoi';
        case 'canceled': return 'U anulua';
        default: return p.message ?? p.phase;
      }
    }();
    final value = p?.ratio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children:[
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          if (p != null && p.phase != 'done' && p.phase != 'canceled')
            TextButton.icon(
              onPressed: _onCancel,
              icon: const Icon(Icons.cancel),
              label: const Text('Anulo'),
            ),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: value),
      ],
    );
  }

  void _onCancel() { _importService.cancelImport(); }

  Future<bool> _confirmApply() async {
    final d = _diff!;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmo Importin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Do të aplikohen:'),
            const SizedBox(height: 8),
            _confirmLine('Cilësimet', _settings && d.settingsChange!=SettingsChange.none),
            _confirmLine('Favoritet', _bookmarks && (d.bookmarkAdds.isNotEmpty || d.bookmarkUpdates.isNotEmpty)),
            _confirmLine('Shënimet', _notes && (d.noteAdds.isNotEmpty || d.noteUpdates.isNotEmpty || d.noteConflicts.isNotEmpty)),
            _confirmLine('Memorizimi', _memorization && (d.memorizationAdds.isNotEmpty || d.memorizationStatusUpgrades.isNotEmpty)),
            _confirmLine('Progresi Leximit', _readingProgress && d.readingProgressImprovements.isNotEmpty),
            if (d.noteConflicts.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top:8),
              child: Text('Konflikte shënimesh: ${d.noteConflicts.length}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            if (d.settingsChange == SettingsChange.partial) Padding(
              padding: const EdgeInsets.only(top:8),
              child: Text(
                _settingsMerge
                    ? 'Cilësimet: MERGE (ruhen vlerat lokale mungese).'
                    : 'Cilësimet: OVERWRITE tërësisht.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('Anulo')),
          ElevatedButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text('Apliko')),
        ],
      ),
    ) ?? false;
  }

  bool _checkVersionCompatibility(int bundleVersion) {
    const current = DataExportService.exportVersion; // requires import at top
    // Simple rule: if bundleVersion > current => incompatible (need upgrade); if older show warning dialog handled separately.
    return bundleVersion <= current;
  }

  Future<bool> _showVersionDialog(int bundleVersion) async {
    const current = DataExportService.exportVersion;
    final newer = bundleVersion > current;
    final older = bundleVersion < current;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Versioni i Pakos'),
        content: Text(newer
            ? 'Paketa është version $bundleVersion ndërsa aplikacioni mbështet $current. Përditëso aplikacionin për të importuar.'
            : older
              ? 'Paketa është version më i vjetër ($bundleVersion < $current). Mund të ketë humbje fushash të reja. Vazhdo?'
              : 'Version i përputhshëm ($bundleVersion).'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: Text(newer? 'Mbyll':'Jo')),
          if (!newer) ElevatedButton(onPressed: ()=>Navigator.pop(ctx,true), child: const Text('Po')),
        ],
      ),
    ) ?? false;
  }

  Widget _confirmLine(String label, bool active) => Row(
    children: [
      Icon(active ? Icons.check_circle : Icons.remove_circle, size: 16, color: active ? Colors.green : Colors.grey),
      const SizedBox(width: 6),
      Expanded(child: Text(label)),
    ],
  );

  void _showConflictResolver() {
    if (_diff == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (c, controller) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children:[const Icon(Icons.rule), const SizedBox(width:8), const Text('Zgjidh Konfliktet')]),
                  const SizedBox(height:8),
                  if (_diff!.noteConflicts.isNotEmpty) _bulkConflictBar(),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: _diff!.noteConflicts.length,
                      itemBuilder: (c,i){
                        final nc = _diff!.noteConflicts[i];
                        final id = nc.id;
                        final selected = _conflictResolutions[id] ?? NoteConflictResolution.import;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Note ID: $id', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height:4),
                                Text('Lokale: '+ (nc.local['content']??'').toString(), maxLines:3, overflow: TextOverflow.ellipsis),
                                const SizedBox(height:4),
                                Text('Import: '+ (nc.imported['content']??'').toString(), maxLines:3, overflow: TextOverflow.ellipsis),
                                const SizedBox(height:6),
                                Row(children:[
                                  Expanded(child: OutlinedButton(
                                    onPressed:(){ setState((){ _conflictResolutions[id]=NoteConflictResolution.local; }); },
                                    style: OutlinedButton.styleFrom(backgroundColor: selected==NoteConflictResolution.local? Colors.green.withOpacity(0.15):null),
                                    child: Text('Mbaj Lokale', style: TextStyle(color: selected==NoteConflictResolution.local? Colors.green: null)),
                                  )),
                                  const SizedBox(width:8),
                                  Expanded(child: ElevatedButton(
                                    onPressed:(){ setState((){ _conflictResolutions[id]=NoteConflictResolution.import; }); },
                                    style: ElevatedButton.styleFrom(backgroundColor: selected==NoteConflictResolution.import? Theme.of(context).colorScheme.primary: null),
                                    child: const Text('Merr Importin'),
                                  )),
                                ])
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height:8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: ()=> Navigator.pop(ctx),
                      icon: const Icon(Icons.done),
                      label: const Text('Ruaj'),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _bulkConflictBar() {
    final total = _diff!.noteConflicts.length;
    final imports = _conflictResolutions.values.where((e)=>e==NoteConflictResolution.import).length;
    final locals = _conflictResolutions.values.where((e)=>e==NoteConflictResolution.local).length;
    return Padding(
      padding: const EdgeInsets.only(bottom:8),
      child: Wrap(spacing:8, runSpacing:4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Chip(label: Text('Gjithsej: $total')),
        Chip(label: Text('Import: $imports')),
        Chip(label: Text('Lokale: $locals')),
        TextButton(onPressed:(){ setState((){ for (final c in _diff!.noteConflicts){ _conflictResolutions[c.id]=NoteConflictResolution.import; } }); }, child: const Text('Import all')),
        TextButton(onPressed:(){ setState((){ for (final c in _diff!.noteConflicts){ _conflictResolutions[c.id]=NoteConflictResolution.local; } }); }, child: const Text('Local all')),
        TextButton(onPressed:(){ setState((){ _conflictResolutions.clear(); }); }, child: const Text('Reset')),
      ]),
    );
  }

  String _resolvedConflictSummary() {
    if (_diff==null) return '0';
    final total = _diff!.noteConflicts.length;
    final decided = _conflictResolutions.length;
    if (decided==0) return '$total';
    return '$decided/$total';
  }

  Widget _settingsStrategyRow() {
    final partial = _diff?.settingsChange == SettingsChange.partial;
    if (!partial) {
      return Row(
        children: [
          const Icon(Icons.tune, size: 18),
          const SizedBox(width:6),
          Text('Strategjia: overwrite (nuk ka merge të nevojshëm)', style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.tune, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Cilësimet (partial):', style: Theme.of(context).textTheme.bodySmall),
              ChoiceChip(label: const Text('Merge'), selected: _settingsMerge, onSelected: (v){ setState(()=>_settingsMerge=true); }),
              ChoiceChip(label: const Text('Overwrite'), selected: !_settingsMerge, onSelected: (v){ setState(()=>_settingsMerge=false); }),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiffRow { final String label; final String value; _DiffRow(this.label,this.value); }
