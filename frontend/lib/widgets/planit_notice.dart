import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/profile/profile_widgets.dart';

final _notices = Expando<_NoticeHandle>();

/// A non-modal notification centered within the app's phone-sized content.
/// Uses the root overlay so save messages survive closing an editor route.
void showPlanitNotice(BuildContext context, Widget content) {
  if (!context.mounted) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  _notices[overlay]?.dismiss();
  final handle = _NoticeHandle(overlay);
  _notices[overlay] = handle;
  handle.entry = OverlayEntry(
    builder: (_) => _NoticeView(content: content, dismiss: handle.dismiss),
  );
  overlay.insert(handle.entry);
  handle.timer = Timer(
    Duration(seconds: MediaQuery.accessibleNavigationOf(context) ? 6 : 4),
    handle.dismiss,
  );
}

void hidePlanitNotice(BuildContext context) {
  if (!context.mounted) return;
  _notices[Overlay.of(context, rootOverlay: true)]?.dismiss();
}

class _NoticeHandle {
  _NoticeHandle(this.overlay);
  final OverlayState overlay;
  late final OverlayEntry entry;
  Timer? timer;
  bool _dismissed = false;

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    timer?.cancel();
    if (identical(_notices[overlay], this)) _notices[overlay] = null;
    entry.remove();
    entry.dispose();
  }
}

class _NoticeView extends StatefulWidget {
  const _NoticeView({required this.content, required this.dismiss});
  final Widget content;
  final VoidCallback dismiss;

  @override
  State<_NoticeView> createState() => _NoticeViewState();
}

class _NoticeViewState extends State<_NoticeView> {
  @override
  void dispose() {
    // A root navigator can be removed before the notification's timer fires.
    // Remove the entry after the host finishes unmounting, without a live timer.
    scheduleMicrotask(widget.dismiss);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: IgnorePointer(
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 344,
                maxHeight: MediaQuery.sizeOf(context).height * .7,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  onDismiss: widget.dismiss,
                  child: Material(
                    key: const ValueKey('planit-notice'),
                    color: profileButton,
                    elevation: 8,
                    shadowColor: const Color(0x3329ACF0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: Color(0xFFB9E4F8)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: profileBlue,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DefaultTextStyle(
                              maxLines: 10,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (Theme.of(context).textTheme.bodyMedium ??
                                          const TextStyle())
                                      .copyWith(
                                        color: profileInk,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        height: 1.5,
                                      ),
                              child: widget.content,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
