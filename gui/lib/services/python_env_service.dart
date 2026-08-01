import 'dart:convert';
import 'dart:io';

/// Detecta python3/pip3 en el sistema y comprueba/instala las dependencias
/// que necesita id3_tagger.py (mutagen, requests).
class PythonEnvService {
  static const _knownPythonPaths = [
    '/usr/bin/python3',
    '/opt/homebrew/bin/python3',
    '/usr/local/bin/python3',
  ];

  final _moduleNotFoundRe =
      RegExp(r"ModuleNotFoundError: No module named '(\w+)'");

  /// Busca un python3 utilizable: primero rutas absolutas conocidas, y si
  /// ninguna existe recurre a un shell de login (un .app lanzado desde
  /// Finder no hereda el PATH de .zshrc).
  Future<String?> detectPython3() async {
    for (final path in _knownPythonPaths) {
      if (File(path).existsSync()) return path;
    }

    try {
      final result =
          await Process.run('/bin/zsh', ['-lc', 'which python3']);
      final path = (result.stdout as String).trim();
      if (result.exitCode == 0 && path.isNotEmpty && File(path).existsSync()) {
        return path;
      }
    } catch (_) {
      // sin shell disponible o sin python3 en PATH: se maneja como no encontrado
    }
    return null;
  }

  String _pipPathFor(String pythonPath) {
    if (pythonPath.contains('python3')) {
      return pythonPath.replaceFirst('python3', 'pip3');
    }
    return '${File(pythonPath).parent.path}/pip3';
  }

  /// Devuelve la lista de módulos que faltan (vacía si están todos disponibles).
  Future<List<String>> checkMissingDeps(String pythonPath) async {
    final result = await Process.run(
      pythonPath,
      ['-c', 'import mutagen, requests'],
    );
    if (result.exitCode == 0) return [];

    final stderr = result.stderr as String;
    final match = _moduleNotFoundRe.firstMatch(stderr);
    if (match != null) {
      // Solo detectamos el primer módulo faltante por ejecución (Python
      // aborta el import en el primero); reintentar tras instalarlo revela
      // el siguiente si lo hubiera.
      return [match.group(1)!];
    }
    return ['mutagen', 'requests'];
  }

  /// Instala mutagen y requests con `pip3 install --user`, emitiendo cada
  /// línea de salida a onLine para mostrarla en el log de la app.
  Future<int> installDeps(
    String pythonPath,
    void Function(String line) onLine,
  ) async {
    final pipPath = _pipPathFor(pythonPath);
    final executable = File(pipPath).existsSync() ? pipPath : pythonPath;
    final args = File(pipPath).existsSync()
        ? ['install', '--user', 'mutagen', 'requests']
        : ['-m', 'pip', 'install', '--user', 'mutagen', 'requests'];

    final process = await Process.start(executable, args);
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine);
    return process.exitCode;
  }
}
