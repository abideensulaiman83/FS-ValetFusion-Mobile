// lib/components/master_suggest_field.dart
//
// Type-ahead text field for the vehicle entry forms (Brand, Colour): suggests names from a master
// list (vehicle makes / colours) as you type, but any free text is still accepted - the master is
// a help, not a rule. Uses the caller's controller, so OCR prefill and form resets work as with a
// plain TextField. If the list can't be loaded it simply behaves like a plain TextField.
import 'package:flutter/material.dart';

class MasterSuggestField extends StatefulWidget {
  final TextEditingController controller;
  final Future<List<String>> Function() load;
  final InputDecoration decoration;
  final TextCapitalization textCapitalization;
  final int maxOptions;

  const MasterSuggestField({
    super.key,
    required this.controller,
    required this.load,
    required this.decoration,
    this.textCapitalization = TextCapitalization.words,
    this.maxOptions = 8,
  });

  @override
  State<MasterSuggestField> createState() => _MasterSuggestFieldState();
}

class _MasterSuggestFieldState extends State<MasterSuggestField> {
  final _focusNode = FocusNode();
  List<String> _names = const [];

  @override
  void initState() {
    super.initState();
    widget.load().then((names) {
      if (mounted) setState(() => _names = names);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Names starting with the typed text first, then ones containing it.
  Iterable<String> _options(TextEditingValue value) {
    final q = value.text.trim().toLowerCase();
    if (q.isEmpty || _names.isEmpty) return const [];
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
    return [...starts, ...contains].take(widget.maxOptions);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: _focusNode,
        optionsBuilder: _options,
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: widget.textCapitalization,
          decoration: widget.decoration,
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
