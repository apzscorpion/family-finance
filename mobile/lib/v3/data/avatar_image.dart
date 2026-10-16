import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Centre-crops [bytes] to a square, scales it to at most [size] px and
/// re-encodes it as JPEG. Returns null when the bytes are not an image.
/// Run through `compute` — decoding is pure Dart and slow on big photos.
Uint8List? squareAvatarJpeg(Uint8List bytes, {int size = 512}) {
  img.Image? raw;
  try {
    raw = img.decodeImage(bytes);
  } catch (_) {
    return null; // some decoders throw on junk instead of returning null
  }
  if (raw == null) return null;
  final src = img.bakeOrientation(raw); // phone photos carry EXIF rotation
  final side = src.width < src.height ? src.width : src.height;
  final square = img.copyResizeCropSquare(src,
      size: side < size ? side : size, interpolation: img.Interpolation.average);
  return img.encodeJpg(square, quality: 82);
}
