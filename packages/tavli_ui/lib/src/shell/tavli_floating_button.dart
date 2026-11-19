import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// Plutajuće dugme sa ikonicom i tekstom („Dodaj recept“, „Dodaj
/// namirnicu“): na telefonu dole desno, iznad navigacije.
///
/// Visina 56, radijus 20, tekst 15 podebljan, istaknuta boja teme.
/// Stavlja se u `Scaffold.floatingActionButton`. Na računaru ista akcija je
/// dugme u `TavliPageHeader`.
class TavliFloatingButton extends StatelessWidget {
  const TavliFloatingButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(TavliRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.18),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: c.primaryContainer,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: c.onPrimaryContainer),
                  const SizedBox(width: TavliSpacing.small),
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
