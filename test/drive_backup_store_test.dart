import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tigris/repositories/backup_store.dart';
import 'package:tigris/repositories/drive_backup_store.dart';

void main() {
  test('finds a folder and lists json backups across pages', () async {
    var calls = 0;
    final store = DriveBackupStore(headers: () async => {'Authorization': 'Bearer token'}, client: MockClient((request) async {
      calls++;
      if (calls == 1) return http.Response('{"files":[{"id":"folder"}]}', 200);
      if (calls == 2) return http.Response('{"files":[{"id":"one","name":"one.json","createdTime":"2025-01-01T00:00:00Z"},{"id":"md","name":"one.md","createdTime":"2025-01-01T00:00:00Z"}],"nextPageToken":"next"}', 200);
      return http.Response('{"files":[{"id":"two","name":"two.json","createdTime":"2025-01-02T00:00:00Z"}]}', 200);
    }));
    final files = await store.listBackups();
    expect(files.map((file) => file.name), ['two.json', 'one.json']);
  });

  test('creates folder and multipart uploads into it', () async {
    final requests = <http.BaseRequest>[];
    final store = DriveBackupStore(headers: () async => {}, client: MockClient((request) async {
      requests.add(request);
      if (requests.length == 1) return http.Response('{"files":[]}', 200);
      if (requests.length == 2) return http.Response('{"id":"folder"}', 200);
      return http.Response('{"id":"${requests.length}","name":"file"}', 200);
    }));
    await store.upload(baseName: 'file', json: '{}', readable: '# notes');
    expect(requests.where((request) => request.url.toString().contains('uploadType=multipart')).length, 2);
  });

  test('download decodes utf8 and errors include status', () async {
    final store = DriveBackupStore(headers: () async => {}, client: MockClient((request) async => http.Response.bytes(utf8.encode('你好 Àlàáfíà'), 200)));
    expect(await store.download(BackupFile(id: 'id', name: 'x.json', createdAt: DateTime.now())), '你好 Àlàáfíà');
    final denied = DriveBackupStore(headers: () async => {}, client: MockClient((request) async => http.Response('no', 403)));
    expect(() => denied.download(BackupFile(id: 'id', name: 'x.json', createdAt: DateTime.now())), throwsA(isA<BackupStoreException>()));
  });

  test('multipart upload names the file and puts it in the folder', () async {
    final bodies = <String>[];
    final store = DriveBackupStore(headers: () async => {}, client: MockClient((request) async {
      if (request.url.path.contains('upload')) {
        bodies.add(request.body);
        return http.Response('{"id":"x"}', 200);
      }
      return http.Response('{"files":[{"id":"folder"}]}', 200);
    }));
    await store.upload(baseName: 'file', json: '{"a":"你好"}', readable: '# notes');
    expect(bodies[0], allOf(contains('file.json'), contains('"folder"'), contains('{"a":"你好"}')));
    expect(bodies[1], allOf(contains('file.md'), contains('# notes')));
  });

  test('removes the json when the readable upload fails', () async {
    var uploads = 0;
    final deleted = <String>[];
    final store = DriveBackupStore(headers: () async => {}, client: MockClient((request) async {
      if (request.method == 'DELETE') {
        deleted.add(request.url.pathSegments.last);
        return http.Response('', 204);
      }
      if (request.url.path.contains('upload')) {
        return ++uploads == 1 ? http.Response('{"id":"json1","name":"f.json"}', 200) : http.Response('boom', 500);
      }
      if ((request.url.queryParameters['q'] ?? '').contains('.md')) {
        return http.Response('{"files":[]}', 200);
      }
      return http.Response('{"files":[{"id":"folder"}]}', 200);
    }));
    await expectLater(store.upload(baseName: 'f', json: '{}', readable: 'x'), throwsA(isA<BackupStoreException>()));
    expect(deleted, ['json1']);
  });

  test('delete ignores 404 and escapes quotes in names', () async {
    final queries = <String>[];
    final store = DriveBackupStore(headers: () async => {}, client: MockClient((request) async {
      if (request.method == 'DELETE') return http.Response('gone', 404);
      queries.add(request.url.queryParameters['q'] ?? '');
      return http.Response('{"files":[{"id":"found"}]}', 200);
    }));
    await store.delete(BackupFile(id: 'id', name: "it's.json", createdAt: DateTime.now()));
    expect(queries.last, contains(r"it\'s.md"));
  });
}
