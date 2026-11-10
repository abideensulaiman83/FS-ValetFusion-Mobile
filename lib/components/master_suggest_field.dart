// lib/components/master_suggest_field.dart
//
// Type-ahead text field for the vehicle entry forms (Brand, Colour): suggests names from a master
// list (vehicle makes / colours) as you type. Uses the caller's controller, so OCR prefill and form
// resets work as with a plain TextField. If the list can't be loaded it simply behaves like a plain
// TextField.
//
// Two modes:
//  * default (driver receive form) - the master is a help, not a rule: any free text is accepted.
//  * pickOnly (key controller desk) - the value must be one of the master names: the full list
//    shows on focus, typing filters it, and text that is not a master name is flagged under the
//    field. The form checks [MasterSuggestFieldState.isValid] before saving. If the list is empty
//    (failed to load / none set up) free text is accepted, so the desk is never blocked.
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';

class MasterSuggestField extends StatefulWidget {
  final TextEditingController controller;
  final Future<List<String>> Function() load;
  final InputDecoration decoration;
  final TextCapitalization textCapitalization;
  final int maxOptions;
  final bool pickOnly;

  const MasterSuggestField({
    super.key,
    required this.controller,
    required this.load,
    required this.decoration,
    this.textCapitalization = TextCapitalization.words,
    this.maxOptions = 8,
    this.pickOnly = false,
  });

  @override
  State<MasterSuggestField> createState() => MasterSuggestFieldState();
}

class MasterSuggestFieldState extends State<MasterSuggestField> {
  final _focusNode = FocusNode();
  List<String> _names = const [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
    widget.load().then((names) {
      if (mounted) setState(() => _names = names);
    }).catchError((_) {});
  }

  @override
  void didUpdateWidget(MasterSuggestField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChange);
      widget.controller.addListener(_onTextChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    _focusNode.dispose();
    super.dispose();
  }

  /// The master name matching [text] (ignoring case and outer spaces), or null.
  String? _match(String text) {
    final q = text.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final n in _names) {
      if (n.toLowerCase() == q) return n;
    }
    return null;
  }

  /// Pick-only check: empty is fine (the field is optional), a master name is fine, and anything
  /// goes when there is no master list to pick from. Always true outside pick-only mode.
  bool get isValid {
    if (!widget.pickOnly || _names.isEmpty) return true;
    final text = widget.controller.text.trim();
    return text.isEmpty || _match(text) != null;
  }

  /// Typed a master name in another case - store it as the master spells it.
  void normalise() {
    final m = _match(widget.controller.text);
    if (m != null && m != widget.controller.text) widget.controller.text = m;
  }

  void _onFocusChange() {
    if (!widget.pickOnly || !mounted) return;
    if (!_focusNode.hasFocus) normalise();
    setState(() {}); // show / hide the "pick from the list" message
  }

  void _onTextChange() {
    if (widget.pickOnly && mounted) setState(() {});
  }

  /// Names starting with the typed text first, then ones containing it. Pick-only mode lists every
  /// name while the field is still empty, so the user can just scroll and pick.
  Iterable<String> _options(TextEditingValue value) {
    final q = value.text.trim().toLowerCase();
    if (_names.isEmpty) return const [];
    if (q.isEmpty) return widget.pickOnly ? _names : const [];
    final starts = <String>[], contains = <String>[];
    for (final n in _names) {
      final l = n.toLowerCase();
      if (l == q) continue; // already typed in full
      if (l.startsWith(q)) {
        starts.add(n);
      } else if (l.contains(q)) {
        contains.add(n);
      }
    }
    final all = [...starts, ...contains];
    return widget.pickOnly ? all : all.take(widget.maxOptions);
  }

  @override
  Widget build(BuildContext context) {
    // Flag a non-master value once the user has left the field (not while still typing).
    final showError = widget.pickOnly && !_focusNode.hasFocus && !isValid;
    final decoration = showError
        ? widget.decoration.copyWith(errorText: tr(context, 'Pick a name from the list'))
        : widget.decoration;
    return LayoutBuilder(builder: (context, constraints) {
      return RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: _options,
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: widget.textCapitalization,
          decoration: decoration,
          onSubmitted: (_) => onSubmitted(),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 220, maxWidth: constraints.maxWidth),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final name = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Text(name),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
  }
}
