import 'dart:math' as math;

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

  bool get hasPlate => plate.trim().isNotEmpty;
}

class ParkingSpace {
  final String id,
      title,
      district,
      landmark,
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
        AccessType.offen => 'Außen · offen',
        AccessType.schranke => 'Außen · Schranke',
        AccessType.tor => 'Innenhof · Tor',
        AccessType.tiefgarage => 'Garage · innen',
        AccessType.rezeption => 'Garage · Empfang',
      };

  bool get indoor => covered || access == AccessType.tiefgarage;
  bool get outdoor => !indoor;
  bool get free => hourlyPrice <= 0;

  // Legacy approximation helpers remain for older, non-routed screens. The
  // production discovery v2 UI never displays these values.
  double distanceMetersTo(Destination? destination) {
    if (destination == null) return walkingMeters.toDouble();
    const earthRadius = 6371000.0;
    final lat1 = lat * math.pi / 180;
    final lat2 = destination.lat * math.pi / 180;
    final deltaLat = (destination.lat - lat) * math.pi / 180;
    final deltaLng = (destination.lng - lng) * math.pi / 180;
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final airDistance = earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return airDistance * 1.28;
  }

  int walkingMetersTo(Destination? destination) =>
      distanceMetersTo(destination).round();

  int walkingMinutesTo(Destination? destination) =>
      math.max(1, (distanceMetersTo(destination) / 78).ceil());

  String walkingLabel(Destination? destination) =>
      'ca. ${walkingMinutesTo(destination)} Min. zu Fuß';

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

  int get hours => math.max(1, (end.difference(start).inMinutes + 59) ~/ 60);

  Duration get duration => end.difference(start);

  bool get valid =>
      destination != null && vehicle != null && end.isAfter(start);

  SearchQuery copyWith({
    Destination? destination,
    DateTime? start,
    DateTime? end,
    Vehicle? vehicle,
    Set<String>? filters,
    String? sort,
  }) =>
      SearchQuery(
        destination: destination ?? this.destination,
        start: start ?? this.start,
        end: end ?? this.end,
        vehicle: vehicle ?? this.vehicle,
        filters: filters ?? this.filters,
        sort: sort ?? this.sort,
      );

  String summary() {
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final timeRange = sameDay
        ? '${_dateLabel(start)} · ${_time(start)}–${_time(end)}'
        : '${_dateLabel(start)} ${_time(start)} – ${_dateLabel(end)} ${_time(end)}';
    return '${destination?.name ?? 'Wohin möchtest du?'} · $timeRange · ${vehicle?.name ?? 'Fahrzeug wählen'}';
  }

  String durationLabel() {
    final minutes = duration.inMinutes;
    final days = minutes ~/ (24 * 60);
    final remainingHours = (minutes % (24 * 60) / 60).ceil();
    if (days > 0 && remainingHours > 0) {
      return '$days ${days == 1 ? 'Tag' : 'Tage'} · $remainingHours Std.';
    }
    if (days > 0) return '$days ${days == 1 ? 'Tag' : 'Tage'}';
    return '$hours ${hours == 1 ? 'Stunde' : 'Stunden'}';
  }

  static String _time(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _dateLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);

    if (date == today) return 'Heute';
    if (date == today.add(const Duration(days: 1))) return 'Morgen';

    const weekdays = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
    const months = [
      'Jan.',
      'Feb.',
      'März',
      'Apr.',
      'Mai',
      'Juni',
      'Juli',
      'Aug.',
      'Sept.',
      'Okt.',
      'Nov.',
      'Dez.',
    ];

    return '${weekdays[value.weekday - 1]}, ${value.day}. ${months[value.month - 1]}';
  }
}
