import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tavli_ui/tavli_ui.dart';

import '../../account/household_invite_code.dart';

/// Kod iz QR-a: sam kod, `tavli://household/join#KOD` ili HTTPS link sa
/// kodom u fragmentu. Sve drugo se zanemaruje.
HouseholdInviteCode? householdCodeFromScan(String raw) {
  final text = raw.trim();
  if (HouseholdInviteCode.parse(text) case final code?) return code;
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  return HouseholdInviteCode.fromAppLink(uri) ??
      (uri.scheme == 'https' ? HouseholdInviteCode.parse(uri.fragment) : null);
}

/// „Skeniraj QR kod“ (kanvas): kamera u okviru, kod se čita sam. Vraća
/// prepoznat kod, ili `null` za „Unesi kod“ i zatvaranje.
class HouseholdScanScreen extends StatefulWidget {
  const HouseholdScanScreen({super.key});

  @override
  State<HouseholdScanScreen> createState() => _HouseholdScanScreenState();
}

class _HouseholdScanScreenState extends State<HouseholdScanScreen> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  var _done = false;

  @override
  void dispose() {
    unawaited(_camera.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = householdCodeFromScan(barcode.rawValue ?? '');
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(TavliSpacing.small),
              child: Row(
                spacing: TavliSpacing.small,
                children: [
                  TavliIconButton(
                    glyph: TavliIcons.close,
                    semanticLabel: 'Zatvori',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Skeniraj QR kod',
                        style: t.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(TavliSpacing.large),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: TavliSpacing.large,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: TavliWidth.message,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _Viewfinder(
                            child: MobileScanner(
                              controller: _camera,
                              onDetect: _onDetect,
                              errorBuilder: (context, error) =>
                                  const _CameraUnavailable(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Column(
                      spacing: TavliSpacing.small,
                      children: [
                        Text(
                          'Postavi QR kod u okvir',
                          textAlign: TextAlign.center,
                          style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: c.onSurface,
                          ),
                        ),
                        Text(
                          'Kod se čita sam, ne moraš ništa da pritiskaš.',
                          textAlign: TextAlign.center,
                          style: t.bodyMedium?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TavliSpacing.large),
              child: TavliButtonRow(
                expand: true,
                children: [
                  TavliButton.secondary(
                    label: 'Svetlo',
                    glyph: TavliIcons.flash,
                    onPressed: _camera.toggleTorch,
                  ),
                  TavliButton.secondary(
                    label: 'Unesi kod',
                    glyph: TavliIcons.edit,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kamera u zaobljenom okviru sa uglovima u boji teme.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return CustomPaint(
      foregroundPainter: _CornerPainter(c.primary),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TavliRadius.card),
        child: ColoredBox(color: c.inverseSurface, child: child),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.color);

  final Color color;

  // Kanvas: ugao 44 sa linijom 5, zaobljen kao kartica.
  static const _length = 44.0;
  static const _stroke = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    const r = TavliRadius.card;
    final w = size.width, h = size.height;
    for (final (x, y, sx, sy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(x, y + sy * _length)
        ..lineTo(x, y + sy * r)
        ..arcToPoint(
          Offset(x + sx * r, y),
          radius: const Radius.circular(r),
          clockwise: sx * sy > 0,
        )
        ..lineTo(x + sx * _length, y);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TavliSpacing.large),
        child: Text(
          'Kamera nije dostupna. Dozvoli pristup kameri u podešavanjima '
          'telefona ili unesi kod.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: c.onInverseSurface),
        ),
      ),
    );
  }
}
