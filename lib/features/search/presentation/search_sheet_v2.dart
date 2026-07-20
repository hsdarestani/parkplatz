import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/models/models.dart';
import '../../booking/data/repositories.dart';
import '../../parking/data/providers.dart';
import '../data/demo_search_data.dart';
import '../data/vehicle_catalog.dart';
import 'search_controller.dart';

class SearchSheetV2 extends ConsumerStatefulWidget {
  const SearchSheetV2({super.key, required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  ConsumerState<SearchSheetV2> createState() => _SearchSheetV2State();
}

class _SearchSheetV2State extends ConsumerState<SearchSheetV2> {
  final pages = PageController();
  int step = 0;
  bool loadingVehicles = true;
  List<Vehicle> savedVehicles = const [];
  String? selectedBrand;
  VehicleCatalogEntry? selectedCatalogModel;

  static const stepTitles = [
    'Zeitraum',
    'Ziel',
    'Fahrzeug',
    'Filter',
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
      final values = await ref.read(vehicleRepositoryProvider).all();
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

  bool _ready(SearchQuery query) => switch (step) {
        0 => query.end.isAfter(query.start),
        1 => query.destination != null,
        2 => query.vehicle != null,
        _ => query.valid,
      };

  Future<void> _go(int target) async {
    setState(() => step = target);
    await pages.animateToPage(
      target,
      duration: T.normal,
      curve: T.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchProvider);
    final compact = MediaQuery.sizeOf(context).width < 620;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 14 : 22,
          10,
          compact ? 14 : 22,
          16,
        ),
        decoration: const BoxDecoration(
          color: T.porcelain,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: T.lineStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StepIcon(step: step),
                const SizedBox(width: 12),
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
                IconButton.filledTonal(
                  tooltip: 'Schließen',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 14),
            Expanded(
              child: PageView(
                controller: pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => step = value),
                children: [
                  _TimingStep(query: query),
                  _DestinationStep(query: query),
                  _vehicleStep(query),
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
                    onPressed: _ready(query)
                        ? step == stepTitles.length - 1
                            ? widget.onSubmit
                            : () => _go(step + 1)
                        : null,
                    icon: Icon(
                      step == stepTitles.length - 1
                          ? Icons.travel_explore_rounded
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

  Widget _vehicleStep(SearchQuery query) {
    final brands = vehicleBrands;
    final models = selectedBrand == null
        ? const <VehicleCatalogEntry>[]
        : vehicleModelsFor(selectedBrand!);
    return _WizardCard(
      icon: Icons.directions_car_filled_rounded,
      title: 'Fahrzeug passend auswählen',
      subtitle:
          'Eigenes Fahrzeug mit Kennzeichen oder strukturiert über Marke und Modell.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loadingVehicles) const LinearProgressIndicator(),
          if (savedVehicles.isNotEmpty) ...[
            const _Subheading('Deine Fahrzeuge', Icons.garage_outlined),
            ...savedVehicles.map(
              (vehicle) => _VehicleTile(
                vehicle: vehicle,
                selected: query.vehicle?.id == vehicle.id,
                onTap: () => ref.read(searchProvider.notifier).vehicle(vehicle),
              ),
            ),
            const SizedBox(height: 18),
          ],
          const _Subheading('Marke und Modell', Icons.car_rental_rounded),
          DropdownButtonFormField<String>(
            value: selectedBrand,
            decoration: const InputDecoration(
              labelText: 'Marke',
              prefixIcon: Icon(Icons.factory_outlined),
            ),
            items: brands
                .map(
                  (brand) => DropdownMenuItem(
                    value: brand,
                    child: Text(brand),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedBrand = value;
                selectedCatalogModel = null;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<VehicleCatalogEntry>(
            value: selectedCatalogModel,
            decoration: const InputDecoration(
              labelText: 'Modell',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
            items: models
                .map(
                  (model) => DropdownMenuItem(
                    value: model,
                    child: Text(model.model),
                  ),
                )
                .toList(),
            onChanged: selectedBrand == null
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => selectedCatalogModel = value);
                    ref.read(searchProvider.notifier).vehicle(value.toVehicle());
                  },
          ),
          if (selectedCatalogModel != null) ...[
            const SizedBox(height: 12),
            _CatalogPreview(entry: selectedCatalogModel!),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push('/vehicles');
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Eigenes Fahrzeug hinzufügen'),
          ),
        ],
      ),
    );
  }
}

class _TimingStep extends ConsumerWidget {
  const _TimingStep({required this.query});

  final SearchQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat('EEE, dd. MMM', 'de_DE');
    final time = DateFormat('HH:mm');
    return _WizardCard(
      icon: Icons.calendar_month_rounded,
      title: 'Einfahrt und Ausfahrt festlegen',
      subtitle:
          'Stunden, mehrere Tage oder bis zu 30 Tage. Verfügbarkeit wird für den gesamten Zeitraum geprüft.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateTimePanel(
            title: 'Einfahrt',
            icon: Icons.login_rounded,
            accent: T.success,
            dateLabel: date.format(query.start),
            timeLabel: time.format(query.start),
            onDate: () => _pickStartDate(context, ref, query),
            onTime: () => _pickStartTime(context, ref, query),
          ),
          const SizedBox(height: 12),
          _DateTimePanel(
            title: 'Ausfahrt',
            icon: Icons.logout_rounded,
            accent: T.warning,
            dateLabel: date.format(query.end),
            timeLabel: time.format(query.end),
            onDate: () => _pickEndDate(context, ref, query),
            onTime: () => _pickEndTime(context, ref, query),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [T.ink, T.inkSoft]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.timelapse_rounded, color: T.mint),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gesamtdauer',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        query.durationLabel(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              (label: '2 Std.', duration: Duration(hours: 2)),
              (label: '4 Std.', duration: Duration(hours: 4)),
              (label: '8 Std.', duration: Duration(hours: 8)),
              (label: '1 Tag', duration: Duration(days: 1)),
              (label: '2 Tage', duration: Duration(days: 2)),
              (label: '3 Tage', duration: Duration(days: 3)),
              (label: '7 Tage', duration: Duration(days: 7)),
            ]
                .map(
                  (option) => ActionChip(
                    avatar: const Icon(Icons.schedule_rounded, size: 17),
                    label: Text(option.label),
                    onPressed: () => ref
                        .read(searchProvider.notifier)
                        .durationValue(option.duration),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStartDate(
    BuildContext context,
    WidgetRef ref,
    SearchQuery query,
  ) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: query.start.isBefore(now) ? now : query.start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
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
  }

  Future<void> _pickEndDate(
    BuildContext context,
    WidgetRef ref,
    SearchQuery query,
  ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: query.end.isBefore(query.start) ? query.start : query.end,
      firstDate: DateTime(query.start.year, query.start.month, query.start.day),
      lastDate: query.start.add(const Duration(days: 30)),
    );
    if (selected == null) return;
    var end = DateTime(
      selected.year,
      selected.month,
      selected.day,
      query.end.hour,
      query.end.minute,
    );
    if (!end.isAfter(query.start)) end = query.start.add(const Duration(hours: 1));
    ref.read(searchProvider.notifier).range(query.start, end);
  }

  Future<void> _pickStartTime(
    BuildContext context,
    WidgetRef ref,
    SearchQuery query,
  ) async {
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
  }

  Future<void> _pickEndTime(
    BuildContext context,
    WidgetRef ref,
    SearchQuery query,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(query.end),
    );
    if (selected == null) return;
    var end = DateTime(
      query.end.year,
      query.end.month,
      query.end.day,
      selected.hour,
      selected.minute,
    );
    if (!end.isAfter(query.start)) end = end.add(const Duration(days: 1));
    ref.read(searchProvider.notifier).range(query.start, end);
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
      icon: Icons.location_searching_rounded,
      title: 'Ziel auswählen',
      subtitle:
          'Die echte Fußroute wird anschließend über den Routing-Dienst berechnet.',
      child: Column(
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Messe, Bahnhof oder Sehenswürdigkeit',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => search = value),
          ),
          const SizedBox(height: 12),
          ...matches.map(
            (destination) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () =>
                    ref.read(searchProvider.notifier).destination(destination),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                  side: BorderSide(
                    color: widget.query.destination?.id == destination.id
                        ? T.mint
                        : T.line,
                  ),
                ),
                tileColor: widget.query.destination?.id == destination.id
                    ? T.mintSoft
                    : T.surface,
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
          ),
        ],
      ),
    );
  }
}

class _FilterStep extends ConsumerWidget {
  const _FilterStep({required this.query});

