import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

/// Razdelnik „ili“ između dve radnje (kanvas: „Tvoje domaćinstvo“ i
/// „Pridruži se domaćinstvu“). Ukras; čitač ekrana ga preskače.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: c.onSurfaceVariant, fontWeight: FontWeight.w600);
    return ExcludeSemantics(
      child: Row(
        spacing: TavliSpacing.small,
        children: [
          const Expanded(child: TavliDivider()),
          Text('ili', style: style),
          const Expanded(child: TavliDivider()),
        ],
      ),
    );
  }
}

/// Zaglavlje potvrde prelaska: kuća u krugu, „Pozvan si u“ i naziv
/// odredišnog domaćinstva (kanvas: „Potvrda prelaska“).
class HouseholdInviteHeader extends StatelessWidget {
  const HouseholdInviteHeader({
    super.key,
    required this.householdName,
    this.caption = 'Pozvan si u',
  });

  final String householdName;

  /// Natpis iznad naziva („Pozvan si u“ ili „Novo domaćinstvo“).
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Row(
      spacing: TavliSpacing.medium,
      children: [
        const TavliAvatar.icon(TavliIcons.home, size: TavliAvatar.prominent),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                caption,
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
              Text(
                householdName,
                style: t.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: c.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Naslov dijaloga sa ikonicom upozorenja iznad (kanvas: „Poslednji
/// član“).
class WarningDialogHeader extends StatelessWidget {
  const WarningDialogHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TavliSpacing.medium,
      children: [
        const TavliAvatar.icon(
          TavliIcons.warning,
          size: TavliAvatar.prominent,
          destructive: true,
        ),
        Text(
          title,
          style: t.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
