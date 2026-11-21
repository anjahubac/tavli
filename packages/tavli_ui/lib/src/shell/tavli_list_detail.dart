import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// Lista i detalj na širokom ekranu (Nabavka: lista stavki levo, „Za koje
/// obroke“ desno). Lista dobija ostatak širine; detalj je najviše
/// [TavliWidth.detail] i najviše trećina širine, a pomera se sam kada je
/// viši od prostora.
///
/// Ekran ga koristi tek kada je sadržaj širok bar [TavliWidth.listDetail];
/// uže od toga detalj se otvara kao donji list.
class TavliListDetail extends StatelessWidget {
  const TavliListDetail({super.key, required this.list, required this.detail});

  final Widget list;
  final Widget detail;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final third = constraints.maxWidth / 3;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TavliSpacing.large,
        children: [
          Expanded(child: list),
          SizedBox(
            width: third < TavliWidth.detail ? third : TavliWidth.detail,
            child: SingleChildScrollView(child: detail),
          ),
        ],
      );
    },
  );
}
