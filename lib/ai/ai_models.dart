import 'dart:convert';
import 'dart:typed_data';

/// AI provajderi koji govore OpenAI-kompatibilan API.
enum AIProvider {
  gemini('Gemini', 'https://generativelanguage.googleapis.com/v1beta/openai/'),
  groq('Groq', 'https://api.groq.com/openai/v1/'),
  openRouter('OpenRouter', 'https://openrouter.ai/api/v1/');

  const AIProvider(this.label, this.baseUrl);

  final String label;
  final String baseUrl;
}

/// Vrsta zadatka određuje koji lanac modela se koristi.
enum TaskKind { vision, text }

class ModelSpec {
  const ModelSpec({
    required this.provider,
    required this.model,
    required this.label,
    this.supportsVision = false,
    this.enabled = true,
    this.dailyResetUtcHour,
  });

  final AIProvider provider;
  final String model;
  final String label;
  final bool supportsVision;
  final bool enabled;

  /// Sat (UTC) kada se dnevni limit resetuje. Null znači da provajder
  /// to ne objavljuje, pa se koristi Retry-After ili podrazumevana pauza.
  final int? dailyResetUtcHour;

  String get key => '${provider.name}/$model';

  ModelSpec copyWith({bool? enabled}) => ModelSpec(
    provider: provider,
    model: model,
    label: label,
    supportsVision: supportsVision,
    enabled: enabled ?? this.enabled,
    dailyResetUtcHour: dailyResetUtcHour,
  );

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'model': model,
    'label': label,
    'supportsVision': supportsVision,
    'enabled': enabled,
    'dailyResetUtcHour': dailyResetUtcHour,
  };

  factory ModelSpec.fromJson(Map<String, dynamic> json) => ModelSpec(
    provider: AIProvider.values.byName(json['provider'] as String),
    model: json['model'] as String,
    label: json['label'] as String,
    supportsVision: json['supportsVision'] as bool? ?? false,
    enabled: json['enabled'] as bool? ?? true,
    dailyResetUtcHour: json['dailyResetUtcHour'] as int?,
  );

  @override
  String toString() => key;
}

class AIImage {
  const AIImage(this.bytes, {this.mimeType = 'image/jpeg'});

  final Uint8List bytes;
  final String mimeType;

  String toDataUrl() => 'data:$mimeType;base64,${base64Encode(bytes)}';
}

/// Jedan zahtev ka AI-ju. Odgovor je uvek JSON objekat.
class AIRequest {
  const AIRequest({
    required this.system,
    required this.prompt,
    this.images = const [],
    this.temperature = 0.4,
  });

  final String system;
  final String prompt;
  final List<AIImage> images;
  final double temperature;

  TaskKind get kind => images.isEmpty ? TaskKind.text : TaskKind.vision;
}
