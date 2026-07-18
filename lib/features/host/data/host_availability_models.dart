class HostAvailabilityRule {
  const HostAvailabilityRule({
    required this.weekday,
    required this.active,
    required this.startTime,
    required this.endTime,
    this.priceOverrideCents,
  });

  final int weekday;
  final bool active;
  final String startTime;
  final String endTime;
  final int? priceOverrideCents;

  factory HostAvailabilityRule.fromJson(Map<String, dynamic> json) =>
      HostAvailabilityRule(
        weekday: json['weekday'] as int,
        active: json['active'] == true,
        startTime: shortTime(json['start_time'].toString()),
        endTime: shortTime(json['end_time'].toString()),
        priceOverrideCents: json['price_override_cents'] as int?,
      );

  Map<String, dynamic> toApi() => {
        'weekday': weekday,
        'active': active,
        'start_time': apiTime(startTime),
        'end_time': apiTime(endTime),
        'price_override_cents': priceOverrideCents,
      };

  HostAvailabilityRule copyWith({
    bool? active,
    String? startTime,
    String? endTime,
    int? priceOverrideCents,
    bool clearPrice = false,
  }) =>
      HostAvailabilityRule(
        weekday: weekday,
        active: active ?? this.active,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        priceOverrideCents:
            clearPrice ? null : priceOverrideCents ?? this.priceOverrideCents,
      );
}

class HostAvailabilityBlock {
  const HostAvailabilityBlock({
    required this.id,
    required this.start,
    required this.end,
    this.reason,
  });

  final int id;
  final DateTime start;
  final DateTime end;
  final String? reason;

  factory HostAvailabilityBlock.fromJson(Map<String, dynamic> json) =>
      HostAvailabilityBlock(
        id: json['id'] as int,
        start: DateTime.parse(json['start_at'] as String).toLocal(),
        end: DateTime.parse(json['end_at'] as String).toLocal(),
        reason: json['reason'] as String?,
      );
}

class HostAvailabilityConfig {
  const HostAvailabilityConfig({required this.rules, required this.blocks});

  final List<HostAvailabilityRule> rules;
  final List<HostAvailabilityBlock> blocks;
}

String shortTime(String value) =>
    value.length >= 5 ? value.substring(0, 5) : value;

String apiTime(String value) => value.length == 5 ? '$value:00' : value;
