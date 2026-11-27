import 'package:flutter/material.dart';
import '../../l10n/planit_l10n.dart';
import 'room_widgets.dart';

class RoomPreferenceEditor extends StatefulWidget {
  const RoomPreferenceEditor({
    super.key,
    required this.initialText,
    required this.onSave,
    this.readOnly = false,
  });

  final String initialText;
  final ValueChanged<String> onSave;
  final bool readOnly;

  @override
  State<RoomPreferenceEditor> createState() => _RoomPreferenceEditorState();
}

class _RoomPreferenceEditorState extends State<RoomPreferenceEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(covariant RoomPreferenceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        _text.text == oldWidget.initialText &&
        (!_text.value.isComposingRangeValid ||
            _text.value.composing.isCollapsed)) {
      _text.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.readOnly || !_formKey.currentState!.validate()) return;
    final value = _text.text.trim();
    widget.onSave(value);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n(context).preferencesSaved2)));
  }

  @override
  Widget build(BuildContext context) => RoomPanel(
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n(context).ourPreferences,
                  style: TextStyle(
                    color: roomInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!widget.readOnly)
                TextButton(
                  key: const ValueKey('save-room-preference'),
                  onPressed: _save,
                  style: TextButton.styleFrom(
                    foregroundColor: roomBlue,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(l10n(context).save),
                )
              else
                Tooltip(
                  message: l10n(context).preferencesForTheConfirmedPlan,
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: roomMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('room-preference'),
            controller: _text,
            readOnly: widget.readOnly,
            minLines: 4,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n(context).enterWhatYouWouldLikeToDo
                : null,
            style: const TextStyle(color: roomInk, fontSize: 14, height: 1.6),
            decoration: InputDecoration(
              hintText: l10n(context).enterWhatYouWouldLikeToDo2,
              hintStyle: const TextStyle(color: roomMuted, fontSize: 13),
              fillColor: roomBackground,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFDDEAF2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFDDEAF2)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
