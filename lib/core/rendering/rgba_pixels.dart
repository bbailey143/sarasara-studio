import 'dart:typed_data';

/// Convert straight-alpha RGBA8 pixels to the premultiplied RGBA8 layout that
/// Flutter's `PixelFormat.rgba8888` raw-image decoder requires.
///
/// Simulations keep straight RGB so tests and color math remain readable. Call
/// this only on the disposable buffer that is about to cross the Flutter image
/// boundary.
void premultiplyRgba8888(Uint8List pixels) {
  if (pixels.lengthInBytes % 4 != 0) {
    throw ArgumentError(
      'RGBA8 buffers must contain complete four-byte pixels.',
    );
  }
  for (var offset = 0; offset < pixels.lengthInBytes; offset += 4) {
    final alpha = pixels[offset + 3];
    if (alpha == 255) continue;
    if (alpha == 0) {
      pixels[offset] = 0;
      pixels[offset + 1] = 0;
      pixels[offset + 2] = 0;
      continue;
    }
    pixels[offset] = (pixels[offset] * alpha + 127) ~/ 255;
    pixels[offset + 1] = (pixels[offset + 1] * alpha + 127) ~/ 255;
    pixels[offset + 2] = (pixels[offset + 2] * alpha + 127) ~/ 255;
  }
}
