import 'package:material_ui/material_ui.dart';

/// Miran, kontekstualni prikaz prazne nabavke.
class EmptyBasket extends StatelessWidget {
  const EmptyBasket({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Prazna korpa za nabavku',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: 144,
          height: 144,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.shopping_basket_outlined,
            size: 72,
            color: colors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
