import 'package:flutter/material.dart';
import '../../l10n/planit_l10n.dart';

import '../../models/calendar_event.dart';
import '../../services/calendar_controller.dart';
import '../profile/profile_widgets.dart';

const _palette = [
  (0xFF69AD94, '초록'),
  (0xFF6099C8, '파랑'),
  (0xFF7772C8, '보라'),
  (0xFFED986A, '주황'),
  (0xFFD76387, '분홍'),
  (0xFFC15D5D, '빨강'),
  (0xFFB38A2E, '노랑'),
  (0xFF388D96, '청록'),
];

Future<void> showCalendarColors(
  BuildContext context,
  CalendarController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (context) => Theme(
    data: profileTheme(context),
    child: Material(
      color: profileSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n(context).categoryColors,
                          style: TextStyle(
                            color: profileInk,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n(context).closeColorSettings,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    l10n(context).theSelectedColorAppliesToEveryEvent,
                    style: TextStyle(color: Color(0xFF6C879A), fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  for (final category in EventCategory.selectable)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE1EDF5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayLabel(context, category.label),
                            style: const TextStyle(
                              color: profileInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final (color, label) in _palette)
                                Semantics(
                                  button: true,
                                  selected:
                                      controller.colorFor(category) == color,
                                  label:
                                      '${displayLabel(context, category.label)} ${displayLabel(context, label)}',
                                  child: Tooltip(
                                    message:
                                        '${displayLabel(context, category.label)} ${displayLabel(context, label)}',
                                    child: Material(
                                      color: Color(color),
                                      shape: const CircleBorder(),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        key: ValueKey(
                                          'category-color-${category.name}-$color',
                                        ),
                                        onTap: () => controller
                                            .setCategoryColor(category, color),
                                        borderRadius: BorderRadius.circular(24),
                                        child: SizedBox(
                                          width: 40,
                                          height: 40,
                                          child:
                                              controller.colorFor(category) ==
                                                  color
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 22,
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
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
);
