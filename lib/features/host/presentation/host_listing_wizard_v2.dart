import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/design_tokens.dart';
import '../../../services/map/map_provider.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../marketplace/data/marketplace_repository.dart';
import '../../parking/data/providers.dart';
import '../data/host_repository.dart';
import '../domain/host_listing_validation.dart';

class HostListingWizardV2Screen extends ConsumerStatefulWidget {
  const HostListingWizardV2Screen({super.key});

  @override
  ConsumerState<HostListingWizardV2Screen> createState() =>
      _HostListingWizardV2ScreenState();
}

class _HostListingWizardV2ScreenState
    extends ConsumerState<HostListingWizardV2Screen> {
  final pages = PageController();
  final mapController = MapController();
  final mapProvider = OpenStreetMapProvider();
  final title = TextEditingController();
  final address = TextEditingController();
  final landmark = TextEditingController();
  final instructions = TextEditingController();
  final price = TextEditingController(text: '3,50');
  final height = TextEditingController(text: '2,10');
  final width = TextEditingController(text: '2,50');
  final length = TextEditingController(text: '5,20');

  Timer? addressTimer;
  int step = 0;
  bool addressLoading = false;
  bool busy = false;
  bool covered = false;
  bool evCharging = false;
  bool accessible = false;
  bool instantBookable = true;
  bool freeParking = false;
  String accessType = 'open';
  AddressSuggestion? verifiedAddress;
  List<AddressSuggestion> suggestions = const [];
  LatLng pin = const LatLng(50.1109, 8.6821);
  Uint8List? photoBytes;
  String? photoName;

  static const titles = [
    'Adresse & Pin',
    'Größe & Zufahrt',
    'Ausstattung & Foto',
    'Preis & Freigabe',
  ];

  @override
  void dispose() {
    addressTimer?.cancel();
    pages.dispose();
    for (final controller in [
      title,
      address,
      landmark,
      instructions,
      price,
      height,
      width,
      length,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _searchAddress(String value) {
    verifiedAddress = null;
    addressTimer?.cancel();
    if (value.trim().length < 3) {
      setState(() => suggestions = const []);
      return;
    }
    addressTimer = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => addressLoading = true);
      try {
        final values = await ref
            .read(marketplaceRepositoryProvider)
            .suggestAddress(value.trim());
        if (mounted) setState(() => suggestions = values);
      } catch (_) {
        if (mounted) setState(() => suggestions = const []);
      } finally {
        if (mounted) setState(() => addressLoading = false);
      }
    });
  }

  void _selectAddress(AddressSuggestion value) {
    address.text = value.displayName;
    verifiedAddress = value;
    pin = LatLng(value.latitude, value.longitude);
    if (landmark.text.trim().isEmpty && value.road != null) {
      landmark.text = value.road!;
    }
    setState(() => suggestions = const []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mapController.move(pin, 17);
    });
  }

  String? _stepError(int target) {
    if (target == 0) {
      final titleError = HostListingValidation.title(title.text);
      if (titleError != null) return titleError;
      if (verifiedAddress == null) {
        return 'Bitte wähle eine verifizierte Adresse aus den Vorschlägen.';
      }
      final landmarkError = HostListingValidation.landmark(landmark.text);
      if (landmarkError != null) return landmarkError;
    }
    if (target == 1) {
      for (final error in [
        HostListingValidation.height(height.text),
        HostListingValidation.width(width.text),
        HostListingValidation.length(length.text),
        HostListingValidation.instructions(instructions.text),
      ]) {
        if (error != null) return error;
      }
    }
    if (target == 3) return HostListingValidation.price(price.text);
    return null;
  }

  Future<void> _go(int target) async {
    if (target > step) {
      final error = _stepError(step);
      if (error != null) {
        _showError(error);
        return;
      }
    }
    setState(() => step = target);
    await pages.animateToPage(
      target,
      duration: T.normal,
      curve: T.emphasized,
    );
  }

  void _showError(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _pickPhoto() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    final file = selection?.files.single;
    if (file?.bytes == null) return;
    setState(() {
      photoBytes = file!.bytes;
      photoName = file.name;
    });
  }

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Stellplatz hinzufügen',
        subtitle: 'Verifizierte Adresse, visueller Pin und AI-Fotoprüfung.',
        activePath: '/host/new',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _ProgressHeader(
                    title: titles[step],
                    current: step,
                    count: titles.length,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: PageView(
                      controller: pages,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (value) => setState(() => step = value),
                      children: [
                        _addressStep(),
                        _detailsStep(),
                        _featuresStep(),
                        _publishStep(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (step > 0)
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _go(step - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Zurück'),
                        ),
                      if (step > 0) const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy
                              ? null
                              : step == titles.length - 1
                                  ? _submit
                                  : () => _go(step + 1),
                          icon: Icon(
                            step == titles.length - 1
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(
                            busy
                                ? 'Wird veröffentlicht …'
                                : step == titles.length - 1
                                    ? 'Stellplatz veröffentlichen'
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
        ),
      );

  Widget _addressStep() => _PageCard(
        icon: Icons.location_on_rounded,
        title: 'Echte Adresse auswählen',
        subtitle:
            'Freie Texte sind nicht zulässig. Wähle zwingend einen Treffer aus der Adresssuche.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Titel des Stellplatzes',
                hintText: 'z. B. Garage nahe Hauptbahnhof',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              onChanged: (value) {
                setState(() => verifiedAddress = null);
                _searchAddress(value);
              },
              decoration: InputDecoration(
                labelText: 'Straße und Hausnummer',
                hintText: 'Mindestens 3 Zeichen eingeben',
                prefixIcon: const Icon(Icons.manage_search_rounded),
                suffixIcon: addressLoading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : verifiedAddress != null
                        ? const Icon(Icons.verified_rounded, color: T.success)
                        : const Icon(Icons.arrow_drop_down_rounded),
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 230),
                decoration: BoxDecoration(
                  color: T.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: T.line),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ListTile(
                      onTap: () => _selectAddress(suggestion),
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        suggestion.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(suggestion.district),
                      trailing: const Icon(Icons.check_circle_outline_rounded),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: landmark,
              decoration: const InputDecoration(
                labelText: 'Öffentlicher Orientierungspunkt',
                hintText: 'z. B. nahe Messe Frankfurt',
                prefixIcon: Icon(Icons.flag_rounded),
              ),
            ),
            const SizedBox(height: 14),
            if (verifiedAddress == null)
              const _Notice(
                icon: Icons.warning_amber_rounded,
                text:
                    'Die Adresse ist noch nicht bestätigt. Der nächste Schritt bleibt gesperrt.',
                warning: true,
              )
            else
              _Notice(
                icon: Icons.verified_rounded,
                text:
                    '${verifiedAddress!.district} · Adresse erfolgreich bestätigt',
              ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 310,
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: pin,
                    initialZoom: 16,
                    onTap: (_, point) => setState(() => pin = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: mapProvider.tileTemplate,
                      userAgentPackageName: mapProvider.userAgentPackageName,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: pin,
                          width: 64,
                          height: 64,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_pin,
                            size: 60,
                            color: T.success,
                          ),
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [TextSourceAttribution(mapProvider.attribution)],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            const Row(
              children: [
                Icon(Icons.touch_app_rounded, color: T.success, size: 19),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tippe auf die tatsächliche Einfahrt. Koordinaten werden intern gespeichert und niemals als Formularfeld verlangt.',
                    style: TextStyle(color: T.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _detailsStep() => _PageCard(
        icon: Icons.straighten_rounded,
        title: 'Maße und Zufahrt',
        subtitle: 'Verhindert unpassende Fahrzeuge und Fehlbuchungen.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _dimension(height, 'Max. Höhe', Icons.height_rounded),
                _dimension(width, 'Max. Breite', Icons.width_normal_rounded),
                _dimension(length, 'Max. Länge', Icons.straighten_rounded),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: accessType,
              decoration: const InputDecoration(
                labelText: 'Stellplatzart und Zufahrt',
                prefixIcon: Icon(Icons.garage_rounded),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'open',
                  child: Text('Außen · offene Zufahrt'),
                ),
                DropdownMenuItem(
                  value: 'barrier',
                  child: Text('Außen · Schranke'),
                ),
                DropdownMenuItem(
                  value: 'gate',
                  child: Text('Innenhof · Tor'),
                ),
                DropdownMenuItem(
                  value: 'underground',
                  child: Text('Garage · innen'),
                ),
                DropdownMenuItem(
                  value: 'reception',
                  child: Text('Garage · Empfang'),
                ),
              ],
              onChanged: (value) => setState(() => accessType = value ?? 'open'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: instructions,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Zufahrts- und Einparkhinweise',
                hintText: 'Tor, Stellplatznummer, Schlüssel oder Besonderheiten',
                prefixIcon: Icon(Icons.route_rounded),
              ),
            ),
          ],
        ),
      );

  Widget _featuresStep() => _PageCard(
        icon: Icons.auto_awesome_rounded,
        title: 'Ausstattung und Foto',
        subtitle: 'Klare Icons und automatische Prüfung vor Veröffentlichung.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _featureSwitch(
              'Überdacht',
              'Schutz vor Regen und Sonne',
              Icons.roofing_rounded,
              covered,
              (value) => setState(() => covered = value),
            ),
            _featureSwitch(
              'E-Laden',
              'Ladepunkt am oder nahe dem Stellplatz',
              Icons.ev_station_rounded,
              evCharging,
              (value) => setState(() => evCharging = value),
            ),
            _featureSwitch(
              'Barrierearm',
              'Breiter, möglichst stufenfreier Zugang',
              Icons.accessible_forward_rounded,
              accessible,
              (value) => setState(() => accessible = value),
            ),
            _featureSwitch(
              'Sofort reservierbar',
              'Die Anfrage wird sofort angelegt; die Übergabe muss trotzdem bestätigt werden.',
              Icons.bolt_rounded,
              instantBookable,
              (value) => setState(() => instantBookable = value),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickPhoto,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 230,
                decoration: BoxDecoration(
                  color: T.surfaceRaised,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: T.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: photoBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 54,
                            color: T.success,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Foto des Stellplatzes hinzufügen',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'OpenAI prüft Motiv, Qualität und personenbezogene Daten.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: T.muted),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(photoBytes!, fit: BoxFit.cover),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: IconButton.filled(
                              tooltip: 'Foto ändern',
                              onPressed: _pickPhoto,
                              icon: const Icon(Icons.edit_rounded),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      );

  Widget _publishStep() => _PageCard(
        icon: Icons.euro_rounded,
        title: 'Preis und Veröffentlichung',
        subtitle: 'Kostenlos oder kostenpflichtig – beide benötigen Bestätigung.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.volunteer_activism_rounded,
                color: freeParking ? T.success : T.muted,
              ),
              title: const Text(
                'Kostenlos anbieten',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('Stundenpreis und Gesamtpreis werden mit 0 € angezeigt.'),
              value: freeParking,
              onChanged: (value) {
                setState(() {
                  freeParking = value;
                  price.text = value ? '0,00' : '3,50';
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: price,
              enabled: !freeParking,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Preis pro Stunde in €',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
            ),
            const SizedBox(height: 18),
            const _Notice(
              icon: Icons.shield_rounded,
              text:
                  'Genaue Adresse bleibt geschützt. Das Foto wird erst nach AI-Freigabe öffentlich. Kostenlose und Sofort-Anfragen warten auf die Bestätigung des Anbieters.',
            ),
          ],
        ),
      );

  Widget _dimension(
    TextEditingController controller,
    String label,
    IconData icon,
  ) =>
      SizedBox(
        width: 260,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '$label in m',
            prefixIcon: Icon(icon),
          ),
        ),
      );

  Widget _featureSwitch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: value ? T.mintSoft : T.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: value ? T.mint : T.line),
        ),
        child: SwitchListTile(
          secondary: Icon(icon, color: value ? T.success : T.muted),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle),
          value: value,
          onChanged: onChanged,
        ),
      );

  Future<void> _submit() async {
    for (var index = 0; index < titles.length; index += 1) {
      final error = _stepError(index);
      if (error != null) {
        await _go(index);
        _showError(error);
        return;
      }
    }
    final selected = verifiedAddress!;
    setState(() => busy = true);
    try {
      final hourlyPrice =
          (HostListingValidation.parseNumber(price.text)! * 100).round();
      final created = await ref.read(hostRepositoryProvider).create(
            HostSpaceRecord(
              id: '',
              title: title.text.trim(),
              district: selected.district,
              landmark: landmark.text.trim(),
              latitude: pin.latitude,
              longitude: pin.longitude,
              exactAddress: selected.displayName,
              entranceInstructions: instructions.text.trim(),
              hourlyPriceCents: hourlyPrice,
              maxHeight: HostListingValidation.parseNumber(height.text)!,
              maxWidth: HostListingValidation.parseNumber(width.text)!,
              maxLength: HostListingValidation.parseNumber(length.text)!,
              accessType: accessType,
              covered: covered,
              evCharging: evCharging,
              accessible: accessible,
              instantBookable: instantBookable,
              verified: false,
              status: 'active',
            ),
          );

      ParkingMedia? media;
      if (photoBytes != null && photoName != null) {
        media = await ref.read(marketplaceRepositoryProvider).uploadParkingImage(
              created.id,
              photoBytes!,
              photoName!,
            );
      }
      ref.invalidate(parkingSpacesProvider);
      if (!mounted) return;
      final photoMessage = switch (media?.approvalStatus) {
        'approved' => ' Foto wurde automatisch freigegeben.',
        'rejected' => ' Bitte ersetze das abgelehnte Foto.',
        'pending' => ' Foto wartet auf Prüfung.',
        _ => '',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stellplatz wurde veröffentlicht.$photoMessage')),
      );
      context.go('/host');
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.title,
    required this.current,
    required this.count,
  });

  final String title;
  final int current;
  final int count;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [T.mint, T.success]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: T.shadowSmall,
                ),
                child: Icon(
                  [
                    Icons.location_on_rounded,
                    Icons.straighten_rounded,
                    Icons.auto_awesome_rounded,
                    Icons.rocket_launch_rounded,
                  ][current],
                  color: T.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Schritt ${current + 1} von $count',
                      style: const TextStyle(color: T.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              count,
              (index) => Expanded(
                child: AnimatedContainer(
                  duration: T.fast,
                  height: 5,
                  margin: EdgeInsets.only(right: index == count - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index <= current ? T.mint : T.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _PageCard extends StatelessWidget {
  const _PageCard({
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: T.surface,
            borderRadius: BorderRadius.circular(T.radius),
            border: Border.all(color: T.line),
            boxShadow: T.shadowSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: T.mintSoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: T.success),
                  ),
                  const SizedBox(width: 13),
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

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warning ? T.amberSoft : T.mintSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: warning ? T.amber : T.mint),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: warning ? T.warning : T.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
