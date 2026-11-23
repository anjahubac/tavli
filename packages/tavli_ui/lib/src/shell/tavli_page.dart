import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// Sadržaj ekrana koji se pomera, sa razmacima sa platna.
///
/// Telefon: 20 sa strane, 8 gore (ispod gornje trake), 20 dole, 14 između
/// odeljaka. [wide] (računar, tablet): 28 sa strane, 24 gore i dole, 16
/// između odeljaka. [maxWidth] (npr. [TavliWidth.readable]) drži tekst
/// čitljive širine u sredini širokog ekrana.
class TavliPage extends StatelessWidget {
  const TavliPage({
    super.key,
    required this.children,
    this.wide = false,
    this.maxWidth,
  }) : _centered = false;

  /// Jedan element (prazno stanje, greška) u sredini ekrana; pomera se
  /// kada ne staje (mali prozor, krupan tekst).
  TavliPage.centered({super.key, required Widget child})
    : children = [child],
      wide = false,
      maxWidth = null,
      _centered = true;

  final List<Widget> children;
  final bool wide;
  final double? maxWidth;
  final bool _centered;

  @override
  Widget build(BuildContext context) {
    if (_centered) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: children.single),
          ),
        ),
      );
    }
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: wide ? 16 : TavliSpacing.medium,
      children: children,
    );
    final maxWidth = this.maxWidth;
    if (maxWidth != null) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }
    return SingleChildScrollView(
      padding: wide
          ? const EdgeInsets.symmetric(horizontal: 28, vertical: 24)
          : const EdgeInsets.fromLTRB(
              TavliSpacing.large,
              TavliSpacing.small,
              TavliSpacing.large,
              TavliSpacing.large,
            ),
      child: content,
    );
  }
}
