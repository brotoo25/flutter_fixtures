import 'package:flutter/material.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// A dialog-based implementation of DataSelectorView
///
/// This class provides a dialog UI for users to select a fixture from a collection.
class FixturesDialogView extends StatefulWidget implements DataSelectorView {
  /// The BuildContext used to show the dialog
  final BuildContext context;

  /// The fixture collection to display, if any
  final FixtureCollection? fixture;

  /// Creates a new FixturesDialogView with the specified context and fixture
  const FixturesDialogView({
    super.key,
    required this.context,
    this.fixture,
  });

  @override
  State<FixturesDialogView> createState() => _FixturesDialogViewState();

  @override
  Future<FixtureDocument?> pick(FixtureCollection fixture) {
    return showDialog<FixtureDocument>(
      context: context,
      builder: (BuildContext context) {
        return FixturesDialogView(
          context: context,
          fixture: fixture,
        );
      },
    );
  }
}

class _FixturesDialogViewState extends State<FixturesDialogView> {
  int? _selectedOptionIndex = 0;

  @override
  Widget build(BuildContext context) {
    return widget.fixture == null
        ? const SizedBox.shrink()
        : AlertDialog(
            title: Text(widget.fixture!.description),
            content: SizedBox(
              width: 300,
              height: 200,
              child: RadioGroup<int>(
                groupValue: _selectedOptionIndex,
                onChanged: (value) =>
                    setState(() => _selectedOptionIndex = value),
                child: ListView.builder(
                  shrinkWrap: false,
                  itemCount: widget.fixture!.items.length,
                  itemBuilder: (context, index) {
                    final option = widget.fixture!.items[index];
                    return ListTile(
                      leading: Radio<int>(value: index),
                      title:
                          Text("${option.identifier} - ${option.description}"),
                      onTap: () => setState(() => _selectedOptionIndex = index),
                    );
                  },
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
                    Navigator.pop(
                        context, widget.fixture!.items[_selectedOptionIndex!]);
                  }
                },
                child: const Text('Select'),
              ),
            ],
          );
  }
}