  final SearchQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const features = [
      ('covered', 'Überdacht', Icons.roofing_rounded),
      ('ev', 'E-Laden', Icons.ev_station_rounded),
      ('accessible', 'Barrierearm', Icons.accessible_forward_rounded),
      ('instant', 'Sofort', Icons.bolt_rounded),
      ('fit', 'Fahrzeug passt', Icons.fact_check_outlined),
      ('free', 'Kostenlos', Icons.money_off_csred_rounded),
    ];
    const access = [
      ('garage', 'Garage', Icons.garage_rounded),
      ('indoor', 'Innen', Icons.meeting_room_rounded),
      ('outdoor', 'Außen', Icons.wb_sunny_rounded),
    ];
    return _WizardCard(
      icon: Icons.tune_rounded,
      title: 'Wichtige Eigenschaften',
      subtitle: 'Große, visuelle Filter statt einer langen Textliste.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Subheading('Ausstattung', Icons.auto_awesome_rounded),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: features
                .map(
                  (item) => _VisualFilter(
                    icon: item.$3,
                    label: item.$2,
                    selected: query.filters.contains(item.$1),
                    onTap: () =>
                        ref.read(searchProvider.notifier).toggle(item.$1),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const _Subheading('Stellplatzart', Icons.local_parking_rounded),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: access
                .map(
                  (item) => _VisualFilter(
                    icon: item.$3,
                    label: item.$2,
                    selected: query.filters.contains(item.$1),
                    onTap: () => ref
                        .read(searchProvider.notifier)
                        .exclusiveAccessFilter(item.$1),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: query.sort == 'Entfernung' ? 'Empfohlen' : query.sort,
            decoration: const InputDecoration(
              labelText: 'Sortierung',
              prefixIcon: Icon(Icons.sort_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'Empfohlen', child: Text('Empfohlen')),
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
                const Icon(Icons.verified_rounded, color: T.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${query.summary()} · ${query.durationLabel()}',
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

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.calendar_month_rounded,
      Icons.location_on_rounded,
      Icons.directions_car_filled_rounded,
      Icons.tune_rounded,
    ];
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [T.mint, T.success]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: T.shadowSmall,
      ),
      child: Icon(icons[step], color: T.ink),
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
            boxShadow: T.shadowSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: T.mintSoft,
                      borderRadius: BorderRadius.circular(15),
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
                        Text(subtitle, style: const TextStyle(color: T.muted)),
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

class _DateTimePanel extends StatelessWidget {
  const _DateTimePanel({
    required this.title,
    required this.icon,
    required this.accent,
    required this.dateLabel,
    required this.timeLabel,
    required this.onDate,
    required this.onTime,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String dateLabel;
  final String timeLabel;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: T.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('$dateLabel · $timeLabel', style: const TextStyle(color: T.muted)),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Datum ändern',
              onPressed: onDate,
              icon: const Icon(Icons.calendar_today_outlined),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: 'Uhrzeit ändern',
              onPressed: onTime,
              icon: const Icon(Icons.schedule_rounded),
            ),
          ],
        ),
      );
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: BorderSide(color: selected ? T.mint : T.line),
          ),
          tileColor: selected ? T.mintSoft : T.surface,
          leading: Icon(
            Icons.directions_car_filled_rounded,
            color: selected ? T.success : T.muted,
          ),
          title: Text(
            vehicle.name,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${vehicle.hasPlate ? '${vehicle.plate} · ' : ''}${vehicle.length.toStringAsFixed(2)} × ${vehicle.width.toStringAsFixed(2)} × ${vehicle.height.toStringAsFixed(2)} m',
          ),
          trailing: Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: selected ? T.success : T.muted,
          ),
        ),
      );
}

class _CatalogPreview extends StatelessWidget {
  const _CatalogPreview({required this.entry});

  final VehicleCatalogEntry entry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: T.mintSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: T.mint),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: T.success),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.brand} ${entry.model}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${entry.length.toStringAsFixed(2)} × ${entry.width.toStringAsFixed(2)} × ${entry.height.toStringAsFixed(2)} m · ohne Kennzeichen',
                    style: const TextStyle(color: T.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Subheading extends StatelessWidget {
  const _Subheading(this.text, this.icon);

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          children: [
            Icon(icon, size: 19, color: T.success),
            const SizedBox(width: 7),
            Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}

class _VisualFilter extends StatelessWidget {
  const _VisualFilter({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: T.fast,
          width: 132,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? T.mintSoft : T.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? T.mint : T.line),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? T.success : T.muted, size: 27),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
}
