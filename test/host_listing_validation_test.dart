import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/features/host/domain/host_listing_validation.dart';

void main() {
  test('host text fields match backend minimum lengths', () {
    expect(
      HostListingValidation.title('AB'),
      'Titel muss mindestens 3 Zeichen enthalten.',
    );
    expect(
      HostListingValidation.address('Main'),
      'Genaue Adresse muss mindestens 5 Zeichen enthalten.',
    );
    expect(
      HostListingValidation.instructions('Tor'),
      'Zufahrts- und Einparkhinweise muss mindestens 5 Zeichen enthalten.',
    );
  });

  test('localized numbers and API ranges are accepted', () {
    expect(HostListingValidation.parseNumber('3,50'), 3.5);
    expect(HostListingValidation.price('0,49'), isNotNull);
    expect(HostListingValidation.price('13'), isNull);
    expect(HostListingValidation.latitude('91'), isNotNull);
    expect(HostListingValidation.longitude('8,6821'), isNull);
    expect(HostListingValidation.length('31'), isNotNull);
  });

  test('step error points to the first invalid field', () {
    final error = HostListingValidation.errorForStep(
      0,
      titleValue: 'AB',
      districtValue: 'Frankfurt',
      landmarkValue: 'Messe',
      addressValue: 'Mainzer Landstraße 1',
      latitudeValue: '50.1109',
      longitudeValue: '8.6821',
      instructionsValue: 'Einfahrt durch das Tor',
      heightValue: '2,10',
      widthValue: '2,50',
      lengthValue: '5,20',
      priceValue: '13',
    );

    expect(error, 'Titel muss mindestens 3 Zeichen enthalten.');
  });
}
