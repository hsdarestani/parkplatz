import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../booking/data/repositories.dart';
import 'host_availability_models.dart';
import 'host_repository.dart';

abstract interface class HostOperationsRepository {
  Future<HostSpaceRecord> update(HostSpaceRecord space);
  Future<void> archive(String id);
  Future<HostAvailabilityConfig> availability(String id);
  Future<List<HostAvailabilityRule>> saveAvailability(
    String id,
    List<HostAvailabilityRule> rules,
  );
  Future<HostAvailabilityBlock> addBlock(
    String id,
    DateTime start,
    DateTime end,
    String? reason,
  );
  Future<void> deleteBlock(String id, int blockId);
}

class ApiHostOperationsRepository implements HostOperationsRepository {
  const ApiHostOperationsRepository(this.api);

  final ApiClient api;

  @override
  Future<HostSpaceRecord> update(HostSpaceRecord space) async =>
      HostSpaceRecord.fromJson(
        await api.patch(
          '/host/parking-spaces/${space.id}',
          body: space.toApi(),
        ) as Map<String, dynamic>,
      );

  @override
  Future<void> archive(String id) => api.delete('/host/parking-spaces/$id');

  @override
  Future<HostAvailabilityConfig> availability(String id) async {
    final json = await api.get(
      '/host/parking-spaces/$id/availability',
    ) as Map<String, dynamic>;
    return HostAvailabilityConfig(
      rules: (json['rules'] as List)
          .map(
            (value) => HostAvailabilityRule.fromJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList(),
      blocks: (json['blocks'] as List)
          .map(
            (value) => HostAvailabilityBlock.fromJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<List<HostAvailabilityRule>> saveAvailability(
    String id,
    List<HostAvailabilityRule> rules,
  ) async {
    final json = await api.post(
      '/host/parking-spaces/$id/availability',
      body: {'rules': rules.map((rule) => rule.toApi()).toList()},
    ) as Map<String, dynamic>;
    return (json['rules'] as List)
        .map(
          (value) => HostAvailabilityRule.fromJson(
            value as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  @override
  Future<HostAvailabilityBlock> addBlock(
    String id,
    DateTime start,
    DateTime end,
    String? reason,
  ) async =>
      HostAvailabilityBlock.fromJson(
        await api.post(
          '/host/parking-spaces/$id/availability-blocks',
          body: {
            'start_at': start.toIso8601String(),
            'end_at': end.toIso8601String(),
            'reason': reason,
          },
        ) as Map<String, dynamic>,
      );

  @override
  Future<void> deleteBlock(String id, int blockId) => api.delete(
        '/host/parking-spaces/$id/availability-blocks/$blockId',
      );
}

class LocalHostOperationsRepository implements HostOperationsRepository {
  final Map<String, HostAvailabilityConfig> _availability = {};

  @override
  Future<HostSpaceRecord> update(HostSpaceRecord space) async => space;

  @override
  Future<void> archive(String id) async {}

  @override
  Future<HostAvailabilityConfig> availability(String id) async =>
      _availability.putIfAbsent(
        id,
        () => HostAvailabilityConfig(
          rules: List.generate(
            7,
            (weekday) => HostAvailabilityRule(
              weekday: weekday,
              active: true,
              startTime: '00:00',
              endTime: '23:59',
            ),
          ),
          blocks: const [],
        ),
      );

  @override
  Future<List<HostAvailabilityRule>> saveAvailability(
    String id,
    List<HostAvailabilityRule> rules,
  ) async {
    final current = await availability(id);
    _availability[id] = HostAvailabilityConfig(
      rules: rules,
      blocks: current.blocks,
    );
    return rules;
  }

  @override
  Future<HostAvailabilityBlock> addBlock(
    String id,
    DateTime start,
    DateTime end,
    String? reason,
  ) async {
    final current = await availability(id);
    final block = HostAvailabilityBlock(
      id: DateTime.now().microsecondsSinceEpoch,
      start: start,
      end: end,
      reason: reason,
    );
    _availability[id] = HostAvailabilityConfig(
      rules: current.rules,
      blocks: [...current.blocks, block],
    );
    return block;
  }

  @override
  Future<void> deleteBlock(String id, int blockId) async {
    final current = await availability(id);
    _availability[id] = HostAvailabilityConfig(
      rules: current.rules,
      blocks: current.blocks.where((block) => block.id != blockId).toList(),
    );
  }
}

final hostOperationsRepositoryProvider = Provider<HostOperationsRepository>((ref) {
  final mode = ref.watch(appModeProvider);
  if (mode == AppMode.localBeta) return LocalHostOperationsRepository();
  return ApiHostOperationsRepository(ref.watch(apiClientProvider));
});
