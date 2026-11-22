import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meetsync/services/planit_server_config.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('classroom server URLs reject credentials and unsafe public cleartext', () {
    expect(PlanitServerConfig.isValid('https://classroom.example.com'), isTrue);
    expect(PlanitServerConfig.isValid('https://classroom.example.com/path'), isFalse);
    expect(PlanitServerConfig.isValid('http://192.168.0.5:8000'), isTrue);
    expect(PlanitServerConfig.isValid('http://10.0.2.2:8000'), isTrue);
    expect(PlanitServerConfig.isValid('http://8.8.8.8:8000'), isFalse);
    expect(PlanitServerConfig.isValid('https://alice:secret@host.com'), isFalse);
    expect(PlanitServerConfig.isValid('https://host.com/?token=secret'), isFalse);
    expect(PlanitServerConfig.isValid(''), isFalse);
  });

  test('server setting persists across app restarts', () async {
    await PlanitServerConfig.save('https://classroom.example.com/');
    expect(PlanitServerConfig.url, 'https://classroom.example.com');
    await PlanitServerConfig.load();
    expect(PlanitServerConfig.url, 'https://classroom.example.com');
    await PlanitServerConfig.reset();
    expect(PlanitServerConfig.url, PlanitServerConfig.buildUrl);
  });
}
