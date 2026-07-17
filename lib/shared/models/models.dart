import 'package:intl/intl.dart';

enum AccessType { offen, schranke, tor, tiefgarage, rezeption }

enum VisualType {
  garage,
  privateOutdoor,
  courtyard,
  practice,
  hotel,
  office,
  gated,
}

class Destination {
  final String id, name, district;
  final double lat, lng;
  const Destination(this.id, this.name, this.district, this.lat, this.lng);
}

class Vehicle {
  final String id, name, plate;
  final double height, width, length;
  const Vehicle(
    this.id,
    this.name,
    this.plate,
    this.height,
    this.width,
    this.length,
  );
}

class ParkingSpace {
  final String id,
      title,
      district,
      landmark,
      exactAddress,
      currency,
      entranceSummary,
      hostType,
      cancellationSummary,
      availabilityStatus;
  final double lat, lng, hourlyPrice, maxHeight, maxWidth, maxLength, rating;
  final int walkingMeters, walkingMinutes, reviewCount;
  final bool available, instant, covered, ev, accessible, verified;
  final AccessType access;
  final VisualType visual;
  const ParkingSpace({
    required this.id,
    required this.title,
    required this.district,
    required this.landmark,
    required this.lat,
    required this.lng,
    required this.exactAddress,
    required this.hourlyPrice,
    this.currency = 'EUR',
    required this.walkingMeters,
    required this.walkingMinutes,
    required this.available,
    required this.instant,
    required this.covered,
    required this.ev,
    required this.accessible,
    required this.maxHeight,
    required this.maxWidth,
    required this.maxLength,
    required this.access,
    required this.entranceSummary,
    required this.hostType,
    required this.verified,
    required this.rating,
    required this.reviewCount,
    required this.cancellationSummary,
    required this.availabilityStatus,
    required this.visual,
  });
  bool fits(Vehicle v) =>
      v.height <= maxHeight && v.width <= maxWidth && v.length <= maxLength;
  double total(int hours) => hourlyPrice * hours;
  String approximate() => '$district · nahe $landmark';
  String accessLabel() => switch (access) {
    AccessType.offen => 'offen',
    AccessType.schranke => 'Schranke',
    AccessType.tor => 'Tor',
    AccessType.tiefgarage => 'Tiefgarage',
    AccessType.rezeption => 'Rezeption',
  };
  String dimensions() =>
      'bis ${maxHeight.toStringAsFixed(2)} m Höhe · ${maxLength.toStringAsFixed(1)} m Länge';
}

class SearchQuery {
  final Destination? destination;
  final DateTime start, end;
  final Vehicle? vehicle;
  final Set<String> filters;
  final String sort;
  const SearchQuery({
    this.destination,
    required this.start,
    required this.end,
    this.vehicle,
    this.filters = const {},
    this.sort = 'Empfohlen',
  });
  int get hours => end.difference(start).inHours.clamp(1, 24);
  bool get valid =>
      destination != null && vehicle != null && end.isAfter(start);
  SearchQuery copyWith({
    Destination? destination,
    DateTime? start,
    DateTime? end,
    Vehicle? vehicle,
    Set<String>? filters,
    String? sort,
  }) => SearchQuery(
    destination: destination ?? this.destination,
    start: start ?? this.start,
    end: end ?? this.end,
    vehicle: vehicle ?? this.vehicle,
    filters: filters ?? this.filters,
    sort: sort ?? this.sort,
  );
  String summary() {
    final df = DateFormat('E, d. MMM', 'de_DE');
    final tf = DateFormat('HH:mm', 'de_DE');
    return '${destination?.name ?? 'Wohin möchtest du?'} · ${df.format(start)} · ${tf.format(start)}–${tf.format(end)} · ${vehicle?.name ?? 'Fahrzeug wählen'}';
  }
}
