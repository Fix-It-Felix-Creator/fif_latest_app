import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../customers/address_search_screen.dart';

/// Outline button that launches the UK postcode search screen
/// ([AddressSearchScreen]) and invokes [onPicked] when the user taps a
/// result. Designed for use at the top of an address form in the auth flow.
class PostcodeSearchButton extends StatelessWidget {
  const PostcodeSearchButton({
    super.key,
    required this.onPicked,
    this.initialQuery,
  });

  final ValueChanged<AddressResult> onPicked;
  final String? initialQuery;

  Future<void> _open(BuildContext context) async {
    final result = await Navigator.of(context).push<AddressResult>(
      MaterialPageRoute(
        builder: (_) => AddressSearchScreen(initialQuery: initialQuery),
      ),
    );
    if (result != null) onPicked(result);
  }

  @override
  Widget build(BuildContext context) {
    return ShadButton.outline(
      width: double.infinity,
      onPressed: () => _open(context),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.search, size: 16),
          SizedBox(width: 8),
          Text('Search by UK postcode'),
        ],
      ),
    );
  }
}
