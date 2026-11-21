import 'package:material_ui/material_ui.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../app/home_shell.dart' show wideLayoutWidth;

/// Širok ekran (bočna navigacija): zaglavlje „Nabavka“ umesto gornje trake.
bool isWideShopping(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideLayoutWidth;

/// „Prebaci u ostavu (n)“: koliko kupljenih stavki čeka ostavu i radnja.
typedef PantryAction = ({int count, VoidCallback onPressed});

/// Raspored Nabavke po platnu.
///
/// Telefon: izbor „Po planu“ i „Po receptu“ u sredini, filteri, lista koja se
/// pomera i zakucana traka „Prebaci u ostavu (n)“ iznad navigacije.
///
/// Računar: zaglavlje „Nabavka“ sa izborom desno, filteri levo i „Prebaci u
/// ostavu (n)“ desno u istom redu, pa lista i, kada ima mesta, detalj
/// izabrane stavke („Za koje obroke“) desno.
///
/// Sadržaj je ili lista ([children], pomera se) ili jedan element koji
/// popunjava prostor ([body], npr. učitavanje ili prazno stanje).
class ShoppingFrame extends StatelessWidget {
  const ShoppingFrame({
    super.key,
    required this.mode,
    this.filters = const [],
    this.children,
    this.body,
    this.pantry,
    this.detail,
  }) : assert((children == null) != (body == null), 'lista ili telo');

  /// Izbor „Po planu“ i „Po receptu“.
  final Widget mode;

  /// Izbor plana, čipovi nedelja i opseg datuma.
  final List<Widget> filters;
  final List<Widget>? children;
  final Widget? body;
  final PantryAction? pantry;

  /// Detalj izabrane stavke; prikazuje se samo na širokom ekranu.
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final wide = isWideShopping(context);
    final pantry = this.pantry;
    final pantryButton = pantry == null
        ? null
        : TavliButton.primary(
            label: 'Prebaci u ostavu (${pantry.count})',
            glyph: TavliIcons.pantry,
            onPressed: pantry.onPressed,
          );

    if (!wide) {
      final header = Padding(
        padding: const EdgeInsets.fromLTRB(
          TavliSpacing.large,
          TavliSpacing.small,
          TavliSpacing.large,
          TavliSpacing.medium,
        ),
        child: Center(child: mode),
      );
      // Izbor ostaje gore; filteri se pomeraju sa listom.
      final filtered = [
        for (final f in filters) ...[
          f,
          const SizedBox(height: TavliSpacing.medium),
        ],
      ];
      // Traka je dno sopstvenog Scaffold-a sa sopstvenim prikazom poruka,
      // pa kratka poruka („Kupljeno: …“, „Poništi“) iskače iznad trake i
      // ne pokriva „Prebaci u ostavu“.
      return ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          bottomNavigationBar: pantryButton == null
              ? null
              : TavliActionBar(actions: [pantryButton]),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                // Učitavanje i greška na telefonu: bez filtera, da veliki
                // tekst na niskom ekranu ne gura sadržaj van ekrana.
                child: children == null
                    ? body!
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TavliSpacing.large,
                        ),
                        children: [
                          ...filtered,
                          ...children!,
                          const SizedBox(height: TavliSpacing.large),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    }

    final detail = this.detail;
    final content = children == null
        ? body!
        : ListView(
            children: [
              ...children!,
              const SizedBox(height: TavliSpacing.large),
            ],
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TavliSpacing.large,
        TavliSpacing.large,
        TavliSpacing.large,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TavliPageHeader(title: 'Nabavka', actions: [mode]),
          const SizedBox(height: TavliSpacing.medium),
          if (filters.isNotEmpty || pantryButton != null) ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TavliSpacing.medium,
              runSpacing: TavliSpacing.medium,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: TavliSpacing.small,
                  children: filters,
                ),
                ?pantryButton,
              ],
            ),
            const SizedBox(height: TavliSpacing.medium),
          ],
          Expanded(
            child: detail == null
                ? content
                : TavliListDetail(list: content, detail: detail),
          ),
        ],
      ),
    );
  }
}

/// Da li lista na širokom ekranu ima mesta za detalj desno.
bool hasShoppingDetail(BuildContext context, BoxConstraints constraints) =>
    isWideShopping(context) && constraints.maxWidth >= TavliWidth.listDetail;
