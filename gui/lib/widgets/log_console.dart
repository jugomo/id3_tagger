import 'package:flutter/material.dart';

import '../models/log_entry.dart';

/// Consola de salida con autoscroll: una línea por LogEntry, coloreada
/// según su tipo (stdout normal, stderr en rojo, resumen en verde/negrita).
class LogConsole extends StatefulWidget {
  final List<LogEntry> entries;

  const LogConsole({super.key, required this.entries});

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.length != oldWidget.entries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color? _colorFor(LogType type, BuildContext context) {
    switch (type) {
      case LogType.stderr:
        return Colors.redAccent;
      case LogType.summary:
        return Colors.greenAccent;
      case LogType.stdout:
        return null;
    }
  }

  FontWeight _weightFor(LogType type) =>
      type == LogType.summary ? FontWeight.bold : FontWeight.normal;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.entries.length,
        itemBuilder: (context, index) {
          final entry = widget.entries[index];
          return Text(
            entry.text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: _colorFor(entry.type, context),
              fontWeight: _weightFor(entry.type),
            ),
          );
        },
      ),
    );
  }
}
