import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/brand_config.dart';
import '../../config/design_tokens.dart';
import '../../features/booking/data/repositories.dart';
import 'freiraum_motion.dart';

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
              toolbarHeight: 68,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: T.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              actions: actions,
            ),
      bottomNavigationBar:
          desktop ? null : _BottomNavigation(activePath: activePath),
      body: Row(
        children: [
          if (desktop) _SideNavigation(activePath: activePath),
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(child: _ContentBackground()),
                Column(
                  children: [
                    if (desktop)
                      MotionReveal(
                        offset: const Offset(0, -.045),
                        child: _DesktopHeader(
                          title: title,
                          subtitle: subtitle,
                          actions: actions,
                        ),
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
                    Expanded(
                      child: MotionReveal(
                        delay: const Duration(milliseconds: 70),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentBackground extends StatelessWidget {
  const _ContentBackground();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8F7F3),
                    T.porcelain,
                    Color(0xFFF0F4F1),
                  ],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Positioned(
              right: -110,
              top: -150,
              child: _GlowBlob(
                size: 360,
                color: T.mint.withOpacity(.08),
              ),
            ),
            Positioned(
              left: 80,
              bottom: -220,
              child: _GlowBlob(
                size: 420,
                color: T.amber.withOpacity(.055),
              ),
            ),
          ],
        ),
      );
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      );
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
        decoration: BoxDecoration(
          color: T.surface.withOpacity(.94),
          border: const Border(bottom: BorderSide(color: T.line)),
          boxShadow: [
            BoxShadow(
              color: T.ink.withOpacity(.035),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [T.mint, T.success],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.7,
                        ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: T.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            ...actions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(left: 10),
                child: action,
              ),
            ),
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
        padding: EdgeInsets.fromLTRB(
          18,
          MediaQuery.paddingOf(context).top + 24,
          18,
          24,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF081522), T.ink, Color(0xFF10243A)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MotionReveal(
              child: Row(
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
            ),
            const SizedBox(height: 38),
            ..._destinations.indexed.map(
              (entry) => MotionReveal(
                delay: Duration(milliseconds: 65 + entry.$1 * 45),
                child: _SideDestination(
                  destination: entry.$2,
                  selected: _selected(activePath, entry.$2.path),
                ),
              ),
            ),
            const Spacer(),
            MotionReveal(
              delay: const Duration(milliseconds: 260),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(.09),
                      T.mint.withOpacity(.065),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(.1)),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Genaue Zufahrten werden erst nach einer Buchung geteilt.',
                      style: TextStyle(color: T.subtle, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _SideDestination extends StatefulWidget {
  const _SideDestination({
    required this.destination,
    required this.selected,
  });

  final _Destination destination;
  final bool selected;

  @override
  State<_SideDestination> createState() => _SideDestinationState();
}

class _SideDestinationState extends State<_SideDestination> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: AnimatedScale(
            scale: hovered ? 1.015 : 1,
            duration: T.fast,
            curve: T.emphasized,
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: () => context.go(widget.destination.path),
                borderRadius: BorderRadius.circular(17),
                child: AnimatedContainer(
                  duration: T.fast,
                  curve: T.emphasized,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? T.mint.withOpacity(.16)
                        : hovered
                            ? Colors.white.withOpacity(.055)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: widget.selected
                          ? T.mint.withOpacity(.38)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: T.fast,
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: widget.selected
                              ? T.mint
                              : Colors.white.withOpacity(.06),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          widget.destination.icon,
                          color: widget.selected ? T.ink : Colors.white70,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.destination.label,
                        style: TextStyle(
                          color: widget.selected ? Colors.white : Colors.white70,
                          fontWeight:
                              widget.selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      AnimatedOpacity(
                        opacity: widget.selected || hovered ? 1 : 0,
                        duration: T.fast,
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
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
              selectedIcon: Icon(destination.icon, color: T.success),
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
                  fontWeight: FontWeight.w800,
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF63EBC8), T.mint],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: T.mint.withOpacity(.24),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
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
