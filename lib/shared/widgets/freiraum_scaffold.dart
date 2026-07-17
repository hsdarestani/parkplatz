import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/brand_config.dart';
import '../../config/design_tokens.dart';
import '../../features/booking/data/repositories.dart';

class FreiraumScaffold extends ConsumerWidget {
  const FreiraumScaffold({
    super.key,
    required this.title,
    required this.activePath,
    required this.child,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final String activePath;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = MediaQuery.sizeOf(context).width >= T.desktop;
    final mode = ref.watch(appModeProvider);

    return Scaffold(
      backgroundColor: T.porcelain,
      appBar: desktop
          ? null
          : AppBar(
              title: Text(title),
              actions: actions,
            ),
      bottomNavigationBar:
          desktop ? null : _BottomNavigation(activePath: activePath),
      body: Row(
        children: [
          if (desktop) _SideNavigation(activePath: activePath),
          Expanded(
            child: Column(
              children: [
                if (desktop)
                  _DesktopHeader(
                    title: title,
                    subtitle: subtitle,
                    actions: actions,
                  ),
                if (mode == AppMode.localBeta)
                  const _StatusBanner(
                    icon: Icons.science_outlined,
                    text:
                        'Lokaler Beta-Modus – Änderungen bleiben auf diesem Gerät.',
                    background: T.amberSoft,
                    foreground: T.warning,
                  ),
                if (mode == AppMode.checking)
                  const LinearProgressIndicator(minHeight: 2),
                if (mode == AppMode.unavailable)
                  _StatusBanner(
                    icon: Icons.cloud_off_outlined,
                    text: 'Die Live-Daten sind gerade nicht erreichbar.',
                    background: T.inkSoft,
                    foreground: Colors.white,
                    action: TextButton(
                      onPressed: ref.read(appModeProvider.notifier).check,
                      child: const Text('Erneut versuchen'),
                    ),
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: const BoxDecoration(
          color: T.surface,
          border: Border(bottom: BorderSide(color: T.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.5,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: T.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      );
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.activePath});

  final String activePath;

  @override
  Widget build(BuildContext context) => Container(
        width: 248,
        color: T.ink,
        padding: EdgeInsets.fromLTRB(
          18,
          MediaQuery.paddingOf(context).top + 24,
          18,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                _BrandMark(),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      BrandConfig.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'Parken. Teilen. Ankommen.',
                      style: TextStyle(color: T.subtle, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 38),
            ..._destinations.map(
              (destination) => _SideDestination(
                destination: destination,
                selected: _selected(activePath, destination.path),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: T.mint),
                  SizedBox(height: 10),
                  Text(
                    'Geschützte Adressen',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Genaue Zufahrten werden erst nach einer Buchung geteilt.',
                    style: TextStyle(color: T.subtle, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SideDestination extends StatelessWidget {
  const _SideDestination({
    required this.destination,
    required this.selected,
  });

  final _Destination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? T.mint.withOpacity(.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => context.go(destination.path),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    destination.icon,
                    color: selected ? T.mint : Colors.white70,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    destination.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.activePath});

  final String activePath;

  @override
  Widget build(BuildContext context) {
    final index = _destinations.indexWhere(
      (destination) => _selected(activePath, destination.path),
    );
    return NavigationBar(
      selectedIndex: index < 0 ? 0 : index,
      onDestinationSelected: (value) => context.go(_destinations[value].path),
      destinations: _destinations
          .map(
            (destination) => NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.shortLabel,
            ),
          )
          .toList(),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
    this.action,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: background,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: T.mint,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Text(
          'F',
          style: TextStyle(
            color: T.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _Destination {
  const _Destination(this.label, this.shortLabel, this.path, this.icon);

  final String label;
  final String shortLabel;
  final String path;
  final IconData icon;
}

const _destinations = [
  _Destination('Entdecken', 'Entdecken', '/discover', Icons.explore_outlined),
  _Destination(
    'Meine Buchungen',
    'Buchungen',
    '/bookings',
    Icons.confirmation_number_outlined,
  ),
  _Destination(
    'Stellplatz vermieten',
    'Vermieten',
    '/host',
    Icons.add_home_work_outlined,
  ),
  _Destination('Profil', 'Profil', '/profile', Icons.person_outline),
];

bool _selected(String activePath, String path) {
  if (path == '/host') return activePath.startsWith('/host');
  return activePath == path || activePath.startsWith('$path/');
}
