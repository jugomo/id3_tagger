import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/log_entry.dart';

/// Lanza id3_tagger.py como subproceso y transmite su salida línea a línea.
class TaggerProcessService {
  Process? _process;

  bool get isRunning => _process != null;

  /// Ejecuta el script y devuelve su código de salida.
  ///
  /// El token de Discogs se pasa por variable de entorno (no por argv) para
  /// que no quede visible en `ps`/Activity Monitor. `-u` es imprescindible:
  /// sin él, Python bufferea stdout por bloques al no haber una tty, y el
  /// log parecería colgado hasta que el proceso termina.
  Future<int> run({
    required String pythonPath,
    required String scriptPath,
    required List<String> args,
    String? discogsToken,
    required void Function(LogEntry entry) onLine,
  }) async {
    final process = await Process.start(
      pythonPath,
      ['-u', scriptPath, ...args],
      environment: {
        if (discogsToken != null && discogsToken.isNotEmpty)
          'DISCOGS_TOKEN': discogsToken,
        'PYTHONUNBUFFERED': '1',
      },
      includeParentEnvironment: true,
    );
    _process = process;

    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => onLine(LogEntry(line, LogType.stdout)))
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => onLine(LogEntry(line, LogType.stderr)))
        .asFuture<void>();

    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    _process = null;
    return exitCode;
  }

  /// Pide al proceso que termine (sigterm) y lo mata a la fuerza (sigkill)
  /// si sigue vivo tras un breve margen, por si está bloqueado en red.
  Future<void> cancel() async {
    final process = _process;
    if (process == null) return;
    process.kill(ProcessSignal.sigterm);
    await Future.delayed(const Duration(seconds: 2));
    if (_process != null) {
      _process!.kill(ProcessSignal.sigkill);
    }
  }
}
