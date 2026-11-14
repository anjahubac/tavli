import 'package:material_ui/material_ui.dart';

/// Značenje statusa ostaje isto u svakoj korisničkoj paleti.
typedef StatusTone = ({Color foreground, Color background});

class TavliStatusColors extends ThemeExtension<TavliStatusColors> {
  const TavliStatusColors({
    required this.success,
    required this.warning,
    required this.info,
  });

  static const light = TavliStatusColors(
    success: (foreground: Color(0xFF245C38), background: Color(0xFFE5F3E9)),
    warning: (foreground: Color(0xFF714900), background: Color(0xFFFFF0CD)),
    info: (foreground: Color(0xFF244F78), background: Color(0xFFE5F0FA)),
  );
  static const dark = TavliStatusColors(
    success: (foreground: Color(0xFFA7DEB6), background: Color(0xFF193B26)),
    warning: (foreground: Color(0xFFFFD98A), background: Color(0xFF49340C)),
    info: (foreground: Color(0xFFB1D7FB), background: Color(0xFF193750)),
  );

  final StatusTone success;
  final StatusTone warning;
  final StatusTone info;

  static TavliStatusColors of(BuildContext context) =>
      Theme.of(context).extension<TavliStatusColors>()!;

  @override
  TavliStatusColors copyWith({
    StatusTone? success,
    StatusTone? warning,
    StatusTone? info,
  }) => TavliStatusColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    info: info ?? this.info,
  );

  @override
  TavliStatusColors lerp(TavliStatusColors? other, double t) {
    if (other == null) return this;
    StatusTone mix(StatusTone a, StatusTone b) => (
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
      background: Color.lerp(a.background, b.background, t)!,
    );
    return TavliStatusColors(
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      info: mix(info, other.info),
    );
  }
}
