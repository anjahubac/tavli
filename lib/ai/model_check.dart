import 'ai_models.dart';
import 'chain_config.dart';

class ModelAvailability {
  const ModelAvailability(this.spec, {required this.listed});

  final ModelSpec spec;

  /// Da li je model na listi koju je provajder vratio za ovaj ključ.
  final bool listed;
}

/// Upoređuje modele iz lanca sa listom koju vraća `/models`.
/// Gemini vraća id-jeve sa prefiksom "models/".
List<ModelAvailability> checkChainModels(
  ChainConfig config,
  AIProvider provider,
  Iterable<String> listedIds,
) {
  final ids = {
    for (final id in listedIds)
      id.startsWith('models/') ? id.substring('models/'.length) : id,
  };
  final specs = <String, ModelSpec>{
    for (final m in [...config.vision, ...config.text])
      if (m.provider == provider) m.key: m,
  };
  return [
    for (final s in specs.values)
      ModelAvailability(s, listed: ids.contains(s.model)),
  ];
}
