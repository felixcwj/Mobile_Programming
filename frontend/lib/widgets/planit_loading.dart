import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../screens/profile/profile_widgets.dart';
import 'planit_mascot.dart';

/// Indeterminate progress, using the app's existing character and palette.
class PlanitLoading extends StatefulWidget {
  const PlanitLoading({super.key, required this.message});

  final String message;

  @override
  State<PlanitLoading> createState() => _PlanitLoadingState();
}

class _PlanitLoadingState extends State<PlanitLoading>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: widget.message,
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 156,
            height: 156,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Colors.white, profileButton]),
            ),
            child: const PlanitMascot(size: 116),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => SizedBox(
              height: 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [for (var index = 0; index < 3; index++) _dot(index)],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: profileInk,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dot(int index) {
    final bounce = MediaQuery.disableAnimationsOf(context)
        ? 0.0
        : math.max(0.0, math.sin(_animation.value * math.pi * 2 - index * .7));
    return Transform.translate(
      key: ValueKey('planit-loading-dot-$index'),
      offset: Offset(0, -8 * bounce),
      child: Container(
        width: 9,
        height: 9,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: profileBlue.withValues(alpha: .35 + .65 * bounce),
        ),
      ),
    );
  }
}

/// Keeps the current form and scroll position while an operation is pending.
class PlanitLoadingOverlay extends StatelessWidget {
  const PlanitLoadingOverlay({
    super.key,
    required this.loading,
    required this.message,
    required this.child,
  });

  final bool loading;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !loading,
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (loading)
          Positioned.fill(
            child: BlockSemantics(
              child: Stack(
                children: [
                  ModalBarrier(
                    dismissible: false,
                    color: profileSurface.withValues(alpha: .98),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: PlanitLoading(message: message),
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
