import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../booking/data/repositories.dart';
import '../../parking/data/providers.dart';
import '../data/demo_search_data.dart';
import 'search_controller.dart';

class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key, required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  final pages = PageController();
  int step = 0;
  bool loadingVehicles = true;
  List<Vehicle> savedVehicles = const [];

  static const stepTitles = [
    'Wann möchtest du parken?',
    'Wohin möchtest du?',
    'Welches Fahrzeug?',
    'Was brauchst du?',
  ];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final repository = ref.read(vehicleRepositoryProvider);
      final values = await repository.all();
      savedVehicles = values
          .map(
            (vehicle) => Vehicle(
              vehicle.id,
              vehicle.name,
              vehicle.plate,
              vehicle.height,
              vehicle.width,
              vehicle.length,
            ),
          )
          .toList();
    } catch (_) {
      savedVehicles = const [];
    }
    if (mounted) setState(() => loadingVehicles = false);
  }

  Future<void> _go(int target) async {
    setState(() => step = target);
    await pages.animateToPage(
      target,
      duration: T.normal,
      curve: T.emphasized,
    );
  }

  bool _stepReady(SearchQuery query) => switch (step) {
        0 => query.end.isAfter(query.start),
        1 => query.destination != null,
        2 => query.vehicle != null,
        _ => query.valid,
      };

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchProvider);
    final compact = MediaQuery.sizeOf(context).width < 620;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 22,
          12,
          compact ? 16 : 22,
          18,
        ),
        decoration: const BoxDecoration(
          color: T.porcelain,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: T.lineStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stepTitles[step],
                        style: TextStyle(
                          fontSize: compact ? 22 : 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.5,
                        ),
                      ),
                      Text(
                        'Schritt ${step + 1} von ${stepTitles.length}',
                        style: const TextStyle(
                          color: T.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Schließen',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                stepTitles.length,
                (index) => Expanded(
                  child: AnimatedContainer(
                    duration: T.fast,
                    height: 5,
                    margin: EdgeInsets.only(
                      right: index == stepTitles.length - 1 ? 0 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: index <= step ? T.mint : T.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PageView(
                controller: pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => step = value),
                children: [
                  _TimingStep(query: query),
                  _DestinationStep(query: query),
                  _VehicleStep(
                    query: query,
                    loading: loadingVehicles,
                    savedVehicles: savedVehicles,
                    onAddVehicle: () {
                      final router = GoRouter.of(context);
                      Navigator.pop(context);
                      router.push('/vehicles');
                    },
                  ),
                  _FilterStep(query: query),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (step > 0)
                  OutlinedButton.icon(
                    onPressed: () => _go(step - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Zurück'),
                  ),
                if (step > 0) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _stepReady(query)
                        ? step == stepTitles.length - 1
                            ? widget.onSubmit
                            : () => _go(step + 1)
                        : null,
                    icon: Icon(
                      step == stepTitles.length - 1
                          ? Icons.search_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      step == stepTitles.length - 1
                          ? 'Freie Stellplätze anzeigen'
                          : 'Weiter',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingStep extends ConsumerWidget {
  const _TimingStep({required this.query});

  final SearchQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat('EEE, dd. MMM', 'de_DE').format(query.start);
    final start = DateFormat('HH:mm').format(query.start);
    final end = DateFormat('HH:mm').format(query.end);
    return SingleChildScrollView(
      child: _WizardCard(
        icon: Icons.schedule_rounded,
        title: 'Datum, Startzeit und Dauer',
        subtitle:
            'Nur Stellplätze, die in diesem Zeitraum wirklich frei sind, werden angezeigt.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PickerButton(
                  icon: Icons.calendar_month_outlined,
                  label: date,
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: query.start,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (selected == null) return;
                    ref.read(searchProvider.notifier).start(
                          DateTime(
                            selected.year,
                            selected.month,
                            selected.day,
                            query.start.hour,
                            query.start.minute,
                          ),
                        );
                  },
                ),
                _PickerButton(
                  icon: Icons.login_rounded,
                  label: 'Einfahrt $start',
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(query.start),
                    );
                    if (selected == null) return;
                    ref.read(searchProvider.notifier).start(
                          DateTime(
                            query.start.year,
                            query.start.month,
                            query.start.day,
                            selected.hour,
                            selected.minute,
                          ),
                        );
                  },
                ),
                _PickerButton(
                  icon: Icons.logout_rounded,
                  label: 'Ausfahrt $end',
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(query.end),
                    );
                    if (selected == null) return;
                    var value = DateTime(
                      query.start.year,
                      query.start.month,
                      query.start.day,
                      selected.hour,
                      selected.minute,
                    );
                    if (!value.isAfter(query.start)) {
                      value = value.add(const Duration(days: 1));
                    }
                    ref.read(searchProvider.notifier).range(query.start, value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Icon(Icons.timelapse_rounded, color: T.success),
                const SizedBox(width: 10),
                Text(
                  '${query.hours} ${query.hours == 1 ? 'Stunde' : 'Stunden'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Slider(
              value: query.hours.toDouble(),
              min: 1,
              max: 24,
              divisions: 23,
              label: '${query.hours} Std.',
              onChanged: (value) =>
                  ref.read(searchProvider.notifier).duration(value.round()),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 2, 4, 6, 8, 12, 24]
                  .map(
                    (hours) => ChoiceChip(
                      avatar: const Icon(Icons.schedule, size: 16),
                      label: Text('$hours Std.'),
                      selected: query.hours == hours,
                      onSelected: (_) =>
                          ref.read(searchProvider.notifier).duration(hours),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationStep extends ConsumerStatefulWidget {
  const _DestinationStep({required this.query});

  final SearchQuery query;

  @override
  ConsumerState<_DestinationStep> createState() => _DestinationStepState();
}

class _DestinationStepState extends ConsumerState<_DestinationStep> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final matches = demoDestinations
        .where(
          (destination) => search.trim().isEmpty ||
              '${destination.name} ${destination.district}'
                  .toLowerCase()
                  .contains(search.trim().toLowerCase()),
        )
        .toList();
    return _WizardCard(
      icon: Icons.location_on_outlined,
      title: 'Ziel auswählen',
      subtitle: 'Wähle einen Ort; Entfernungen werden danach neu berechnet.',
      child: Column(
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Messe, Bahnhof, Straße oder Sehenswürdigkeit',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => search = value),
          ),
          const SizedBox(height: 12),
          ...matches.map(
            (destination) => ListTile(
              onTap: () =>
                  ref.read(searchProvider.notifier).destination(destination),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: widget.query.destination?.id == destination.id
                  ? T.mintSoft
                  : null,
              leading: Icon(
                widget.query.destination?.id == destination.id
                    ? Icons.check_circle_rounded
                    : Icons.place_outlined,
                color: widget.query.destination?.id == destination.id
                    ? T.success
                    : T.muted,
              ),
              title: Text(
                destination.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(destination.district),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleStep extends ConsumerWidget {
  const _VehicleStep({
    required this.query,
    required this.loading,
    required this.savedVehicles,
    required this.onAddVehicle,
  });

  final SearchQuery query;
  final bool loading;
  final List<Vehicle> savedVehicles;
  final VoidCallback onAddVehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = [...savedVehicles, ...demoVehicles];
    return _WizardCard(
      icon: Icons.directions_car_filled_outlined,
      title: 'Fahrzeug wählen',
      subtitle:
          'Wie bei einer einfachen Fahrzeugbörse: eigenes Auto oder passende Klasse auswählen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading) const LinearProgressIndicator(),
          if (savedVehicles.isNotEmpty) ...[
            const _Subheading('Deine Fahrzeuge'),
            ...savedVehicles.map(
              (vehicle) => _VehicleTile(query: query, vehicle: vehicle),
            ),
            const SizedBox(height: 12),
          ],
          const _Subheading('Fahrzeugklasse'),
          ...demoVehicles.map(
            (vehicle) => _VehicleTile(query: query, vehicle: vehicle),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onAddVehicle,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Eigenes Fahrzeug hinzufügen'),
          ),
          if (vehicles.isEmpty)
            const Text('Bitte füge zuerst ein Fahrzeug hinzu.'),
        ],
      ),
    );
  }
}

class _VehicleTile extends ConsumerWidget {
  const _VehicleTile({required this.query, required this.vehicle});

  final SearchQuery query;
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = query.vehicle?.id == vehicle.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => ref.read(searchProvider.notifier).vehicle(vehicle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? T.mint : T.line),
        ),
        tileColor: selected ? T.mintSoft : T.surface,
        leading: Icon(
          Icons.directions_car_rounded,
          color: selected ? T.success : T.muted,
        ),
        title: Text(
          vehicle.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${vehicle.plate} · ${vehicle.length.toStringAsFixed(2)} × ${vehicle.width.toStringAsFixed(2)} × ${vehicle.height.toStringAsFixed(2)} m',
        ),
        trailing: Icon(
          selected ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: selected ? T.success : T.muted,
        ),
      ),
    );
  }
}

class _FilterStep extends ConsumerWidget {
  const _FilterStep({required this.query});

  final SearchQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const regular = [
      ('covered', 'Überdacht', Icons.roofing_outlined),
      ('ev', 'E-Laden', Icons.ev_station_outlined),
      ('accessible', 'Barrierearm', Icons.accessible_outlined),
      ('instant', 'Sofortbuchung', Icons.bolt_outlined),
      ('fit', 'Fahrzeug passt', Icons.straighten_outlined),
      ('free', 'Kostenlos', Icons.money_off_csred_outlined),
    ];
    const access = [
      ('garage', 'Garage', Icons.garage_outlined),
      ('indoor', 'Innen', Icons.meeting_room_outlined),
      ('outdoor', 'Außen', Icons.wb_sunny_outlined),
    ];
    return _WizardCard(
      icon: Icons.tune_rounded,
      title: 'Filter und Sortierung',
      subtitle: 'Optional – du kannst direkt suchen oder genauer eingrenzen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Subheading('Eigenschaften'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: regular
                .map(
                  (filter) => FilterChip(
                    avatar: Icon(filter.$3, size: 17),
                    label: Text(filter.$2),
                    selected: query.filters.contains(filter.$1),
                    onSelected: (_) =>
                        ref.read(searchProvider.notifier).toggle(filter.$1),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          const _Subheading('Stellplatzart'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: access
                .map(
                  (filter) => ChoiceChip(
                    avatar: Icon(filter.$3, size: 17),
                    label: Text(filter.$2),
                    selected: query.filters.contains(filter.$1),
                    onSelected: (_) => ref
                        .read(searchProvider.notifier)
                        .exclusiveAccessFilter(filter.$1),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: query.sort,
            decoration: const InputDecoration(
              labelText: 'Sortierung',
              prefixIcon: Icon(Icons.sort_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'Empfohlen', child: Text('Empfohlen')),
              DropdownMenuItem(value: 'Entfernung', child: Text('Entfernung')),
              DropdownMenuItem(value: 'Preis', child: Text('Preis')),
            ],
            onChanged: (value) {
              if (value != null) ref.read(searchProvider.notifier).sort(value);
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: T.mintSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: T.mint),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: T.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${query.summary()} · ${query.hours} Std.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardCard extends StatelessWidget {
  const _WizardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: T.surfaceRaised,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: T.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: T.mintSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: T.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(color: T.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      );
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      );
}

class _Subheading extends StatelessWidget {
  const _Subheading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: T.ink,
          ),
        ),
      );
}