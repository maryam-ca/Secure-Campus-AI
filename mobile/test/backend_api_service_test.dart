import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:securecampus/services/backend_api_service.dart';

void main() {
  BackendApiService service(MockClient client) => BackendApiService(baseUrl: 'http://localhost:8000', client: client);

  group('unreachableReason', () {
    test('nothing answers: tells the Admin to start the service', () async {
      final s = service(MockClient((_) async => throw http.ClientException('refused')));
      final reason = await s.unreachableReason();
      expect(reason, contains('Cannot reach the account service at http://localhost:8000'));
      expect(reason, contains('run.bat'));
    });

    test('another program answers on the same address: says so', () async {
      final s = service(MockClient((_) async => http.Response('{"detail":"Not Found"}', 404)));
      expect(await s.unreachableReason(), contains('Another program is answering'));
    });

    test('a non-JSON answer from another program is also reported as another program', () async {
      final s = service(MockClient((_) async => http.Response('<html>', 200)));
      expect(await s.unreachableReason(), contains('Another program is answering'));
    });

    test('our own service answers: says it is running and to try again', () async {
      final s = service(MockClient((_) async => http.Response('{"status":"ok","service":"iris_ai"}', 200)));
      expect(await s.unreachableReason(), contains('is running'));
    });
  });
}
