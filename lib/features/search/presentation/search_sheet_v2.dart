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
  final PageController _pages = PageController();
  int _step = 0;
  bool _loadingVehicles = true;
  List<Vehicle> _savedVehicles = const [];
  String? _selectedBrand;
  VehicleCatalogEntry? _selectedModel;

  static const _titles = ['Zeitraum', 'Ziel', 'Fahrzeug', 'Filter'];
  static const _icons = [
    Icons.calendar_month_rounded,
    Icons.location_on_rounded,
    Icons.directions_car_filled_rounded,
    Icons.tune_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final records = await ref.read(vehicleRepositoryProvider).all();
      _savedVehicles = records
          .map(
            (record) => Vehicle(
              record.id,
              record.name,
              record.plate,
              record.height,
              record.width,
              record.length,
            ),
          )
          .toList(growable: false);
    } catch (_) {
      _savedVehicles = const [];
    }
    if (mounted) setState(() => _loadingVehicles = false);
  }

  bool _canContinue(SearchQuery query) => switch (_step) {
        0 => query.end.isAfter(query.start),
        1 => query.destination != null,
        2 => query.vehicle != null,
        _ => query.valid,
      };

  Future<void> _goTo(int page) async {
    if (page < 0 || page >= _titles.length) return;
    setState(() => _step = page);
    await _pages.animateToPage(
      page,
      duration: T.normal,
      curve: T.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchProvider);
    final compact = MediaQuery.sizeOf(context).width < 620;

    return SafeArea(
      child: Material(
        color: T.porcelain,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 22,
            10,
            compact ? 14 : 22,
            16,
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
              _Header(
                step: _step,
                title: _titles[_step],
                icon: _icons[_step],
                compact: compact,
                onClose: () => Navigator.maybePop(context),
              ),
              const SizedBox(height: 12),
              _Progress(step: _step, count: _titles.length),
              const SizedBox(height: 14),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (value) => setState(() => _step = value),
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
                  if (_step > 0) ...[
                    OutlinedButton.icon(
                      onPressed: () => _goTo(_step - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Zurück'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _canContinue(query)
                          ? _step == _titles.length - 1
                              ? widget.onSubmit
                              : () => _goTo(_step + 1)
                          : null,
                      icon: Icon(
                        _step == _titles.length - 1
                            ? Icons.travel_explore_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        _step == _titles.length - 1
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
      ),
    );
  }

  Widget _vehicleStep(SearchQuery query) {
    final models = _selectedBrand == null
        ? const <VehicleCatalogEntry>[]
        : vehicleModelsFor(_selectedBrand!);

    return _WizardCard(
      icon: Icons.directions_car_filled_rounded,
      title: 'Fahrzeug passend auswählen',
      subtitle:
          'Eigenes Fahrzeug mit Kennzeichen oder strukturiert über Marke und Modell.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadingVehicles) const LinearProgressIndicator(),
          if (_savedVehicles.isNotEmpty) ...[
            const _Subheading('Deine Fahrzeuge', Icons.garage_outlined),
            ..._savedVehicles.map(
              (vehicle) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SelectionTile(
                  selected: query.vehicle?.id == vehicle.id,
                  icon: Icons.directions_car_filled_rounded,
                  title: vehicle.name,
                  subtitle:
                      '${vehicle.hasPlate ? '${vehicle.plate} · ' : ''}${_dimensions(vehicle)}',
                  onTap: () =>
                      ref.read(searchProvider.notifier).vehicle(vehicle),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const _Subheading('Marke und Modell', Icons.car_rental_rounded),
          DropdownButtonFormField<String>(
            value: _selectedBrand,
            decoration: const InputDecoration(
              labelText: 'Marke',
              prefixIcon: Icon(Icons.factory_outlined),
            ),
            items: vehicleBrands
                .map(
                  (brand) => DropdownMenuItem(
                    value: brand,
                    child: Text(brand),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() {
                _selectedBrand = value;
                _selectedModel = null;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<VehicleCatalogEntry>(
            value: _selectedModel,
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
                .toList(growable: false),
            onChanged: _selectedBrand == null
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _selectedModel = value);
                    ref.read(searchProvider.notifier).vehicle(value.toVehicle());
                  },
          ),
          if (_selectedModel != null) ...[
            const SizedBox(height: 12),
            _CatalogPreview(entry: _selectedModel!),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.maybePop(context);
              context.push('/vehicles');
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Eigenes Fahrzeug hinzufügen'),
          ),
        ],
      ),
    );
  }

  String _dimensions(Vehicle vehicle) =>
      '${vehicle.length.toStringAsFixed(2)} × ${vehicle.width.toStringAsFixed(2)} × ${vehicle.height.toStringAsFixed(2)} m';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.title,
    required this.icon,
    required this.compact,
    required this.onClose,
  });

  final int step;
  final String title;
  final IconData icon;
  final bool compact;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [T.mint, T.success]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: T.shadowSmall,
            ),
            child: Icon(icon, color: T.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 22 : 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                Text(
                  'Schritt ${step + 1} von 4',
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
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(
          count,
          (index) => Expanded(
            child: AnimatedContainer(
              duration: T.fast,
              height: 5,
              margin: EdgeInsets.only(right: index == count - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: index <= step ? T.mint : T.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      );
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
            value: '${date.format(query.start)} · ${time.format(query.start)}',
            onDate: () => _pickStartDate(context, ref),
            onTime: () => _pickStartTime(context, ref),
          ),
          const SizedBox(height: 12),
          _DateTimePanel(
            title: 'Ausfahrt',
            icon: Icons.logout_rounded,
            accent: T.warning,
            value: '${date.format(query.end)} · ${time.format(query.end)}',
            onDate: () => _pickEndDate(context, ref),
            onTime: () => _pickEndTime(context, ref),
          ),
          const SizedBox(height: 16),
          Material(
            color: T.ink,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.timelapse_rounded, color: T.mint),
                  const SizedBox(width: 12),
                  Column(
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              ('2 Std.', Duration(hours: 2)),
              ('4 Std.', Duration(hours: 4)),
              ('8 Std.', Duration(hours: 8)),
              ('1 Tag', Duration(days: 1)),
              ('2 Tage', Duration(days: 2)),
              ('3 Tage', Duration(days: 3)),
              ('7 Tage', Duration(days: 7)),
            ]
                .map(
                  (option) => ActionChip(
                    avatar: const Icon(Icons.schedule_rounded, size: 17),
                    label: Text(option.$1),
                    onPressed: () => ref
                        .read(searchProvider.notifier)
                        .durationValue(option.$2),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStartDate(BuildContext context, WidgetRef ref) async {
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

  Future<void> _pickEndDate(BuildContext context, WidgetRef ref) async {
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
    if (!end.isAfter(query.start)) {
      end = query.start.add(const Duration(hours: 1));
    }
    ref.read(searchProvider.notifier).range(query.start, end);
  }

  Future<void> _pickStartTime(BuildContext context, WidgetRef ref) async {
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

  Future<void> _pickEndTime(BuildContext context, WidgetRef ref) async {
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
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final needle = _search.trim().toLowerCase();
    final matches = demoDestinations
        .where(
          (destination) => needle.isEmpty ||
              '${destination.name} ${destination.district}'
                  .toLowerCase()
                  .contains(needle),
        )
        .toList(growable: false);

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
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 12),
          ...matches.map(
            (destination) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SelectionTile(
                selected: widget.query.destination?.id == destination.id,
                icon: Icons.place_outlined,
                title: destination.name,
                subtitle: destination.district,
                onTap: () => ref
                    .read(searchProvider.notifier)
                    .destination(destination),
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
      subtitle: 'Wähle nur die Merkmale, die du wirklich brauchst.',
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
                .toList(growable: false),
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
                .toList(growable: false),
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
          Material(
            color: T.mintSoft,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
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
        child: Material(
          color: T.surfaceRaised,
          elevation: 2,
          shadowColor: T.ink.withOpacity(.12),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
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
        ),
      );
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? T.mintSoft : T.surface,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: selected ? T.mint : T.line),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : icon,
                  color: selected ? T.success : T.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(subtitle, style: const TextStyle(color: T.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: T.muted),
              ],
            ),
          ),
        ),
      );
}

class _DateTimePanel extends StatelessWidget {
  const _DateTimePanel({
    required this.title,
    required this.icon,
    required this.accent,
    required this.value,
    required this.onDate,
    required this.onTime,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String value;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) => Material(
        color: T.surface,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
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
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(value, style: const TextStyle(color: T.muted)),
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
        ),
      );
}

class _CatalogPreview extends StatelessWidget {
  const _CatalogPreview({required this.entry});

  final VehicleCatalogEntry entry;

  @override
  Widget build(BuildContext context) => Material(
        color: T.mintSoft,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
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
  Widget build(BuildContext context) => Material(
        color: selected ? T.mintSoft : T.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: T.fast,
            width: 132,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
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
        ),
      );
}
