// Tests for the outlet (SHOP_VALIDATOR) screen's pure parts (no network): where an outlet login
// lands, how GET /v1/shops/mine is read (null flags = on), the zero-charge rule, the messages
// shown for refused calls, and the Arabic for the screen.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_valetfusion/l10n/staff/ar_shop.dart';
import 'package:fs_valetfusion/services/authentication_service.dart';
import 'package:fs_valetfusion/services/shop_service.dart';
import 'package:fs_valetfusion/services/valet_service.dart';

void main() {
  test('an outlet login lands on its own screen; other roles keep their homes', () {
    expect(AuthenticationService.homeRouteFor(['SHOP_VALIDATOR']), '/shop/home');
    expect(AuthenticationService.homeRouteFor(['SHOP_VALIDATOR', 'OPERATIONS_HEAD']), '/shop/home');
    expect(AuthenticationService.homeRouteFor(['SHOP_VALIDATOR', 'VALET_STAFF']), '/dashboard');
    expect(AuthenticationService.homeRouteFor(['SHOP_VALIDATOR', 'LOCATION_ADMIN']), '/admin/home');
    expect(AuthenticationService.homeRouteFor(['OPERATIONS_HEAD']), '/web-console');
    expect(AuthenticationService.homeRouteFor(['REPORT_VIEWER']), '/web-console');
    expect(AuthenticationService.homeRouteFor(['PARTNER_ADMIN']), '/web-console');
    expect(AuthenticationService.homeRouteFor(['DRIVER']), '/dashboard');
    expect(AuthenticationService.homeRouteFor(['SUPERVISOR']), '/supervisor/home');
    expect(AuthenticationService.homeRouteFor(['SECURITY']), '/security/parking');
    expect(AuthenticationService.homeRouteFor(['CUSTOMER']), '/customer/home');
    expect(AuthenticationService.homeRouteFor([]), '/');
  });

  test('shops/mine: missing flags count as on, false switches off', () {
    final legacy = MyShop.fromJson({'id': 7, 'shopName': 'Cafe'});
    expect(legacy.id, 7);
    expect(legacy.name, 'Cafe');
    expect([legacy.canValidate, legacy.canRequest, legacy.web, legacy.mobile], [true, true, true, true]);
    expect(legacy.requestOnly, isFalse);

    final nulls = MyShop.fromJson({'id': 7, 'shopName': 'Cafe', 'canValidate': null, 'canRequest': null, 'web': null, 'mobile': null});
    expect([nulls.canValidate, nulls.canRequest, nulls.web, nulls.mobile], [true, true, true, true]);

    final requestOnly = MyShop.fromJson({'id': 8, 'shopName': 'Spa', 'canValidate': false, 'canRequest': true, 'web': true, 'mobile': false});
    expect(requestOnly.requestOnly, isTrue);
    expect(requestOnly.mobile, isFalse);
    expect(requestOnly.web, isTrue);

    final neither = MyShop.fromJson({'id': 9, 'shopName': 'Gym', 'canValidate': false, 'canRequest': false});
    expect(neither.requestOnly, isFalse);
  });

  test('ticket-status: shop-login fields are read', () {
    final t = TicketStatusResponse.fromJson({
      'ticketNo': 'T100',
      'ticketStatus': 'USED',
      'parkingVehicleId': 5,
      'status': 'RECEIVED',
      'shopCharge': 0,
      'shopValidated': true,
      'validatedShopName': 'Cafe',
      'applicableCharge': 12.5,
    });
    expect(t.shopCharge, 0.0);
    expect(t.shopValidated, isTrue);
    expect(t.validatedShopName, 'Cafe');
    expect(t.applicableCharge, 12.5);
    final desk = TicketStatusResponse.fromJson({'ticketNo': 'T101'});
    expect(desk.shopCharge, isNull);
    expect(desk.applicableCharge, isNull);
  });

  test('the car may be requested only on a charge of 0 to the cent', () {
    expect(isZeroCharge(0), isTrue);
    expect(isZeroCharge(0.004), isTrue);
    expect(isZeroCharge(0.01), isFalse);
    expect(isZeroCharge(25), isFalse);
    expect(isZeroCharge(null), isFalse);
    expect(shopMoney(12.5), '12.50');
    expect(shopMoney(null), '-');
  });

  test('refused calls show the server message, else the conflict or fallback text', () {
    final forbidden = ShopApiException('This outlet can only request cars - validation is switched off.',
        statusCode: 403, hasServerMessage: true);
    expect(shopErrorMessage(forbidden, fallback: 'Validation failed'), forbidden.message);

    final bareConflict = ShopApiException('Request failed (409)', statusCode: 409, hasServerMessage: false);
    expect(shopErrorMessage(bareConflict, conflict: 'Already validated.', fallback: 'Validation failed'), 'Already validated.');

    final bare400 = ShopApiException('Request failed (400)', statusCode: 400, hasServerMessage: false);
    expect(shopErrorMessage(bare400, conflict: 'Already validated.', fallback: 'Validation failed'), 'Validation failed');

    expect(shopErrorMessage(const SocketException('down'), fallback: 'x'), 'No connection. Check the network and try again.');
    expect(shopErrorMessage(ValetApiException('Ticket not found'), fallback: 'x'), 'Ticket not found');
  });

  test('the Arabic keeps every placeholder', () {
    final placeholder = RegExp(r'\{(\w+)\}');
    arShop.forEach((en, ar) {
      final want = placeholder.allMatches(en).map((m) => m.group(1)).toSet();
      final got = placeholder.allMatches(ar).map((m) => m.group(1)).toSet();
      expect(got, want, reason: en);
    });
  });
}
