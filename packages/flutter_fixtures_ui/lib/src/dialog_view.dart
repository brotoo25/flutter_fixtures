import 'package:flutter/material.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// A dialog-based implementation of DataSelectorView
///
/// This adapter shows a Material dialog for users to select a fixture from
/// a collection. It is a plain class: the dialog widget itself is a private
/// implementation detail.
///
/// The [contextProvider] is called each time a dialog is shown, so the
/// adapter never holds on to a possibly-stale BuildContext:
///
/// ```dart
/// FixturesDialogView(
///   contextProvider: () => navigatorKey.currentContext!,
/// )
/// ```
class FixturesDialogView implements DataSelectorView {
  /// Supplies the BuildContext used to show the dialog, resolved per pick.
  final BuildContext Function() contextProvider;

  /// Creates a dialog view that resolves its context through [contextProvider].
  FixturesDialogView({required this.contextProvider});

  /// Creates a dialog view bound to a fixed [context].
  ///
  /// Prefer the default constructor with a provider when the view outlives
  /// the widget that created it (e.g. stored in an interceptor).
  FixturesDialogView.of(BuildContext context)
      : this(contextProvider: (() => context));

  @override
  Future<FixtureChoice?> pick(FixtureCollection fixture) {
    return showDialog<FixtureChoice>(
      context: contextProvider(),
      builder: (BuildContext context) => _FixtureDialog(fixture: fixture),
    );
  }
}

/// The dialog widget backing [FixturesDialogView].
class _FixtureDialog extends StatefulWidget {
  final FixtureCollection fixture;

  const _FixtureDialog({required this.fixture});

  @override
  State<_FixtureDialog> createState() => _FixtureDialogState();
}

class _FixtureDialogState extends State<_FixtureDialog> {
  int? _selectedOptionIndex = 0;
  bool _remember = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final idx = widget.fixture.items.indexWhere((e) => e.defaultOption == true);
    _selectedOptionIndex = idx >= 0 ? idx : 0;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.fixture.description),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: RadioGroup<int>(
                  groupValue: _selectedOptionIndex,
                  onChanged: (value) =>
                      setState(() => _selectedOptionIndex = value),
                  child: Scrollbar(
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    controller: _scrollController,
                    child: ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      itemCount: widget.fixture.items.length,
                      itemBuilder: (context, index) {
                        final option = widget.fixture.items[index];
                        return ListTile(
                          leading: Radio<int>(value: index),
                          title: Text(
                              "${option.identifier} - ${option.description}"),
                          onTap: () =>
                              setState(() => _selectedOptionIndex = index),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Row(
                children: [
                  Checkbox(
                    value: _remember,
                    onChanged: (val) =>
                        setState(() => _remember = val ?? false),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _remember = !_remember),
                    child: const Text('Remember'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_selectedOptionIndex != null) {
              final selected = widget.fixture.items[_selectedOptionIndex!];
              Navigator.pop(
                context,
                FixtureChoice(document: selected, remember: _remember),
              );
            }
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
