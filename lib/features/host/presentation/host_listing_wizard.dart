import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/freiraum_scaffold.dart';
import '../../parking/data/providers.dart';
import '../data/host_repository.dart';

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
                onStepTapped: (value) => setState(() => step = value),
                controlsBuilder: _controls,
                steps: [
                  Step(
                    title: const Text('Standort'),
                    subtitle: const Text('Adresse und Position'),
                    isActive: step >= 0,
                    state: step > 0 ? StepState.complete : StepState.indexed,
                    content: _locationStep(),
                  ),
                  Step(
                    title: const Text('Stellplatzdetails'),
                    subtitle: const Text('Maße und Zufahrt'),
                    isActive: step >= 1,
                    state: step > 1 ? StepState.complete : StepState.indexed,
                    content: _detailsStep(),
                  ),
                  Step(
                    title: const Text('Ausstattung'),
                    subtitle: const Text('Komfort und Zugang'),
                    isActive: step >= 2,
                    state: step > 2 ? StepState.complete : StepState.indexed,
                    content: _featuresStep(),
                  ),
                  Step(
                    title: const Text('Preis & Veröffentlichung'),
                    subtitle: const Text('Angebot prüfen und online stellen'),
                    isActive: step >= 3,
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
              onPressed: busy
                  ? null
                  : step == 3
                      ? _submit
                      : () => setState(() => step += 1),
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
            validator: _required,
          ),
          TextFormField(
            controller: address,
            decoration: const InputDecoration(labelText: 'Genaue Adresse'),
            validator: _required,
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
                  validator: _required,
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
                  validator: _required,
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
                  keyboardType: TextInputType.number,
                  validator: _number,
                ),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(
                  controller: longitude,
                  decoration: const InputDecoration(labelText: 'Längengrad'),
                  keyboardType: TextInputType.number,
                  validator: _number,
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
              _dimension(height, 'Max. Höhe in m'),
              _dimension(width, 'Max. Breite in m'),
              _dimension(length, 'Max. Länge in m'),
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
            validator: _required,
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
              ),
              keyboardType: TextInputType.number,
              validator: _positiveNumber,
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

  Widget _dimension(TextEditingController controller, String label) => SizedBox(
        width: 220,
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          validator: _positiveNumber,
        ),
      );

  Widget _switch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: value ? T.success : T.muted),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      );

  String? _required(String? value) => value == null || value.trim().length < 2
      ? 'Bitte ausfüllen.'
      : null;

  String? _number(String? value) =>
      _parse(value) == null ? 'Bitte gültige Zahl eingeben.' : null;

  String? _positiveNumber(String? value) {
    final parsed = _parse(value);
    return parsed == null || parsed <= 0 ? 'Bitte Wert größer 0 eingeben.' : null;
  }

  double? _parse(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      setState(() => step = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte prüfe alle Pflichtfelder.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final hourlyPriceCents = ((_parse(price.text) ?? 0) * 100).round();
      await ref.read(hostRepositoryProvider).create(
            HostSpaceRecord(
              id: '',
              title: title.text.trim(),
              district: district.text.trim(),
              landmark: landmark.text.trim(),
              latitude: _parse(latitude.text)!,
              longitude: _parse(longitude.text)!,
              exactAddress: address.text.trim(),
              entranceInstructions: instructions.text.trim(),
              hourlyPriceCents: hourlyPriceCents,
              maxHeight: _parse(height.text)!,
              maxWidth: _parse(width.text)!,
              maxLength: _parse(length.text)!,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
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
