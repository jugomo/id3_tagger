import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'models/log_entry.dart';
import 'services/python_env_service.dart';
import 'services/script_locator_service.dart';
import 'services/settings_service.dart';
import 'services/tagger_process_service.dart';
import 'widgets/log_console.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _settings = SettingsService();
  late final _scriptLocator = ScriptLocatorService(_settings);
  final _pythonEnv = PythonEnvService();
  final _taggerProcess = TaggerProcessService();

  final _tokenController = TextEditingController();
  final _generoController = TextEditingController();

  String? _directorio;
  String? _datosPath;
  bool _online = true;
  bool _dryRun = false;
  bool _debug = false;

  String? _scriptPath;
  String? _pythonPath;
  List<String>? _missingDeps;
  bool _checkingDeps = false;
  bool _installingDeps = false;

  bool _isRunning = false;
  bool _finished = false;
  final List<LogEntry> _logEntries = [];
  int _procesados = 0;
  int _omitidos = 0;
  int _errores = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _generoController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final lastDir = await _settings.getLastDirectory();
    final datosPath = await _settings.getDatosPath();
    final online = await _settings.getOnline();
    var token = await _settings.getDiscogsToken();
    token ??= Platform.environment['DISCOGS_TOKEN'];
    final dryRun = await _settings.getDryRun();
    final debug = await _settings.getDebug();
    final genero = await _settings.getGeneroPorDefecto();

    final scriptPath = await _scriptLocator.resolve();
    final python = await _pythonEnv.detectPython3();

    if (!mounted) return;
    setState(() {
      _directorio = lastDir;
      _datosPath = datosPath;
      _online = online;
      _tokenController.text = token ?? '';
      _dryRun = dryRun;
      _debug = debug;
      _generoController.text = genero ?? '';
      _scriptPath = scriptPath;
      _pythonPath = python;
    });

    if (python != null) {
      await _checkDeps();
    }
  }

  Future<void> _persistSettings() async {
    if (_directorio != null) {
      await _settings.setLastDirectory(_directorio!);
    }
    await _settings.setDatosPath(_datosPath);
    await _settings.setOnline(_online);
    if (_tokenController.text.trim().isNotEmpty) {
      await _settings.setDiscogsToken(_tokenController.text.trim());
    }
    await _settings.setDryRun(_dryRun);
    await _settings.setDebug(_debug);
    await _settings.setGeneroPorDefecto(_generoController.text.trim());
  }

  Future<void> _pickDirectory() async {
    final path = await getDirectoryPath();
    if (path == null) return;
    setState(() => _directorio = path);
  }

  Future<void> _pickDatosFile() async {
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'Texto', extensions: ['txt']),
    ]);
    if (file == null) return;
    setState(() => _datosPath = file.path);
  }

  Future<void> _pickScript() async {
    final path = await _scriptLocator.pickManually();
    if (path == null) return;
    setState(() => _scriptPath = path);
    await _checkDeps();
  }

  Future<void> _checkDeps() async {
    setState(() => _checkingDeps = true);
    var python = _pythonPath;
    python ??= await _pythonEnv.detectPython3();
    if (python == null) {
      if (!mounted) return;
      setState(() {
        _pythonPath = null;
        _missingDeps = null;
        _checkingDeps = false;
      });
      return;
    }
    final missing = await _pythonEnv.checkMissingDeps(python);
    if (!mounted) return;
    setState(() {
      _pythonPath = python;
      _missingDeps = missing;
      _checkingDeps = false;
    });
  }

  Future<void> _installDeps() async {
    if (_pythonPath == null) return;
    setState(() => _installingDeps = true);
    await _pythonEnv.installDeps(_pythonPath!, (line) {
      _appendEntry(LogEntry(line, LogType.stdout));
    });
    if (!mounted) return;
    setState(() => _installingDeps = false);
    await _checkDeps();
  }

  List<String> _buildArgs() {
    final genero = _generoController.text.trim();
    return [
      '--dir', _directorio!,
      if (_datosPath != null) ...['--datos', _datosPath!],
      if (_online) '--online',
      if (genero.isNotEmpty) ...['--genero-por-defecto', genero],
      if (_debug) '--debug',
      if (_dryRun) '--dry-run',
    ];
  }

  void _appendEntry(LogEntry raw) {
    var entry = raw;
    final text = raw.text;
    final trimmed = text.trimLeft();
    if (raw.type == LogType.stdout && trimmed.startsWith('Listo')) {
      entry = LogEntry(text, LogType.summary);
    }

    if (text.contains('sin datos')) {
      _omitidos++;
    } else if (RegExp(r'^\S+\.mp3: ').hasMatch(text)) {
      _procesados++;
    } else if (trimmed.startsWith('!') || raw.type == LogType.stderr) {
      _errores++;
    }

    if (!mounted) return;
    setState(() => _logEntries.add(entry));
  }

  Future<void> _run() async {
    if (_directorio == null || _scriptPath == null || _pythonPath == null) {
      return;
    }
    await _persistSettings();
    setState(() {
      _logEntries.clear();
      _procesados = 0;
      _omitidos = 0;
      _errores = 0;
      _isRunning = true;
      _finished = false;
    });

    final exitCode = await _taggerProcess.run(
      pythonPath: _pythonPath!,
      scriptPath: _scriptPath!,
      args: _buildArgs(),
      discogsToken: _tokenController.text.trim(),
      onLine: _appendEntry,
    );

    if (exitCode != 0) {
      _appendEntry(
        LogEntry('Proceso terminado con código $exitCode', LogType.stderr),
      );
    }

    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _finished = true;
    });
  }

  Future<void> _cancel() async {
    await _taggerProcess.cancel();
    _appendEntry(const LogEntry('Cancelado por el usuario', LogType.stderr));
  }

  String _depsStatusLabel() {
    if (_pythonPath == null) return 'python3: no encontrado';
    if (_checkingDeps) return 'python3: $_pythonPath — comprobando…';
    if (_missingDeps == null) return 'python3: $_pythonPath';
    if (_missingDeps!.isEmpty) {
      return 'python3: $_pythonPath — ✓ mutagen, requests';
    }
    return 'python3: $_pythonPath — ✗ faltan: ${_missingDeps!.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final canRun = _directorio != null &&
        _scriptPath != null &&
        _pythonPath != null &&
        !_isRunning;

    return Scaffold(
      appBar: AppBar(title: const Text('ID3 Tagger')),
      body: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pathRow(
                    label: 'Carpeta con MP3s',
                    value: _directorio,
                    onBrowse: _isRunning ? null : _pickDirectory,
                  ),
                  const SizedBox(height: 8),
                  _pathRow(
                    label: 'Fichero de correcciones (opcional)',
                    value: _datosPath,
                    onBrowse: _isRunning ? null : _pickDatosFile,
                    onClear: (_datosPath != null && !_isRunning)
                        ? () => setState(() => _datosPath = null)
                        : null,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Buscar online (MusicBrainz + Discogs)'),
                    value: _online,
                    onChanged: _isRunning
                        ? null
                        : (v) => setState(() => _online = v ?? true),
                  ),
                  TextField(
                    controller: _tokenController,
                    enabled: !_isRunning,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Token de Discogs',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Dry run'),
                          value: _dryRun,
                          onChanged: _isRunning
                              ? null
                              : (v) => setState(() => _dryRun = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Debug'),
                          value: _debug,
                          onChanged: _isRunning
                              ? null
                              : (v) => setState(() => _debug = v ?? false),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _generoController,
                    enabled: !_isRunning,
                    decoration: const InputDecoration(
                      labelText: 'Género por defecto (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(_depsStatusLabel())),
                      TextButton(
                        onPressed: _isRunning ? null : _checkDeps,
                        child: const Text('Verificar'),
                      ),
                      if (_missingDeps != null && _missingDeps!.isNotEmpty)
                        FilledButton(
                          onPressed:
                              (_isRunning || _installingDeps) ? null : _installDeps,
                          child: Text(
                            _installingDeps ? 'Instalando…' : 'Instalar deps',
                          ),
                        ),
                    ],
                  ),
                  if (_scriptPath == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'No se ha encontrado id3_tagger.py automáticamente.',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                          TextButton(
                            onPressed: _isRunning ? null : _pickScript,
                            child: const Text('Localizar script...'),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Script: $_scriptPath',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: canRun ? _run : null,
                        child: const Text('Etiquetar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _isRunning ? _cancel : null,
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                  if (_finished)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Procesados: $_procesados · Omitidos: $_omitidos · '
                            'Errores: $_errores',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: LogConsole(entries: _logEntries)),
        ],
      ),
    );
  }

  Widget _pathRow({
    required String label,
    required String? value,
    required VoidCallback? onBrowse,
    VoidCallback? onClear,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            readOnly: true,
            controller: TextEditingController(text: value ?? ''),
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: onBrowse, child: const Text('Examinar')),
        if (onClear != null)
          TextButton(onPressed: onClear, child: const Text('Quitar')),
      ],
    );
  }
}
