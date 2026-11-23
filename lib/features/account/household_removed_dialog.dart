import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/auth_controller.dart';

/// Obaveštenje posle uklanjanja iz domaćinstva: aplikacija je već prešla
/// na novo lično domaćinstvo, pa dijalog samo objašnjava šta se desilo.
Future<void> showHouseholdRemovedDialog(
  BuildContext context,
  HouseholdRemovalNotice notice,
) => showTavliDialog<void>(
  context,
  title: 'Više nisi u domaćinstvu „${notice.previousHouseholdName}“',
  message:
      'Vlasnik te je uklonio iz domaćinstva. Sada si u svom domaćinstvu '
      '„${notice.currentHouseholdName}“. Plan, nabavka, ostava i recepti '
      'starog domaćinstva ostaju tamo.',
  actions: const [TavliDialogAction('U redu', null, isDefault: true)],
);
