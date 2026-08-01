enum LogType { stdout, stderr, summary }

class LogEntry {
  final String text;
  final LogType type;

  const LogEntry(this.text, this.type);
}
