import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backup_store.dart';

class DriveBackupStore implements BackupStore {
  static const _api = 'https://www.googleapis.com/drive/v3/files';
  final Future<Map<String, String>> Function() headers;
  final http.Client _client;
  String? _folderId;

  DriveBackupStore({required this.headers, http.Client? client})
      : _client = client ?? http.Client();

  Future<http.Response> _send(http.BaseRequest request) async {
    request.headers.addAll(await headers());
    final response = await _client.send(request).timeout(const Duration(seconds: 60));
    final result = await http.Response.fromStream(response);
    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw BackupStoreException(result.statusCode, result.body);
    }
    return result;
  }

  String _escapeQuery(String value) => value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

  Future<String> _getFolderId() async {
    if (_folderId != null) return _folderId!;
    final query = "name='Tigris Backups' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final found = await _send(http.Request('GET', Uri.parse('$_api?q=${Uri.encodeQueryComponent(query)}&fields=files(id)&pageSize=1')));
    final files = (jsonDecode(found.body) as Map<String, dynamic>)['files'] as List<dynamic>? ?? [];
    if (files.isNotEmpty) return _folderId = files.first['id'] as String;
    final create = http.Request('POST', Uri.parse(_api));
    create.headers['Content-Type'] = 'application/json';
    create.body = jsonEncode({
      'name': 'Tigris Backups',
      'mimeType': 'application/vnd.google-apps.folder',
    });
    final created = await _send(create);
    return _folderId = (jsonDecode(created.body) as Map<String, dynamic>)['id'] as String;
  }

  Future<BackupFile> _uploadFile(String name, String content, String mimeType) async {
    final folderId = await _getFolderId();
    final boundary = 'tigris_backup_${DateTime.now().microsecondsSinceEpoch}';
    final request = http.Request('POST', Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'));
    request.headers['Content-Type'] = 'multipart/related; boundary=$boundary';
    request.bodyBytes = utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${jsonEncode({'name': name, 'parents': [folderId]})}\r\n--$boundary\r\nContent-Type: $mimeType; charset=UTF-8\r\n\r\n$content\r\n--$boundary--\r\n');
    final response = await _send(request);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return BackupFile(
      id: data['id'] as String,
      name: data['name'] as String? ?? name,
      createdAt: DateTime.tryParse(data['createdTime'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<BackupFile> upload({required String baseName, required String json, required String readable}) async {
    final uploaded = await _uploadFile('$baseName.json', json, 'application/json');
    try {
      await _uploadFile('$baseName.md', readable, 'text/markdown');
    } catch (_) {
      try {
        await delete(uploaded);
      } catch (_) {}
      rethrow;
    }
    return uploaded;
  }

  @override
  Future<List<BackupFile>> listBackups() async {
    final folderId = await _getFolderId();
    final files = <BackupFile>[];
    String? token;
    do {
      final parameters = {
        'q': "'$folderId' in parents and trashed=false",
        'fields': 'nextPageToken,files(id,name,createdTime)',
        'orderBy': 'createdTime desc',
        'pageSize': '100',
        'pageToken': ?token,
      };
      final response = await _send(http.Request('GET', Uri.parse('$_api?${Uri(queryParameters: parameters).query}')));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      for (final item in (data['files'] as List<dynamic>? ?? [])) {
        final map = item as Map<String, dynamic>;
        final name = map['name'] as String;
        if (name.endsWith('.json')) {
          files.add(BackupFile(id: map['id'] as String, name: name, createdAt: DateTime.parse(map['createdTime'] as String)));
        }
      }
      token = data['nextPageToken'] as String?;
    } while (token != null);
    files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return files;
  }

  @override
  Future<String> download(BackupFile file) async {
    final response = await _send(http.Request('GET', Uri.parse('$_api/${Uri.encodeComponent(file.id)}?alt=media')));
    return utf8.decode(response.bodyBytes);
  }

  Future<void> _deleteId(String id) async {
    final request = http.Request('DELETE', Uri.parse('$_api/${Uri.encodeComponent(id)}'));
    try {
      await _send(request);
    } on BackupStoreException catch (error) {
      if (error.statusCode != 404) rethrow;
    }
  }

  @override
  Future<void> delete(BackupFile file) async {
    await _deleteId(file.id);
    final folderId = await _getFolderId();
    final mdName = file.name.replaceFirst(RegExp(r'\.json$'), '.md');
    final query = "name='${_escapeQuery(mdName)}' and '$folderId' in parents and trashed=false";
    final response = await _send(http.Request('GET', Uri.parse('$_api?q=${Uri.encodeQueryComponent(query)}&fields=files(id)&pageSize=1')));
    final files = (jsonDecode(response.body) as Map<String, dynamic>)['files'] as List<dynamic>? ?? [];
    if (files.isNotEmpty) await _deleteId(files.first['id'] as String);
  }
}
