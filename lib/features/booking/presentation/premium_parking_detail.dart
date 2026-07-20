import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/models.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../host/data/host_repository.dart';
import '../../parking/data/providers.dart';
import '../data/repositories.dart';
import 'booking_ui_components.dart';
import 'parking_detail_core_sections.dart';
import 'parking_detail_hero.dart';
import 'parking_detail_marketplace_sections.dart';

export 'parking_detail_hero.dart' show ParkingDetailHero;

class PremiumParkingDetailScreen extends ConsumerStatefulWidget {
  const PremiumParkingDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PremiumParkingDetailScreen> createState() =>
      _PremiumParkingDetailScreenState();
}

class _PremiumParkingDetailScreenState
    extends ConsumerState<PremiumParkingDetailScreen> {
  late Future<bool> owner = _checkOwner();

  Future<bool> _checkOwner() async {
    final auth = ref.read(authRepositoryProvider);
    if (!auth.authenticated && !await auth.restore()) return false;
    final spaces = await ref.read(hostRepositoryProvider).spaces();
    return spaces.any((space) => space.id == widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final space = ref.watch(parkingSpaceProvider(widget.id));
    return FreiraumScaffold(
      title: 'Stellplatz entdecken',
      subtitle: 'Details, Zeitraum und sichere Buchung.',
      activePath: '/discover',
      child: space.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => PremiumRetryState(
          message: 'Stellplatz konnte nicht geladen werden.',
          onRetry: () => ref.invalidate(parkingSpaceProvider(widget.id)),
        ),
        data: (value) => value == null
            ? const Center(child: Text('Stellplatz nicht gefunden.'))
            : FutureBuilder<bool>(
                future: owner,
                builder: (context, snapshot) => _DetailContent(
                  space: value,
                  owner: snapshot.data ?? false,
                  checkingOwner:
                      snapshot.connectionState != ConnectionState.done,
                ),
              ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.space,
    required this.owner,
    required this.checkingOwner,
  });

  final ParkingSpace space;
  final bool owner;
  final bool checkingOwner;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 24,
        compact ? 14 : 24,
        compact ? 14 : 24,
        MediaQuery.paddingOf(context).bottom + 90,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ParkingDetailHero(space: space, owner: owner),
                const SizedBox(height: 16),
                ParkingPhotoGallery(spaceId: space.id),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final details = ParkingDetailsColumn(space: space);
                    final booking = ParkingBookingPanel(
                      space: space,
                      owner: owner,
                      checkingOwner: checkingOwner,
                    );
                    if (constraints.maxWidth < 860) {
                      return Column(
                        children: [details, const SizedBox(height: 16), booking],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: details),
                        const SizedBox(width: 22),
                        Expanded(flex: 4, child: booking),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                ParkingReviewsSection(space: space),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
