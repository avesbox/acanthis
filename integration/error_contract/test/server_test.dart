import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart' as a;
import 'package:serinus/serinus.dart';
import 'package:test/test.dart';

class _Controller extends Controller {
  _Controller() : super('/') {
    final schema = a.object({'email': a.string().min(3)});
    on(Route.post('/validate'), (context) async {
      final result = schema.tryParse(context.body);
      context.response.statusCode = result.isValid ? 200 : 422;
      return result.issues.toTransport();
    });
  }
}

class _Module extends Module {
  _Module() : super(controllers: [_Controller()]);
}

void main() {
  test(
    'real HTTP request returns locale-independent diagnostics to JS',
    () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final app = await serinus.createApplication(
        entrypoint: _Module(),
        host: '127.0.0.1',
        port: port,
      );
      await app.serve();
      addTearDown(app.close);
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:$port/validate'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'email': 'x'}));
      final response = await request.close();
      expect(response.statusCode, 422);
      final body = await response.transform(utf8.decoder).join();
      final envelope = jsonDecode(body) as Map;
      expect(envelope['version'], 1);
      expect(envelope['issues'], [
        {
          'path': ['email'],
          'code': 'minLength',
          'parameters': {'value': 3},
        },
      ]);
      final file = File('.dart_tool/response.json');
      await file.writeAsString(body);
      final js = await Process.run('node', ['consumer.mjs', file.path]);
      expect(js.exitCode, 0, reason: '${js.stdout}\n${js.stderr}');
    },
  );
}
