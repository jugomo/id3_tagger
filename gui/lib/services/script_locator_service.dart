import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'settings_service.dart';

/// Localiza id3_tagger.py sin empaquetarlo como asset: el script sigue
/// viviendo en el repo (el usuario lo edita activamente), así que se
/// resuelve su ruta en disco en vez de congelar una copia en el build.
class ScriptLocatorService {
  final SettingsService settings;

  ScriptLocatorService(this.settings);

  /// Orden de resolución: ruta guardada -> autodetección relativa al cwd
  /// (caso normal de `flutter run` desde gui/) -> null si no se encuentra.
  Future<String?> resolve() async {
    final saved = await settings.getScriptPathOverride();
    if (saved != null && File(saved).existsSync()) {
      return saved;
    }

    for (final candidate in _autodetectCandidates()) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return null;
  }

  List<String> _autodetectCandidates() {
    final cwd = Directory.current;
    return [
      cwd.parent.uri.resolve('id3_tagger.py').toFilePath(),
      cwd.uri.resolve('../id3_tagger.py').toFilePath(),
    ];
  }

  /// Abre un selector de fichero .py y persiste la elección del usuario.
  Future<String?> pickManually() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Python', extensions: ['py']),
      ],
    );
    if (file == null) return null;
    await settings.setScriptPathOverride(file.path);
    return file.path;
  }
}
