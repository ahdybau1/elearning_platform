import 'dart:convert';

enum ImageStyleType {
  realisticPhoto,
  scientificDiagram,
  historicalIllustration,
  anatomicalIllustration,
  technicalBlueprint,
  modernFlatPedagogical,
}

enum ImageAspectRatio { square1x1, landscape16x9, standard4x3, portrait9x16 }

class ImageGenerationRequest {
  final String prompt;
  final String subject;
  final String? classLevel;
  final String? chapterTitle;
  final ImageStyleType style;
  final ImageAspectRatio aspectRatio;
  final String model;
  final String format; // 'webp', 'png', 'jpeg'

  const ImageGenerationRequest({
    required this.prompt,
    required this.subject,
    this.classLevel,
    this.chapterTitle,
    this.style = ImageStyleType.scientificDiagram,
    this.aspectRatio = ImageAspectRatio.landscape16x9,
    this.model = 'imagen-3.0-generate-002',
    this.format = 'webp',
  });

  /// Calcule un hash unique déterministe pour le cache intelligent (FNV-1a 64-bit)
  String computeCacheHash() {
    final raw =
        '$prompt|$subject|${classLevel ?? ''}|${style.name}|${aspectRatio.name}|$model|$format';
    final bytes = utf8.encode(raw);
    // BigInt conserve les 64 bits sur Dart VM comme sur JavaScript.
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final b in bytes) {
      hash ^= BigInt.from(b);
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Enrichit le prompt avec le contexte pédagogique et la discipline
  String buildEnrichedPrompt() {
    final styleDesc = switch (style) {
      ImageStyleType.scientificDiagram =>
        'Precise, clean high-resolution scientific educational diagram with clear annotations, no clutter',
      ImageStyleType.realisticPhoto =>
        'Realistic, authentic educational high-quality photograph for school textbook',
      ImageStyleType.historicalIllustration =>
        'Accurate, high-quality historical textbook illustration with period details',
      ImageStyleType.anatomicalIllustration =>
        'Accurate biological medical educational illustration with natural colors and structure',
      ImageStyleType.technicalBlueprint =>
        'Clean vector technical blueprint schema with engineering components',
      ImageStyleType.modernFlatPedagogical =>
        'Modern crisp pedagogical vector graphic with accessible harmonious palette',
    };

    return '$prompt. Subject: $subject. Educational context: for school curriculum. Style instructions: $styleDesc. High educational value, strictly appropriate for students.';
  }
}

class GeneratedImageResult {
  final String id;
  final String cacheHash;
  final String imageUrl;
  final String prompt;
  final String style;
  final String format;
  final bool fromCache;
  final DateTime createdAt;

  const GeneratedImageResult({
    required this.id,
    required this.cacheHash,
    required this.imageUrl,
    required this.prompt,
    required this.style,
    this.format = 'webp',
    this.fromCache = false,
    required this.createdAt,
  });
}

/// Moteur de Génération et de Mise en Cache d'Illustrations Pédagogiques IA
class ImageGenerationEngine {
  ImageGenerationEngine._();

  // Cache mémoire local indexé par FNV-1a 64 bits.
  static final Map<String, GeneratedImageResult> _cache = {};

  /// Vérifie si une image avec les mêmes paramètres a déjà été produite
  static GeneratedImageResult? checkCache(ImageGenerationRequest req) {
    final hash = req.computeCacheHash();
    return _cache[hash];
  }

  /// Aucun fournisseur de génération n'est raccordé dans cette application.
  /// Ne jamais présenter une photo prédéfinie comme un résultat généré.
  static Future<GeneratedImageResult> generate(
    ImageGenerationRequest req,
  ) async {
    throw UnsupportedError(
      'Génération d’images IA non raccordée. Utilisez la médiathèque.',
    );
  }
}
