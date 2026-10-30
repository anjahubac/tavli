import 'ai_models.dart';

/// Redosled modela po jačini. Korisnik ga menja u podešavanjima;
/// ovde su samo početne vrednosti.
class ChainConfig {
  const ChainConfig({required this.vision, required this.text});

  final List<ModelSpec> vision;
  final List<ModelSpec> text;

  List<ModelSpec> chainFor(TaskKind kind) => switch (kind) {
    TaskKind.vision =>
      vision.where((m) => m.enabled && m.supportsVision).toList(),
    TaskKind.text => text.where((m) => m.enabled).toList(),
  };

  Map<String, dynamic> toJson() => {
    'vision': [for (final m in vision) m.toJson()],
    'text': [for (final m in text) m.toJson()],
  };

  factory ChainConfig.fromJson(Map<String, dynamic> json) => ChainConfig(
    vision: [
      for (final m in json['vision'] as List)
        ModelSpec.fromJson(m as Map<String, dynamic>),
    ],
    text: [
      for (final m in json['text'] as List)
        ModelSpec.fromJson(m as Map<String, dynamic>),
    ],
  );

  // Nazivi modela se često menjaju. Gemini "-latest" alijasi uvek pokazuju
  // na najnoviju verziju; model koji ne postoji router preskače (404).
  // Gemini dnevni limit se resetuje u ponoć po pacifičkom vremenu (08:00 UTC
  // zimi, 07:00 leti) pa uzimamo 08:00 kao sigurniju vrednost.
  static const _geminiPro = ModelSpec(
    provider: AIProvider.gemini,
    model: 'gemini-pro-latest',
    label: 'Gemini Pro',
    supportsVision: true,
    dailyResetUtcHour: 8,
    timeout: Duration(seconds: 60),
  );
  static const _geminiFlash = ModelSpec(
    provider: AIProvider.gemini,
    model: 'gemini-flash-latest',
    label: 'Gemini Flash',
    supportsVision: true,
    dailyResetUtcHour: 8,
  );
  static const _geminiFlashLite = ModelSpec(
    provider: AIProvider.gemini,
    model: 'gemini-flash-lite-latest',
    label: 'Gemini Flash-Lite',
    supportsVision: true,
    dailyResetUtcHour: 8,
  );
  static const _groqVision = ModelSpec(
    provider: AIProvider.groq,
    model: 'meta-llama/llama-4-maverick-17b-128e-instruct',
    label: 'Groq Llama 4 Maverick',
    supportsVision: true,
  );
  static const _groqTextStrong = ModelSpec(
    provider: AIProvider.groq,
    model: 'openai/gpt-oss-120b',
    label: 'Groq GPT-OSS 120B',
  );
  static const _groqTextNext = ModelSpec(
    provider: AIProvider.groq,
    model: 'llama-3.3-70b-versatile',
    label: 'Groq Llama 3.3 70B',
  );
  static const _openRouterFree = ModelSpec(
    provider: AIProvider.openRouter,
    model: 'google/gemma-3-27b-it:free',
    label: 'OpenRouter Gemma 3 (free)',
    supportsVision: true,
  );

  static const defaults = ChainConfig(
    // Za čitanje recepta sa slike Flash je dovoljno dobar i višestruko brži
    // od Pro modela, koji pre odgovora dugo "razmišlja".
    vision: [
      _geminiFlash,
      _groqVision,
      _geminiPro,
      _geminiFlashLite,
      _openRouterFree,
    ],
    text: [
      _geminiPro,
      _groqTextStrong,
      _geminiFlash,
      _groqTextNext,
      _geminiFlashLite,
      _openRouterFree,
    ],
  );
}
