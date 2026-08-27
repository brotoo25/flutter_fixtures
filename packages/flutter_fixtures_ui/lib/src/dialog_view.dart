import 'package:flutter/material.dart';
import 'package:flutter_fixtures_core/flutter_fixtures_core.dart';

/// A dialog-based implementation of DataSelectorView
///
/// This class provides a dialog UI for users to select a fixture from a collection.
class FixturesDialogView extends StatefulWidget implements DataSelectorView {
  static final Map<_DialogRequestKey, Future<FixtureDocument?>>
      _pendingRequests = {};

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
    final navigator = Navigator.of(context, rootNavigator: true);
    final requestKey = _DialogRequestKey(
      navigator: navigator,
      fixtureSignature: _fixtureSignature(fixture),
    );

    final pendingRequest = _pendingRequests[requestKey];
    if (pendingRequest != null) {
      return pendingRequest;
    }

    late final Future<FixtureDocument?> dialogFuture;
    dialogFuture = showDialog<FixtureDocument>(
      context: context,
      builder: (BuildContext context) {
        return FixturesDialogView(
          context: context,
          fixture: fixture,
        );
      },
    ).whenComplete(() {
      final currentRequest = _pendingRequests[requestKey];
      if (identical(currentRequest, dialogFuture)) {
        _pendingRequests.remove(requestKey);
      }
    });

    _pendingRequests[requestKey] = dialogFuture;
    return dialogFuture;
  }

  static String _fixtureSignature(FixtureCollection fixture) {
    final signature = StringBuffer(fixture.description);
    for (final item in fixture.items) {
      signature
        ..write('|')
        ..write(item.identifier)
        ..write('|')
        ..write(item.description)
        ..write('|')
        ..write(item.defaultOption ?? false)
        ..write('|')
        ..write(item.dataPath ?? '');
    }
    return signature.toString();
  }
}

class _DialogRequestKey {
  final NavigatorState navigator;
  final String fixtureSignature;

  const _DialogRequestKey({
    required this.navigator,
    required this.fixtureSignature,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is _DialogRequestKey &&
        identical(other.navigator, navigator) &&
        other.fixtureSignature == fixtureSignature;
  }

  @override
  int get hashCode => Object.hash(
        identityHashCode(navigator),
        fixtureSignature,
      );
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
