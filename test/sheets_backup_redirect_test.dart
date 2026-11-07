import 'dart:convert';
import 'dart:io';

import 'package:dasboardreport/sync/sheets_backup.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresi laporan user 2026-11-07: backup ke Google Sheets gagal dengan
/// "HTTP 302". Google Apps Script membalas POST ke URL /exec dengan 302
/// menuju script.googleusercontent.com; HttpClient bawaan mengubah POST 302
/// -> GET tanpa body, sehingga doPost tidak pernah menerima payload (dan
/// script ini tidak punya doGet). Perbaikan: SheetsBackup.postJson mengikuti
/// redirect secara manual dengan POST ulang + body yang sama.
void main() {
  group('SheetsBackup.postJson (redirect Apps Script)', () {
    late HttpServer server;
    late Uri base;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = Uri.parse('http://127.0.0.1:${server.port}');
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('302 ke URL baru: body ikut ter-POST ulang (bukan jadi GET)', () async {
      String? echoBody;
      String? echoMethod;
      server.listen((req) async {
        if (req.uri.path == '/exec') {
          req.response.statusCode = 302;
          req.response.headers.set('location', '/echo');
          await req.response.close();
        } else if (req.uri.path == '/echo') {
          echoMethod = req.method;
          echoBody = await utf8.decodeStream(req);
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({'ok': true}));
          await req.response.close();
        } else {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
      final sent = jsonEncode({'type': 'backup', 'tabs': {}});
      final res =
          await SheetsBackup.postJson(base.replace(path: '/exec'), sent);
      expect(res.statusCode, 200);
      expect(echoMethod, 'POST');
      expect(echoBody, sent);
      expect(jsonDecode(res.body)['ok'], isTrue);
    });

    test('backup() sukses bila script menjawab {"ok":true} setelah redirect',
        () async {
      server.listen((req) async {
        if (req.uri.path == '/exec') {
          req.response.statusCode = 302;
          req.response.headers.set('location', '/echo');
          await req.response.close();
        } else {
          await utf8.decodeStream(req);
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({'ok': true, 'written': {}}));
          await req.response.close();
        }
      });
      final result = await SheetsBackup.backup(
        {'type': 'backup', 'tabs': {}},
        urlOverride: base.replace(path: '/exec'),
      );
      expect(result.ok, isTrue);
    });

    test('backup() gagal dengan jelas bila script menjawab HTML (halaman login)',
        () async {
      server.listen((req) async {
        req.response.statusCode = 200;
        req.response.headers.contentType = ContentType.html;
        req.response.write('<html><body>Sign in</body></html>');
        await req.response.close();
      });
      final result = await SheetsBackup.backup(
        {'type': 'backup', 'tabs': {}},
        urlOverride: base.replace(path: '/exec'),
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('JSON'));
    });

    test('redirect berantai berhenti setelah batas dan melapor HTTP 302',
        () async {
      server.listen((req) async {
        req.response.statusCode = 302;
        req.response.headers.set('location', '/exec');
        await req.response.close();
      });
      final res = await SheetsBackup.postJson(
        base.replace(path: '/exec'),
        '{}',
        maxRedirects: 2,
      );
      expect(res.statusCode, 302);
    });
  });
}
