import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';

/// The evaluation tablet and team phones use the same APK.  No server address
/// is baked into the release build; each device can be pointed at the team's
/// actual HTTPS backend without rebuilding.
class PlanitServerConfig {
  PlanitServerConfig._();

  static const buildUrl = String.fromEnvironment('PLANIT_API_BASE_URL');
  static const storageKey = 'planit_test_backend_url_v1';
  static String _url = buildUrl;

  static String get url => _url;

  static bool isValid(String address) {
    final input = address.trim();
    final uri = Uri.tryParse(input);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return false;
    }
    if (uri.scheme == 'https') return true;
    // Android release builds block cleartext traffic. Do not offer a LAN HTTP
    // setting that the operating system will reject, or transmit credentials
    // unencrypted on classroom Wi-Fi. Use the HTTPS tunnel for release APKs.
    if (kReleaseMode) return false;
    // Plain HTTP is for debug builds talking to a private development host.
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' ||
        host == '10.0.2.2') {
      return true;
    }
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((v) => v == null || v < 0 || v > 255)) return false;
    final a = octets[0]!;
    final b = octets[1]!;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(storageKey);
    if (saved != null && isValid(saved)) _url = saved;
  }

  static Future<void> save(String value) async {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    if (!isValid(normalized)) {
      throw const FormatException('HTTPS 서버 주소를 입력해 주세요. 내부망 HTTP는 개발용 디버그 앱에서만 지원합니다.');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, normalized)) {
      throw StateError('서버 주소를 저장하지 못했습니다.');
    }
    _url = normalized;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(storageKey)) {
      throw StateError('서버 주소 초기화에 실패했습니다.');
    }
    _url = buildUrl;
  }
}
