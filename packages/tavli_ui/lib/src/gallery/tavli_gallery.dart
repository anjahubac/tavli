import 'package:material_ui/material_ui.dart';

import '../platform.dart';
import '../theme/tavli_colors.dart';
import '../theme/tavli_motif.dart';
import '../theme/tavli_status_colors.dart';
import '../theme/tavli_theme.dart';
import '../tokens.dart';
import 'gallery_section.dart';
import 'shell_sections.dart';

/// Naziv teme kako ga vidi korisnik.
String tavliMotifLabel(TavliMotif motif) => switch (motif) {
  TavliMotif.bosiljak => 'Bosiljak',
  TavliMotif.safran => 'Šafran',
  TavliMotif.borovnica => 'Borovnica',
};

/// Naziv platforme u galeriji.
String tavliPlatformLabel(TavliPlatform platform) => switch (platform) {
  TavliPlatform.android => 'Android',
  TavliPlatform.ios => 'iOS',
  TavliPlatform.macos => 'macOS',
  TavliPlatform.windows => 'Windows',
};

TargetPlatform _target(TavliPlatform platform) => switch (platform) {
  TavliPlatform.android => TargetPlatform.android,
  TavliPlatform.ios => TargetPlatform.iOS,
  TavliPlatform.macos => TargetPlatform.macOS,
  TavliPlatform.windows => TargetPlatform.windows,
};

/// Veličine teksta koje galerija nudi (1x, 1,5x, 2x).
const tavliGalleryTextScales = [1.0, 1.5, 2.0];

/// Izbor u galeriji: tema, osvetljenost, veličina teksta i platforma.
@immutable
class TavliGallerySettings {
  const TavliGallerySettings({
    this.motif = TavliMotif.bosiljak,
    this.brightness = Brightness.light,
    this.textScale = 1,
    this.platform = TavliPlatform.android,
  });

  final TavliMotif motif;
  final Brightness brightness;
  final double textScale;
  final TavliPlatform platform;

  TavliGallerySettings copyWith({
    TavliMotif? motif,
    Brightness? brightness,
    double? textScale,
    TavliPlatform? platform,
  }) => TavliGallerySettings(
    motif: motif ?? this.motif,
    brightness: brightness ?? this.brightness,
    textScale: textScale ?? this.textScale,
    platform: platform ?? this.platform,
  );

  /// Tema iz paketa sa zadatom (simuliranom) platformom.
  ThemeData get theme =>
      buildTavliTheme(motif, brightness).copyWith(platform: _target(platform));
}

/// Galerija komponenti: prekidači gore, a ispod sve iz biblioteke u
/// izabranoj temi. Aplikacija je prikazuje kao Profil > Komponente (samo u
/// debug verziji).
class TavliGallery extends StatefulWidget {
  const TavliGallery({
    super.key,
    this.initial = const TavliGallerySettings(),
    this.onClose,
  });

  final TavliGallerySettings initial;

  /// Dugme nazad u gornjoj traci; bez njega traka nema dugme.
  final VoidCallback? onClose;

  @override
  State<TavliGallery> createState() => _TavliGalleryState();
}

class _TavliGalleryState extends State<TavliGallery> {
  late TavliGallerySettings _settings = widget.initial;

  void _set(TavliGallerySettings s) => setState(() => _settings = s);

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    return Theme(
      data: s.theme,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Komponente'),
            leading: widget.onClose == null
                ? null
                : BackButton(onPressed: widget.onClose),
            automaticallyImplyLeading: false,
          ),
          body: ListView(
            padding: const EdgeInsets.all(TavliSpacing.large),
            children: [
              _Controls(settings: s, onChanged: _set),
              const SizedBox(height: TavliSpacing.large),
              MediaQuery.withClampedTextScaling(
                minScaleFactor: s.textScale,
                maxScaleFactor: s.textScale,
                child: const TavliGallerySections(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.settings, required this.onChanged});

  final TavliGallerySettings settings;
  final ValueChanged<TavliGallerySettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    Widget group<T>(
      String label,
      Iterable<T> values,
      T selected,
      String Function(T) name,
      TavliGallerySettings Function(T) apply,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: TavliSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: TavliSpacing.small),
          Wrap(
            spacing: TavliSpacing.small,
            runSpacing: TavliSpacing.small,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(name(v)),
                  selected: v == selected,
                  onSelected: (_) => onChanged(apply(v)),
                ),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        group(
          'Tema',
          TavliMotif.values,
          s.motif,
          tavliMotifLabel,
          (v) => s.copyWith(motif: v),
        ),
        group(
          'Osvetljenost',
          Brightness.values,
          s.brightness,
          (v) => v == Brightness.light ? 'Svetlo' : 'Tamno',
          (v) => s.copyWith(brightness: v),
        ),
        group(
          'Veličina teksta',
          tavliGalleryTextScales,
          s.textScale,
          (v) => '${v.toString().replaceAll('.0', '').replaceAll('.', ',')}x',
          (v) => s.copyWith(textScale: v),
        ),
        group(
          'Platforma',
          TavliPlatform.values,
          s.platform,
          tavliPlatformLabel,
          (v) => s.copyWith(platform: v),
        ),
      ],
    );
  }
}

/// Sadržaj galerije bez prekidača: osnova (boje, tekst, mere, tema na
/// Material elementima) i komponente kostura ekrana.
///
/// Svaka nova komponenta iz biblioteke dobija svoj odeljak ovde.
class TavliGallerySections extends StatelessWidget {
  const TavliGallerySections({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [TavliFoundationGallerySections(), TavliShellGallerySections()],
    );
  }
}

