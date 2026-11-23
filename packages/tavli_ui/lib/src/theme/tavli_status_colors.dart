import 'package:material_ui/material_ui.dart';

/// Značenje statusa ostaje isto u svakoj korisničkoj paleti.
typedef StatusTone = ({Color foreground, Color background});

class TavliStatusColors extends ThemeExtension<TavliStatusColors> {
  const TavliStatusColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.dislike,
  });

  static const light = TavliStatusColors(
    success: (foreground: Color(0xFF245C38), background: Color(0xFFE5F3E9)),
    warning: (foreground: Color(0xFF714900), background: Color(0xFFFFF0CD)),
    info: (foreground: Color(0xFF244F78), background: Color(0xFFE5F0FA)),
    dislike: (foreground: Color(0xFF7A3214), background: Color(0xFFF8E8E0)),
  );
  static const dark = TavliStatusColors(
    success: (foreground: Color(0xFFA7DEB6), background: Color(0xFF193B26)),
    warning: (foreground: Color(0xFFFFD98A), background: Color(0xFF49340C)),
    info: (foreground: Color(0xFFB1D7FB), background: Color(0xFF193750)),
    dislike: (foreground: Color(0xFFFFC2A8), background: Color(0xFF4A2618)),
  );

  final StatusTone success;
  final StatusTone warning;
  final StatusTone info;

  /// „Ne volim“ u ukusima (terakota sa platna): ista u svakoj paleti, da se
  /// ne pomeša sa bojom teme za „Volim“.
  final StatusTone dislike;

  static TavliStatusColors of(BuildContext context) =>
      Theme.of(context).extension<TavliStatusColors>()!;

  @override
  TavliStatusColors copyWith({
    StatusTone? success,
    StatusTone? warning,
    StatusTone? info,
    StatusTone? dislike,
  }) => TavliStatusColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    info: info ?? this.info,
    dislike: dislike ?? this.dislike,
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
      dislike: mix(dislike, other.dislike),
    );
  }
}
