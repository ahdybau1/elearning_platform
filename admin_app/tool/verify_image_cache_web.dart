import 'package:admin_app/core/engines/image_generation_engine.dart';

// dart compile js tool/verify_image_cache_web.dart -o .dart_tool/cache_probe.js
// node .dart_tool/cache_probe.js
void main() {
  const request = ImageGenerationRequest(
    prompt: 'Suite géométrique',
    subject: 'Mathématiques',
  );
  if (request.computeCacheHash() != '36700523a3da4288') {
    throw StateError('FNV-1a mismatch on JavaScript');
  }
  // CLI verification output, not application logging.
  // ignore: avoid_print
  print('PASS: FNV-1a is identical on JavaScript and Dart VM');
}
