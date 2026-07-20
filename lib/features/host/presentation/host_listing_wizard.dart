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

class HostListingWizardScreen extends ConsumerStatefulWidget {
  const HostListingWizardScreen({super.key});

  @override
  ConsumerState<HostListingWizardScreen> createState() =>
      _HostListingWizardScreenState();
}

class _HostListingWizardScreenState
    extends ConsumerState<HostListingWizardScreen> {
  final formKey = GlobalKey<FormState>();
  final pageController = PageController();
  final mapController = MapController();
  final title = TextEditingController();
  final district = TextEditingController(text: 'Frankfurt');
  final landmark = TextEditingController();
  final address = TextEditingController();
  final latitude = TextEditingController(text: '50.1109');
  final longitude = TextEditingController(text: '8.6821');
  final instructions = TextEditingController();
  final price = TextEditingController(text: '3,50');
  final height = TextEditingController(text: '2,10');
  final width = TextEditingController(text: '2,50');
  final length = TextEditingController(text: '5,20');
  final mapProvider = OpenStreetMapProvider();

  Timer? addressTimer;
  int step = 0;
  String accessType = 'open';
  bool covered = false;
  bool evCharging = false;
  bool accessible = false;
  bool instantBookable = true;
  bool freeParking = false;
  bool busy = false;
  bool addressLoading = false;
  bool addressVerified = false;
  List<AddressSuggestion> suggestions = const [];
  Uint8List? photoBytes;
  String? photoName;
  LatLng pin = const LatLng(50.1109, 8.6821);

  static const titles = [
    'Standort bestätigen',
    'Größe und Zufahrt',
    'Ausstattung und Foto',
    'Preis und Veröffentlichung',
  ];

  @override
  void dispose() {
    addressTimer?.cancel();
    pageController.dispose();
    for (final controller in [
      title,
      district,
      landmark,
      address,
      latitude,
      longitude,
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

  String? _stepError(int targetStep) => HostListingValidation.errorForStep(
        targetStep,
        titleValue: title.text,
        districtValue: district.text,
        landmarkValue: landmark.text,
        addressValue: address.text,
        latitudeValue: latitude.text,
        longitudeValue: longitude.text,
        instructionsValue: instructions.text,
        heightValue: height.text,
        widthValue: width.text,
        lengthValue: length.text,
        priceValue: price.text,
      );

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validateStep(int targetStep) {
    formKey.currentState?.validate();
    final error = _stepError(targetStep);
    if (error == null) return true;
    _showError(error);
    return false;
  }

  Future<void> _go(int target) async {
    if (target > step && !_validateStep(step)) return;
    setState(() => step = target);
    await pageController.animateToPage(
      target,
      duration: T.normal,
      curve: T.emphasized,
    );
  }

  void _searchAddress(String value) {
    addressVerified = false;
    addressTimer?.cancel();
    if (value.trim().length < 3) {
      setState(() => suggestions = const []);
      return;
    }
    addressTimer = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => addressLoading = true);
      try {
        final results = await ref
            .read(marketplaceRepositoryProvider)
            .suggestAddress(value);
        if (mounted) setState(() => suggestions = results);
      } catch (_) {
        if (mounted) setState(() => suggestions = const []);
      } finally {
        if (mounted) setState(() => addressLoading = false);
      }
    });
  }

  void _selectAddress(AddressSuggestion suggestion) {
    address.text = suggestion.displayName;
    district.text = suggestion.district;
    if (landmark.text.trim().isEmpty && suggestion.road != null) {
      landmark.text = suggestion.road!;
    }
    _setPin(LatLng(suggestion.latitude, suggestion.longitude));
    setState(() {
      addressVerified = true;
      suggestions = const [];
    });
    mapController.move(pin, 17);
  }

  void _setPin(LatLng value) {
    pin = value;
    latitude.text = value.latitude.toStringAsFixed(6);
    longitude.text = value.longitude.toStringAsFixed(6);
    setState(() {});
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
        subtitle: 'Geführte Einrichtung mit Adress- und Fotoprüfung.',
        activePath: '/host/new',
        child: Form(
          key: formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                        controller: pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (value) => setState(() => step = value),
                        children: [
                          _locationStep(),
                          _detailsStep(),
                          _featuresStep(),
                          _publishStep(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
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
                                  ? Icons.publish_rounded
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
        ),
      );

  Widget _locationStep() => _PageCard(
        icon: Icons.location_on_outlined,
        title: 'Adresse auswählen und Pin prüfen',
        subtitle:
            'Wähle einen echten Adressvorschlag und korrigiere den Pin direkt auf der Karte.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Titel',
                hintText: 'z. B. Innenhof nahe Hauptbahnhof',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: HostListingValidation.title,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: address,
              decoration: InputDecoration(
                labelText: 'Genaue Adresse',
                hintText: 'Straße und Hausnummer eingeben',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: addressLoading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : addressVerified
                        ? const Icon(Icons.verified_rounded, color: T.success)
                        : null,
              ),
              onChanged: _searchAddress,
              validator: HostListingValidation.address,
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: T.surface,
                  borderRadius: BorderRadius.circular(16),
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    controller: district,
                    decoration: const InputDecoration(
                      labelText: 'Stadtteil',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    validator: HostListingValidation.district,
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: TextFormField(
                    controller: landmark,
                    decoration: const InputDecoration(
                      labelText: 'Orientierungspunkt',
                      hintText: 'z. B. nahe Messe Frankfurt',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    validator: HostListingValidation.landmark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 300,
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: pin,
                    initialZoom: 16,
                    onTap: (_, point) => _setPin(point),
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
                          width: 62,
                          height: 62,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_pin,
                            size: 58,
                            color: T.success,
                          ),
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(mapProvider.attribution),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.touch_app_outlined, size: 18, color: T.muted),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Tippe auf die tatsächliche Einfahrt, um den Pin zu verschieben.',
                    style: TextStyle(color: T.muted),
                  ),
                ),
              ],
            ),
            Offstage(
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: latitude,
                      validator: HostListingValidation.latitude,
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: longitude,
                      validator: HostListingValidation.longitude,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _detailsStep() => _PageCard(
        icon: Icons.straighten_outlined,
        title: 'Welche Fahrzeuge passen?',
        subtitle:
            'Maße und Zufahrtsart schützen Fahrer und Anbieter vor Fehlbuchungen.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _dimension(
                  height,
                  'Max. Höhe in m',
                  Icons.height_rounded,
                  HostListingValidation.height,
                ),
                _dimension(
                  width,
                  'Max. Breite in m',
                  Icons.width_normal_rounded,
                  HostListingValidation.width,
                ),
                _dimension(
                  length,
                  'Max. Länge in m',
                  Icons.straighten_rounded,
                  HostListingValidation.length,
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: accessType,
              decoration: const InputDecoration(
                labelText: 'Art des Stellplatzes und der Zufahrt',
                prefixIcon: Icon(Icons.garage_outlined),
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
            TextFormField(
              controller: instructions,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Zufahrts- und Einparkhinweise',
                hintText: 'Tor, Stellplatznummer, Schlüssel oder Besonderheiten',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
              validator: HostListingValidation.instructions,
            ),
          ],
        ),
      );

  Widget _featuresStep() => _PageCard(
        icon: Icons.photo_camera_outlined,
        title: 'Ausstattung und echtes Foto',
        subtitle:
            'Das Foto wird vor der öffentlichen Anzeige automatisch geprüft.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _switch(
              'Überdacht',
              'Schutz vor Regen und direkter Sonne',
              Icons.roofing_outlined,
              covered,
              (value) => setState(() => covered = value),
            ),
            _switch(
              'E-Laden möglich',
              'Ladepunkt am oder nahe dem Stellplatz',
              Icons.ev_station_outlined,
              evCharging,
              (value) => setState(() => evCharging = value),
            ),
            _switch(
              'Barrierearm',
              'Breiter Zugang und möglichst stufenfreier Weg',
              Icons.accessible_outlined,
              accessible,
              (value) => setState(() => accessible = value),
            ),
            _switch(
              'Sofort buchbar',
              'Der Zeitraum ist sofort reserviert; der Anbieter bestätigt trotzdem die Übergabe.',
              Icons.bolt_outlined,
              instantBookable,
              (value) => setState(() => instantBookable = value),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickPhoto,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: T.surfaceRaised,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: T.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: photoBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 50, color: T.success),
                          SizedBox(height: 10),
                          Text(
                            'Foto des Stellplatzes hinzufügen',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'JPG, PNG oder WEBP · automatische Qualitätsprüfung',
                            style: TextStyle(color: T.muted),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(photoBytes!, fit: BoxFit.cover),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: IconButton.filled(
                              tooltip: 'Foto ändern',
                              onPressed: _pickPhoto,
                              icon: const Icon(Icons.edit_outlined),
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
        icon: Icons.euro_outlined,
        title: 'Preis und Veröffentlichung',
        subtitle:
            'Kostenlose Stellplätze sind möglich. Jede Buchung benötigt weiterhin eine Bestätigung.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.money_off_csred_outlined),
              title: const Text(
                'Kostenlos anbieten',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text('Gesamtpreis und Stundenpreis werden mit 0 € angezeigt.'),
              value: freeParking,
              onChanged: (value) {
                setState(() {
                  freeParking = value;
                  price.text = value ? '0,00' : '3,50';
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: price,
              enabled: !freeParking,
              decoration: const InputDecoration(
                labelText: 'Preis pro Stunde in €',
                prefixIcon: Icon(Icons.euro_rounded),
                helperText: '0 € für kostenlos oder bis maximal 1.000 €',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: HostListingValidation.price,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: T.mintSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: T.mint),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: T.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Die genaue Adresse bleibt geschützt. Fotos erscheinen erst nach Freigabe. Auch kostenlose und sofort buchbare Aufenthalte werden vom Anbieter bestätigt.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _dimension(
    TextEditingController controller,
    String label,
    IconData icon,
    FormFieldValidator<String> validator,
  ) =>
      SizedBox(
        width: 250,
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          validator: validator,
        ),
      );

  Widget _switch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: value ? T.success : T.muted),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      );

  Future<void> _submit() async {
    for (var targetStep = 0; targetStep < titles.length; targetStep += 1) {
      if (!_validateStep(targetStep)) {
        await _go(targetStep);
        return;
      }
    }

    setState(() => busy = true);
    try {
      final hourlyPriceCents =
          (HostListingValidation.parseNumber(price.text)! * 100).round();
      final created = await ref.read(hostRepositoryProvider).create(
            HostSpaceRecord(
              id: '',
              title: title.text.trim(),
              district: district.text.trim(),
              landmark: landmark.text.trim(),
              latitude: HostListingValidation.parseNumber(latitude.text)!,
              longitude: HostListingValidation.parseNumber(longitude.text)!,
              exactAddress: address.text.trim(),
              entranceInstructions: instructions.text.trim(),
              hourlyPriceCents: hourlyPriceCents,
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
        'approved' => ' Foto wurde freigegeben.',
        'rejected' => ' Foto benötigt ein neues Motiv.',
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
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          Text(
            'Schritt ${current + 1} von $count',
            style: const TextStyle(color: T.muted, fontWeight: FontWeight.w700),
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
          width: double.infinity,
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 19,
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
