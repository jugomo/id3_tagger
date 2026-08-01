import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper fino sobre SharedPreferences para los ajustes persistidos de la app.
class SettingsService {
  static const _kLastDirectory = 'last_directory';
  static const _kDatosPath = 'datos_path';
  static const _kOnline = 'online';
  static const _kDiscogsToken = 'discogs_token';
  static const _kDryRun = 'dry_run';
  static const _kDebug = 'debug';
  static const _kGeneroPorDefecto = 'genero_por_defecto';
  static const _kScriptPathOverride = 'script_path_override';

  Future<String?> getLastDirectory() async =>
      (await SharedPreferences.getInstance()).getString(_kLastDirectory);
  Future<void> setLastDirectory(String value) async =>
      (await SharedPreferences.getInstance()).setString(_kLastDirectory, value);

  Future<String?> getDatosPath() async =>
      (await SharedPreferences.getInstance()).getString(_kDatosPath);
  Future<void> setDatosPath(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_kDatosPath);
    } else {
      await prefs.setString(_kDatosPath, value);
    }
  }

  Future<bool> getOnline() async =>
      (await SharedPreferences.getInstance()).getBool(_kOnline) ?? true;
  Future<void> setOnline(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_kOnline, value);

  Future<String?> getDiscogsToken() async =>
      (await SharedPreferences.getInstance()).getString(_kDiscogsToken);
  Future<void> setDiscogsToken(String value) async =>
      (await SharedPreferences.getInstance()).setString(_kDiscogsToken, value);

  Future<bool> getDryRun() async =>
      (await SharedPreferences.getInstance()).getBool(_kDryRun) ?? false;
  Future<void> setDryRun(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_kDryRun, value);

  Future<bool> getDebug() async =>
      (await SharedPreferences.getInstance()).getBool(_kDebug) ?? false;
  Future<void> setDebug(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_kDebug, value);

  Future<String?> getGeneroPorDefecto() async =>
      (await SharedPreferences.getInstance()).getString(_kGeneroPorDefecto);
  Future<void> setGeneroPorDefecto(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_kGeneroPorDefecto);
    } else {
      await prefs.setString(_kGeneroPorDefecto, value);
    }
  }

  Future<String?> getScriptPathOverride() async =>
      (await SharedPreferences.getInstance()).getString(_kScriptPathOverride);
  Future<void> setScriptPathOverride(String value) async =>
      (await SharedPreferences.getInstance())
          .setString(_kScriptPathOverride, value);
}
