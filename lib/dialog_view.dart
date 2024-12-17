import 'package:flutter/material.dart';
import 'package:flutter_fixtures/fixture.dart';

class FixturesDialogView extends StatefulWidget implements DataSelectorView {
  final BuildContext context;
  final FixtureCollection? fixture;

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
              child: ListView.builder(
                shrinkWrap: false,
                itemCount: widget.fixture!.items.length,
                itemBuilder: (context, index) {
                  final option = widget.fixture!.items[index];
                  return RadioListTile<int>(
                    title: Text("${option.identifier} - ${option.description}"),
                    value: index,
                    groupValue: _selectedOptionIndex,
                    onChanged: (value) =>
                        setState(() => _selectedOptionIndex = value),
                  );
                },
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
