import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:family_finance/v3/data/avatar_image.dart';
import 'package:family_finance/v3/data/v3_models.dart';

void main() {
  group('squareAvatarJpeg', () {
    test('centre-crops a wide photo to a 512px square JPEG', () {
      final wide = img.Image(width: 1200, height: 800);
      final out = squareAvatarJpeg(Uint8List.fromList(img.encodePng(wide)))!;
      final back = img.decodeJpg(out)!;
      expect(back.width, 512);
      expect(back.height, 512);
    });

    test('never upscales a small photo', () {
      final small = img.Image(width: 300, height: 200);
      final back = img.decodeJpg(
          squareAvatarJpeg(Uint8List.fromList(img.encodePng(small)))!)!;
      expect(back.width, 200);
      expect(back.height, 200);
    });

    test('returns null for bytes that are not an image', () {
      expect(squareAvatarJpeg(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });

  group('MemberRow photo and about', () {
    test('reads avatar and about from the joined profile', () {
      final m = MemberRow.fromJson({
        'user_id': 'u1',
        'profiles': {
          'full_name': 'Asif',
          'avatar_path': 'u1/avatar.jpg',
          'avatar_updated_at': '2026-10-16T10:00:00Z',
          'about': '  Saving for Hajj ',
        },
      });
      expect(m.about, 'Saving for Hajj');
      expect(m.avatarPath, 'u1/avatar.jpg');
      expect(
          m.avatarUrl,
          endsWith('/storage/v1/object/public/avatars/u1/avatar.jpg'
              '?v=${DateTime.utc(2026, 10, 16, 10).millisecondsSinceEpoch}'));
    });

    test('old select without the new columns still works', () {
      final m = MemberRow.fromJson({
        'user_id': 'u2',
        'profiles': {'full_name': 'Sinu', 'upi_id': null, 'about': ''},
      });
      expect(m.name, 'Sinu');
      expect(m.about, isNull);
      expect(m.avatarUrl, isNull);
    });
  });
}
