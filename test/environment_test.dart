import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/config/environment.dart';

void main() {
  test('default API base URL is safe for native release builds', () {
    final uri = Uri.parse(Environment.apiBaseUrl);

    expect(uri.isAbsolute, isTrue);
    expect(uri.scheme, 'https');
    expect(uri.host, 'parkplatz.smarbiz.sbs');
    expect(uri.path, '/api');
  });
}
