import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamz/data/local/media_scanner.dart';
import 'package:streamz/data/local/progress_store.dart';
import 'package:streamz/data/network/media_api_client.dart';
import 'package:streamz/data/repositories/media_repository.dart';
import 'package:streamz/domain/services/device_id_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('health probe uses the lightweight health endpoint', () async {
    final client = MediaApiClient(
      '192.168.1.5',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/health');
        return http.Response('{"ready":true,"protocolVersion":1}', 200);
      }),
    );

    expect(await client.ping(), isTrue);
    client.close();
  });

  test(
    'health probe rejects a successful response from an unready host',
    () async {
      final client = MediaApiClient(
        '192.168.1.5',
        httpClient: MockClient(
          (_) async => http.Response('{"ready":false}', 200),
        ),
      );

      expect(await client.ping(), isFalse);
      client.close();
    },
  );

  test(
    'station fetch errors are not mistaken for an empty station list',
    () async {
      final client = MediaApiClient(
        '192.168.1.5',
        httpClient: MockClient(
          (_) async => http.Response('temporarily unavailable', 503),
        ),
      );

      await expectLater(client.fetchStations, throwsA(isA<Exception>()));
      client.close();
    },
  );

  test(
    'replacing and clearing a host closes its HTTP connection pool',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = MediaRepository(
        scanner: MediaScanner(),
        progress: ProgressStore(preferences),
        preferences: preferences,
        deviceId: DeviceIdService(preferences),
      );
      final firstTransport = _CloseTrackingClient();
      final secondTransport = _CloseTrackingClient();

      repository
        ..client = MediaApiClient('192.168.1.5', httpClient: firstTransport)
        ..client = MediaApiClient('192.168.1.6', httpClient: secondTransport);
      expect(firstTransport.isClosed, isTrue);

      repository.clearClient();
      expect(secondTransport.isClosed, isTrue);
    },
  );
}

class _CloseTrackingClient extends MockClient {
  _CloseTrackingClient() : super((_) async => http.Response('', 200));

  bool isClosed = false;

  @override
  void close() {
    isClosed = true;
    super.close();
  }
}
