import 'package:flutter_test/flutter_test.dart';
import 'package:fs_valetfusion/components/ticket_scan.dart';

void main() {
  test('plain ticket numbers pass through', () {
    expect(parseScannedTicket(' 1001 '), '1001');
    expect(parseScannedTicket('0028'), '0028');
    expect(parseScannedTicket('A-1001'), 'A-1001');
  });

  test('guest tracking QR resolves to its ticket', () {
    expect(parseScannedTicket('https://valetfusion.focalsoft.ae/track/TYU/0028'), '0028');
    expect(parseScannedTicket('https://staging.example.com/track/BVL%201/1001/'), '1001');
  });

  test('ticket query parameter is read', () {
    expect(parseScannedTicket('https://x.ae/guest?ticket=1001'), '1001');
    expect(parseScannedTicket('https://x.ae/t?t=55'), '55');
  });

  test('key tags, unrelated URLs and blanks are rejected', () {
    expect(parseScannedTicket('HOOK-17'), isNull);
    expect(parseScannedTicket('key 4'), isNull);
    expect(parseScannedTicket('https://google.com/search'), isNull);
    expect(parseScannedTicket('https://x.ae/track/TYU'), isNull);
    expect(parseScannedTicket('   '), isNull);
  });
}
