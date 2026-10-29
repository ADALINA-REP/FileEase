import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  final String id;
  final String toolTitle;
  final String fileName;
  final String filePath;
  final int originalBytes;
  final int resultBytes;
  final DateTime timestamp;

  const HistoryEntry({
    required this.id,
    required this.toolTitle,
    required this.fileName,
    required this.filePath,
    required this.originalBytes,
    required this.resultBytes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'toolTitle': toolTitle,
    'fileName': fileName,
    'filePath': filePath,
    'originalBytes': originalBytes,
    'resultBytes': resultBytes,
    'timestamp': timestamp.toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    toolTitle: json['toolTitle'] as String,
    fileName: json['fileName'] as String,
    filePath: json['filePath'] as String,
    originalBytes: json['originalBytes'] as int,
    resultBytes: json['resultBytes'] as int,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class HistoryService extends ChangeNotifier {
  static const String _storageKey = 'fileease_operation_history';
  static final HistoryService instance = HistoryService._internal();

  HistoryService._internal();

  List<HistoryEntry> _entries = [];
  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// Total saved bytes across all operations
  int get totalBytesSaved {
    int saved = 0;
    for (final e in _entries) {
      if (e.originalBytes > e.resultBytes) {
        saved += (e.originalBytes - e.resultBytes);
      }
    }
    return saved;
  }

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _entries = decoded
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      _entries = [];
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addEntry({
    required String toolTitle,
    required String fileName,
    required String filePath,
    required int originalBytes,
    required int resultBytes,
  }) async {
    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      toolTitle: toolTitle,
      fileName: fileName,
      filePath: filePath,
      originalBytes: originalBytes,
      resultBytes: resultBytes,
      timestamp: DateTime.now(),
    );

    // Keep the most recent 50 operations to remain ultra-light
    _entries.insert(0, entry);
    if (_entries.length > 50) {
      _entries = _entries.sublist(0, 50);
    }

    notifyListeners();
    await _save();
  }

  Future<void> removeEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> clearAll() async {
    _entries.clear();
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }
}
