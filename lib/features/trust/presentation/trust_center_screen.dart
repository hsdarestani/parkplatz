import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/freiraum_scaffold.dart';
import '../data/trust_repository.dart';

class TrustCenterScreen extends ConsumerWidget {
  const TrustCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FreiraumScaffold(
        title: 'Vertrauen',
        subtitle: 'Prüfungen und Kontohilfe.',
        activePath: '/trust',
        child: FutureBuilder<TrustOverview>(
          future: ref.read(trustRepositoryProvider).overview(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return Center(
              child: Text(
                '${data.verifiedSpaces} verifiziert · '
                '${data.pendingVerifications} in Prüfung · '
                '${data.openReports} offen',
              ),
            );
          },
        ),
      );
}