/// Osnova biblioteke u galeriji: boje, tekst, mere i tema na Material
/// elementima. Nije deo javnog ulaza; koriste je testovi izgleda.
class TavliFoundationGallerySections extends StatelessWidget {
  const TavliFoundationGallerySections({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GallerySection(title: 'Boje', child: _Colors()),
        GallerySection(title: 'Tekst', child: _Typography()),
        GallerySection(title: 'Razmaci i radijusi', child: _Tokens()),
        GallerySection(
          title: 'Tema na Material elementima',
          child: _Material(),
        ),
      ],
    );
  }
}

class _Colors extends StatelessWidget {
  const _Colors();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final x = TavliColors.of(context);
    final status = TavliStatusColors.of(context);
    final swatches = <(String, Color, Color)>[
      ('Pozadina', x.bg, c.onSurface),
      ('Površina', c.surface, c.onSurface),
      ('Glavna', c.primary, c.onPrimary),
      ('Istaknuto', c.primaryContainer, c.onPrimaryContainer),
      ('Tekst', c.onSurface, c.surface),
      ('Prigušeno', c.onSurfaceVariant, c.surface),
      ('Ivica', x.line, c.onSurface),
      ('Ivica polja', x.boxLine, c.surface),
      ('Greška', c.error, c.onError),
      for (final (i, t) in x.tints.indexed)
        ('Pločica ${i + 1}', t, c.onSurface),
      ('Uspeh', status.success.background, status.success.foreground),
      ('Upozorenje', status.warning.background, status.warning.foreground),
      ('Info', status.info.background, status.info.foreground),
    ];
    return Wrap(
      spacing: TavliSpacing.small,
      runSpacing: TavliSpacing.small,
      children: [
        for (final (name, bg, fg) in swatches)
          Container(
            width: 104,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(TavliSpacing.small),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(TavliRadius.compact),
              border: Border.all(color: x.line),
            ),
            alignment: Alignment.bottomLeft,
            child: Text(
              name,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: fg),
            ),
          ),
      ],
    );
  }
}

class _Typography extends StatelessWidget {
  const _Typography();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final styles = <(String, TextStyle?)>[
      ('Naslov', t.headlineMedium),
      ('Podnaslov', t.titleLarge),
      ('Naslov kartice', t.titleMedium),
      ('Tekst', t.bodyLarge),
      ('Manji tekst', t.bodyMedium),
      ('Oznaka', t.labelLarge),
      ('Sitno', t.labelSmall),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, style) in styles)
          Padding(
            padding: const EdgeInsets.only(bottom: TavliSpacing.small),
            child: Text('$name · Šargarepa i ćufte', style: style),
          ),
      ],
    );
  }
}

class _Tokens extends StatelessWidget {
  const _Tokens();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final label = Theme.of(context).textTheme.labelMedium;
    const spacing = [
      ('mali', TavliSpacing.small),
      ('srednji', TavliSpacing.medium),
      ('veliki', TavliSpacing.large),
    ];
    const radius = [
      ('štikliranje', TavliRadius.checkbox),
      ('čip', TavliRadius.chip),
      ('kompaktno', TavliRadius.compact),
      ('polje', TavliRadius.field),
      ('dugme', TavliRadius.button),
      ('kartica', TavliRadius.card),
      ('list', TavliRadius.sheet),
    ];
    String n(double v) => v.toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, v) in spacing)
          Padding(
            padding: const EdgeInsets.only(bottom: TavliSpacing.small),
            child: Row(
              children: [
                Container(width: v * 4, height: 12, color: c.primary),
                const SizedBox(width: TavliSpacing.small),
                Flexible(child: Text('Razmak $name · ${n(v)}', style: label)),
              ],
            ),
          ),
        const SizedBox(height: TavliSpacing.small),
        Wrap(
          spacing: TavliSpacing.small,
          runSpacing: TavliSpacing.small,
          children: [
            for (final (name, v) in radius)
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      borderRadius: BorderRadius.circular(v),
                    ),
                  ),
                  Text('$name ${n(v)}', style: label),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _Material extends StatelessWidget {
  const _Material();

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: TavliSpacing.medium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: TavliSpacing.small,
          runSpacing: TavliSpacing.small,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Sačuvaj')),
            OutlinedButton(onPressed: () {}, child: const Text('Otkaži')),
            TextButton(onPressed: () {}, child: const Text('Preskoči')),
            const FilledButton(onPressed: null, child: Text('Isključeno')),
          ],
        ),
        gap,
        const TextField(
          decoration: InputDecoration(
            labelText: 'Naziv recepta',
            hintText: 'npr. Sarma',
          ),
        ),
        gap,
        const TextField(
          decoration: InputDecoration(
            labelText: 'Količina',
            errorText: 'Unesi broj',
          ),
        ),
        gap,
        Wrap(
          spacing: TavliSpacing.small,
          runSpacing: TavliSpacing.small,
          children: [
            FilterChip(
              label: const Text('Nedelja 1'),
              selected: true,
              onSelected: (_) {},
            ),
            FilterChip(label: const Text('Ceo plan'), onSelected: (_) {}),
          ],
        ),
        gap,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(TavliSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ručak', style: Theme.of(context).textTheme.labelLarge),
                Text(
                  'Pasulj sa kobasicom',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        gap,
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Checkbox(value: true, onChanged: (_) {}),
            Checkbox(value: false, onChanged: (_) {}),
            Switch(value: true, onChanged: (_) {}),
            Switch(value: false, onChanged: (_) {}),
          ],
        ),
      ],
    );
  }
}
