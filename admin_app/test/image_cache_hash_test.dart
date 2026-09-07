import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/engines/image_generation_engine.dart';

void main() {
  test('Cache hash preserves all 64 bits with UTF-8 input', () {
    const request = ImageGenerationRequest(prompt: 'Suite géométrique', subject: 'Mathématiques');
    // Independent reference computed with Node BigInt.asUintN(64, ...).
    expect(request.computeCacheHash(), '36700523a3da4288');
    expect(request.computeCacheHash(), matches(RegExp(r'^[0-9a-f]{16}$')));
  });
  test('Changing the requested image format changes its cache key', () {
    const webp = ImageGenerationRequest(prompt: 'Suite géométrique', subject: 'Mathématiques');
    const png = ImageGenerationRequest(prompt: 'Suite géométrique', subject: 'Mathématiques', format: 'png');
    expect(webp.computeCacheHash(), isNot(png.computeCacheHash()));
  });
}
