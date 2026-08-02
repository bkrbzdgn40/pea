import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/workout_diagnostics.dart';
import '../../infrastructure/services/diagnostics_json_file_exporter.dart';
import 'workout_diagnostics_components.dart';
import 'workout_diagnostics_snapshot_view.dart';

typedef DiagnosticsJsonFileExporter =
    Future<void> Function({
      required String json,
      required String fileName,
      Rect? sharePositionOrigin,
    });

class WorkoutDiagnosticsPanel extends StatefulWidget {
  const WorkoutDiagnosticsPanel({
    required this.snapshotReader,
    required this.onReset,
    this.copyText,
    this.exportJsonFile,
    this.refreshInterval = const Duration(seconds: 2),
    super.key,
  });

  final WorkoutDiagnosticsSnapshot Function() snapshotReader;
  final VoidCallback onReset;
  final Future<void> Function(String text)? copyText;
  final DiagnosticsJsonFileExporter? exportJsonFile;
  final Duration refreshInterval;

  @override
  State<WorkoutDiagnosticsPanel> createState() =>
      _WorkoutDiagnosticsPanelState();
}

class _WorkoutDiagnosticsPanelState extends State<WorkoutDiagnosticsPanel> {
  Timer? _pollingTimer;
  WorkoutDiagnosticsSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _tryReadSnapshot();
    _pollingTimer = Timer.periodic(widget.refreshInterval, (_) {
      _refreshSnapshot();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Beta Diagnostics',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: snapshot == null
                    ? const Center(
                        child: Text('Diagnostics snapshot okunamad\u0131.'),
                      )
                    : WorkoutDiagnosticsSnapshotView(snapshot: snapshot),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 12,
                  overflowSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _handleCopyJson,
                      child: const Text("JSON'u Kopyala"),
                    ),
                    OutlinedButton(
                      onPressed: _handleExportJsonFile,
                      child: const Text('JSON Dosyasını Paylaş'),
                    ),
                    OutlinedButton(
                      onPressed: _handleReset,
                      child: const Text(
                        'Saya\u00e7lar\u0131 S\u0131f\u0131rla',
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Kapat'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  WorkoutDiagnosticsSnapshot? _tryReadSnapshot() {
    try {
      return widget.snapshotReader();
    } catch (_) {
      return null;
    }
  }

  void _refreshSnapshot() {
    final nextSnapshot = _tryReadSnapshot();
    if (!mounted || nextSnapshot == null) {
      return;
    }
    setState(() => _snapshot = nextSnapshot);
  }

  Future<void> _handleCopyJson() async {
    final snapshot = _tryReadSnapshot();
    if (snapshot == null) {
      return;
    }
    final text = const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
    final copy = widget.copyText ?? _copyWithClipboard;
    try {
      await copy(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostics JSON panoya kopyaland\u0131.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostics JSON kopyalanamad\u0131.')),
      );
    }
  }

  Future<void> _copyWithClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _handleExportJsonFile() async {
    final snapshot = _tryReadSnapshot();
    if (snapshot == null) {
      return;
    }
    final json = const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
    final exporter = widget.exportJsonFile ?? shareDiagnosticsJsonFile;
    final renderBox = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
    try {
      await exporter(
        json: json,
        fileName: buildDiagnosticsFileName(snapshot),
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostics JSON dosyası paylaşılamadı.'),
        ),
      );
    }
  }

  void _handleReset() {
    widget.onReset();
    _refreshSnapshot();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Diagnostics saya\u00e7lar\u0131 s\u0131f\u0131rland\u0131.',
        ),
      ),
    );
  }
}
