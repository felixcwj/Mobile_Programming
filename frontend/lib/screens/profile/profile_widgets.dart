import 'dart:typed_data';
import 'package:flutter/material.dart';

const profileBlue = Color(0xFF0077CC);
const profileSky = Color(0xFF55D6F5);
const profileInk = Color(0xFF073365);
const profileSurface = Color(0xFFF8FBFD);
const profileWell = Color(0xFFEAF3F9);
const profileButton = Color(0xFFDDF1FF);

class ProfilePageScaffold extends StatelessWidget {
  const ProfilePageScaffold({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: profileTheme(context),
    child: Scaffold(
      backgroundColor: const Color(0xFFF0F5F9),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: profileSurface,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFFD5E6EF), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1629ACF0),
                  blurRadius: 32,
                  spreadRadius: 3,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '뒤로',
                        onPressed: Navigator.of(context).canPop()
                            ? () => Navigator.of(context).pop()
                            : null,
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color: profileInk,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: profileInk,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

ThemeData profileTheme(BuildContext context) => Theme.of(context).copyWith(
  scaffoldBackgroundColor: profileSurface,
  colorScheme: ColorScheme.fromSeed(
    seedColor: profileBlue,
    primary: profileBlue,
    onPrimary: Colors.white,
    primaryContainer: profileButton,
    onPrimaryContainer: profileInk,
    onSurface: profileInk,
    onSurfaceVariant: const Color(0xFF526A7B),
    surface: profileSurface,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: profileSurface,
    foregroundColor: profileInk,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: profileInk,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF7FBFE),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: profileBlue, width: 2),
    ),
  ),
);

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.bytes, this.radius = 32});
  final Uint8List? bytes;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: profileSky,
    child: bytes == null
        ? SizedBox.square(
            dimension: radius * 2,
            child: const CustomPaint(painter: _ProfileFacePainter()),
          )
        : ClipOval(
            child: Image.memory(
              bytes!,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) =>
                  Icon(Icons.person_outline, size: radius),
            ),
          ),
  );
}

class _ProfileFacePainter extends CustomPainter {
  const _ProfileFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = profileInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .045
      ..strokeCap = StrokeCap.round;
    final arch = Path()
      ..moveTo(size.width * .20, size.height * .45)
      ..cubicTo(
        size.width * .24,
        size.height * -.01,
        size.width * .76,
        size.height * -.01,
        size.width * .80,
        size.height * .45,
      );
    canvas.drawPath(arch, paint);
    paint.style = PaintingStyle.fill;
    for (final x in [.36, .64]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * .66),
          width: size.width * .065,
          height: size.height * .115,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileFacePainter oldDelegate) => false;
}

class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
  });
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: profileWell,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: const TextStyle(color: Color(0xFF73777D), height: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}

class ProfileSaveButton extends StatelessWidget {
  const ProfileSaveButton({
    super.key,
    required this.saving,
    required this.onPressed,
  });
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: saving ? null : onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    icon: saving
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.check, size: 20),
    label: Text(saving ? '저장 중…' : '저장하기'),
  );
}
