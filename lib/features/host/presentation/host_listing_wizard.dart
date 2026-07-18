import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
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

  int step = 0;
  String accessType = 'open';
  bool covered = false;
  bool evCharging = false;
  bool accessible = false;
  bool instantBookable = true;
  bool busy = false;

  @override
  void dispose() {
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
    final error = _stepError(targetStep);
    formKey.currentState?.validate();
    if (error == null) return true;
    setState(() => step = targetStep);
    _showError(error);
    return false;
  }

  void _continue() {
    if (!_validateStep(step)) return;
    setState(() => step += 1);
  }

  void _goToStep(int targetStep) {
    if (targetStep <= step) {
      setState(() => step = targetStep);
      return;
    }

    for (var current = 0; current < targetStep; current += 1) {
      if (!_validateStep(current)) return;
    }
    setState(() => step = targetStep);
  }

  StepState _stateFor(int targetStep) {
    if (step == targetStep) return StepState.editing;
    if (step > targetStep && _stepError(targetStep) == null) {
      return StepState.complete;
    }
    return StepState.indexed;
  }

  @override
  Widget build(BuildContext context) => FreiraumScaffold(
        title: 'Stellplatz hinzufügen',
        subtitle: 'In vier Schritten online und buchbar.',
        activePath: '/host/new',
        child: Form(
          key: formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Stepper(
                currentStep: step,
                type: StepperType.vertical,
                onStepTapped: _goToStep,
                controlsBuilder: _controls,
                steps: [
                  Step(
                    title: const Text('Standort'),
                    subtitle: const Text('Adresse und Position'),
                    isActive: step >= 0,
                    state: _stateFor(0),
                    content: _locationStep(),
                  ),
                  Step(
                    title: const Text('Stellplatzdetails'),
                    subtitle: const Text('Maße und Zufahrt'),
                    isActive: step >= 1,
                    state: _stateFor(1),
                    content: _detailsStep(),
                  ),
                  Step(
                    title: const Text('Ausstattung'),
                    subtitle: const Text('Komfort und Zugang'),
                    isActive: step >= 2,
                    state: _stateFor(2),
                    content: _featuresStep(),
                  ),
                  Step(
                    title: const Text('Preis & Veröffentlichung'),
                    subtitle: const Text('Angebot prüfen und online stellen'),
                    isActive: step >= 3,
                    state: _stateFor(3),
                    content: _publishStep(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _controls(BuildContext context, ControlsDetails details) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: busy ? null : step == 3 ? _submit : _continue,
              icon: Icon(step == 3 ? Icons.publish : Icons.arrow_forward),
              label: Text(
                busy
                    ? 'Wird veröffentlicht …'
                    : step == 3
                        ? 'Stellplatz veröffentlichen'
                        : 'Weiter',
              ),
            ),
            if (step > 0) ...[
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: busy ? null : () => setState(() => step -= 1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Zurück'),
              ),
            ],
          ],
        ),
      );

  Widget _locationStep() => _section(
        children: [
          const _SectionIntro(
            icon: Icons.location_on_outlined,
            title: 'Wo befindet sich der Stellplatz?',
            text:
                'Die genaue Adresse bleibt für Suchende verborgen und wird erst nach einer bestätigten Buchung freigegeben.',
          ),
          TextFormField(
            controller: title,
            decoration: const InputDecoration(
              labelText: 'Titel',
              hintText: 'z. B. Innenhof nahe Hauptbahnhof',
            ),
            validator: HostListingValidation.title,
          ),
          TextFormField(
            controller: address,
            decoration: const InputDecoration(labelText: 'Genaue Adresse'),
            validator: HostListingValidation.address,
          ),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 300,
                child: TextFormField(
                  controller: district,
                  decoration: const InputDecoration(labelText: 'Stadtteil'),
                  validator: HostListingValidation.district,
                ),
              ),
              SizedBox(
                width: 300,
                child: TextFormField(
                  controller: landmark,
                  decoration: const InputDecoration(
                    labelText: 'Öffentlicher Orientierungspunkt',
                    hintText: 'z. B. nahe Messe Frankfurt',
                  ),
                  validator: HostListingValidation.landmark,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: TextFormField(
                  controller: latitude,
                  decoration: const InputDecoration(labelText: 'Breitengrad'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: HostListingValidation.latitude,
                ),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(
                  controller: longitude,
                  decoration: const InputDecoration(labelText: 'Längengrad'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: HostListingValidation.longitude,
                ),
              ),
            ],
          ),
        ],
      );

  Widget _detailsStep() => _section(
        children: [
          const _SectionIntro(
            icon: Icons.straighten_outlined,
            title: 'Welche Fahrzeuge passen?',
            text:
                'Vollständige Maße verhindern ungeeignete Buchungen und Rückfragen.',
          ),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              _dimension(
                height,
                'Max. Höhe in m',
                HostListingValidation.height,
              ),
              _dimension(
                width,
                'Max. Breite in m',
                HostListingValidation.width,
              ),
              _dimension(
                length,
                'Max. Länge in m',
                HostListingValidation.length,
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            value: accessType,
            decoration: const InputDecoration(labelText: 'Art der Zufahrt'),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('Offene Zufahrt')),
              DropdownMenuItem(value: 'barrier', child: Text('Schranke')),
              DropdownMenuItem(value: 'gate', child: Text('Tor')),
              DropdownMenuItem(
                value: 'underground',
                child: Text('Tiefgarage'),
              ),
              DropdownMenuItem(
                value: 'reception',
                child: Text('Rezeption / Empfang'),
              ),
            ],
            onChanged: (value) => setState(() => accessType = value ?? 'open'),
          ),
          TextFormField(
            controller: instructions,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Zufahrts- und Einparkhinweise',
              hintText: 'Tor, Stellplatznummer, Schlüssel oder Besonderheiten',
            ),
            validator: HostListingValidation.instructions,
          ),
        ],
      );

  Widget _featuresStep() => _section(
        children: [
          const _SectionIntro(
            icon: Icons.tune_outlined,
            title: 'Ausstattung und Buchungsart',
            text: 'Diese Angaben erscheinen in Suche und Detailansicht.',
          ),
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
            'Passende Anfragen werden direkt bestätigt',
            Icons.bolt_outlined,
            instantBookable,
            (value) => setState(() => instantBookable = value),
          ),
        ],
      );

  Widget _publishStep() => _section(
        children: [
          const _SectionIntro(
            icon: Icons.euro_outlined,
            title: 'Preis festlegen',
            text:
                'Der verbindliche Gesamtpreis wird bei jeder Buchung serverseitig berechnet.',
          ),
          SizedBox(
            width: 280,
            child: TextFormField(
              controller: price,
              decoration: const InputDecoration(
                labelText: 'Preis pro Stunde in €',
                prefixIcon: Icon(Icons.euro),
                helperText: 'Erlaubt: 0,50 € bis 1.000 €',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: HostListingValidation.price,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
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
                    'Mit der Veröffentlichung bestätigst du, dass du den Stellplatz anbieten darfst. Der Eintrag erscheint sofort als nicht verifiziertes Live-Angebot und kann jederzeit pausiert werden.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _section({required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.radius),
          border: Border.all(color: T.line),
          boxShadow: T.shadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children
              .expand((widget) => [widget, const SizedBox(height: 14)])
              .toList()
            ..removeLast(),
        ),
      );

  Widget _dimension(
    TextEditingController controller,
    String label,
    FormFieldValidator<String> validator,
  ) =>
      SizedBox(
        width: 220,
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
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
    for (var targetStep = 0; targetStep < 4; targetStep += 1) {
      if (!_validateStep(targetStep)) return;
    }

    setState(() => busy = true);
    try {
      final hourlyPriceCents =
          (HostListingValidation.parseNumber(price.text)! * 100).round();
      await ref.read(hostRepositoryProvider).create(
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
      ref.invalidate(parkingSpacesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stellplatz wurde veröffentlicht.')),
        );
        context.go('/host');
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
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
                Text(text, style: const TextStyle(color: T.muted)),
              ],
            ),
          ),
        ],
      );
}
