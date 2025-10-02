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
  bool _remember = false;

  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    if (widget.fixture != null) {
      final idx =
          widget.fixture!.items.indexWhere((e) => e.defaultOption == true);
      _selectedOptionIndex = idx >= 0 ? idx : 0;
    } else {
      _selectedOptionIndex = 0;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.fixture == null
        ? const SizedBox.shrink()
        : AlertDialog(
            title: Text(widget.fixture!.description),
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
                            itemCount: widget.fixture!.items.length,
                            itemBuilder: (context, index) {
                              final option = widget.fixture!.items[index];
                              return ListTile(
                                leading: Radio<int>(value: index),
                                title: Text(
                                    "${option.identifier} - ${option.description}"),
                                onTap: () => setState(
                                    () => _selectedOptionIndex = index),
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
                    final selected =
                        widget.fixture!.items[_selectedOptionIndex!];
                    if (_remember) {
                      FixtureSelectionMemory.remember(
                          widget.fixture!, selected);
                    }
                    Navigator.pop(context, selected);
                  }
                },
                child: const Text('Select'),
              ),
            ],
          );
  }
}
