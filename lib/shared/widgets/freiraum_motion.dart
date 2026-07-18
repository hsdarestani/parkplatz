import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';

class MotionReveal extends StatefulWidget {
  const MotionReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = T.normal,
    this.offset = const Offset(0, .055),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<MotionReveal> createState() => _MotionRevealState();
}

class _MotionRevealState extends State<MotionReveal> {
  Timer? timer;
  bool visible = false;

  @override
  void initState() {
    super.initState();
    timer = Timer(widget.delay, () {
      if (mounted) setState(() => visible = true);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disabled) return widget.child;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: widget.duration,
      curve: T.emphasized,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : widget.offset,
        duration: widget.duration,
        curve: T.emphasized,
        child: widget.child,
      ),
    );
  }
}

class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool hovered = false;
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.enabled && widget.onTap != null;
    final scale = pressed
        ? .985
        : hovered && widget.enabled
            ? 1.008
            : 1.0;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: widget.enabled ? (_) => setState(() => hovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => hovered = false) : null,
      child: AnimatedSlide(
        offset: hovered && widget.enabled ? const Offset(0, -.012) : Offset.zero,
        duration: T.fast,
        curve: T.emphasized,
        child: AnimatedScale(
          scale: scale,
          duration: T.fast,
          curve: T.emphasized,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(T.radius),
            child: InkWell(
              onTap: interactive ? widget.onTap : null,
              onHighlightChanged: interactive
                  ? (value) => setState(() => pressed = value)
                  : null,
              borderRadius: BorderRadius.circular(T.radius),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedNumberText extends StatelessWidget {
  const AnimatedNumberText({
    super.key,
    required this.value,
    required this.builder,
    this.style,
  });

  final double value;
  final String Function(double value) builder;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: T.slow,
        curve: T.emphasized,
        builder: (context, animatedValue, _) => Text(
          builder(animatedValue),
          style: style,
        ),
      );
}

class AnimatedCheck extends StatelessWidget {
  const AnimatedCheck({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.elasticOut,
        builder: (context, value, _) => Transform.scale(
          scale: value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: T.mintSoft,
              border: Border.all(color: T.mint, width: 2),
              boxShadow: [
                BoxShadow(
                  color: T.mint.withOpacity(.22),
                  blurRadius: 34,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: T.success,
              size: 48,
            ),
          ),
        ),
      );
}
