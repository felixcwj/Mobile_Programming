import 'package:flutter/material.dart';
import '../app_theme.dart';

class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: child,
        ),
      );
}

class Surface extends StatelessWidget {
  const Surface({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.dark))),
          if (trailing != null) trailing!,
        ],
      );
}

class TinyLabel extends StatelessWidget {
  const TinyLabel(this.text, {super.key, this.color = AppColors.primary});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withAlpha(23), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}

class FieldTitle extends StatelessWidget {
  const FieldTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.dark)),
      );
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.eyebrow, required this.title, required this.subtitle});
  final String eyebrow;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow.toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, letterSpacing: 1.4, fontSize: 11)),
        const SizedBox(height: 9),
        Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.dark)),
        const SizedBox(height: 7),
        Text(subtitle, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.muted)),
      ]);
}

class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.label, required this.onPressed, this.icon = Icons.arrow_forward_rounded});
  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.border))),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: PageWidth(
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(label),
                  const SizedBox(width: 7),
                  Icon(icon, size: 19),
                ]),
              ),
            ),
          ),
        ),
      );
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 48});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(15)),
        child: Icon(icon, color: AppColors.primary, size: size * 0.48),
      );
}

class DemoNotice extends StatelessWidget {
  const DemoNotice(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.muted),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5))),
      ]);
}
