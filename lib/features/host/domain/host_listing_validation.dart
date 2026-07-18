class HostListingValidation {
  const HostListingValidation._();

  static double? parseNumber(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  static String? title(String? value) => _text(
        value,
        label: 'Titel',
        minLength: 3,
        maxLength: 120,
      );

  static String? district(String? value) => _text(
        value,
        label: 'Stadtteil',
        minLength: 2,
        maxLength: 80,
      );

  static String? landmark(String? value) => _text(
        value,
        label: 'Orientierungspunkt',
        minLength: 2,
        maxLength: 120,
      );

  static String? address(String? value) => _text(
        value,
        label: 'Genaue Adresse',
        minLength: 5,
        maxLength: 240,
      );

  static String? instructions(String? value) => _text(
        value,
        label: 'Zufahrts- und Einparkhinweise',
        minLength: 5,
        maxLength: 1000,
      );

  static String? latitude(String? value) => _number(
        value,
        label: 'Breitengrad',
        min: -90,
        max: 90,
      );

  static String? longitude(String? value) => _number(
        value,
        label: 'Längengrad',
        min: -180,
        max: 180,
      );

  static String? height(String? value) => _number(
        value,
        label: 'Maximale Höhe',
        min: 0,
        max: 10,
        exclusiveMin: true,
      );

  static String? width(String? value) => _number(
        value,
        label: 'Maximale Breite',
        min: 0,
        max: 10,
        exclusiveMin: true,
      );

  static String? length(String? value) => _number(
        value,
        label: 'Maximale Länge',
        min: 0,
        max: 30,
        exclusiveMin: true,
      );

  static String? price(String? value) => _number(
        value,
        label: 'Preis pro Stunde',
        min: 0.50,
        max: 1000,
      );

  static String? errorForStep(
    int step, {
    required String titleValue,
    required String districtValue,
    required String landmarkValue,
    required String addressValue,
    required String latitudeValue,
    required String longitudeValue,
    required String instructionsValue,
    required String heightValue,
    required String widthValue,
    required String lengthValue,
    required String priceValue,
  }) {
    final validators = switch (step) {
      0 => <String?>[
          title(titleValue),
          address(addressValue),
          district(districtValue),
          landmark(landmarkValue),
          latitude(latitudeValue),
          longitude(longitudeValue),
        ],
      1 => <String?>[
          height(heightValue),
          width(widthValue),
          length(lengthValue),
          instructions(instructionsValue),
        ],
      2 => const <String?>[],
      3 => <String?>[price(priceValue)],
      _ => const <String?>['Ungültiger Schritt.'],
    };

    for (final error in validators) {
      if (error != null) return error;
    }
    return null;
  }

  static String? _text(
    String? value, {
    required String label,
    required int minLength,
    required int maxLength,
  }) {
    final normalized = (value ?? '').trim();
    if (normalized.length < minLength) {
      return '$label muss mindestens $minLength Zeichen enthalten.';
    }
    if (normalized.length > maxLength) {
      return '$label darf höchstens $maxLength Zeichen enthalten.';
    }
    return null;
  }

  static String? _number(
    String? value, {
    required String label,
    required double min,
    required double max,
    bool exclusiveMin = false,
  }) {
    final parsed = parseNumber(value);
    if (parsed == null) return '$label muss eine gültige Zahl sein.';
    if (exclusiveMin ? parsed <= min : parsed < min) {
      final operator = exclusiveMin ? 'größer als' : 'mindestens';
      return '$label muss $operator ${_format(min)} sein.';
    }
    if (parsed > max) {
      return '$label darf höchstens ${_format(max)} sein.';
    }
    return null;
  }

  static String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceAll('.', ',');
}
