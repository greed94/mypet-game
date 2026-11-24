import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mypet/game/palette.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/shapes.dart';

void main() {
  test('아기 그림이 없는 모양은 아기 때도 성체 그림을 쓴다', () {
    expect(
      spriteAsset('maltese', PetStage.puppy),
      puppySheets.contains('maltese')
          ? 'sprites/maltese_puppy.png'
          : 'sprites/maltese_adult.png',
    );
    expect(spriteAsset('maltese', PetStage.adult), 'sprites/maltese_adult.png');
  });

  test('모르는 모양 id는 첫 모양으로 돌아간다', () {
    expect(spriteAsset('없는모양', PetStage.adult), 'sprites/papillon_adult.png');
  });

  // 새 모양 그림을 넣을 때 규격(8줄×4칸, 칸마다 입 위치 표시 하나)을 어기면 여기서 걸린다.
  for (final shape in dogShapes) {
    for (final stage in [
      'adult',
      if (puppySheets.contains(shape.id)) 'puppy',
    ]) {
      test('${shape.id}_$stage 시트가 규격에 맞는다', () {
        final petStage = stage == 'puppy' ? PetStage.puppy : PetStage.adult;
        final asset = spriteAsset(shape.id, petStage);
        final expected = shape.id == 'noeul'
            ? 'sprites/papillon_adult.png'
            : 'sprites/${shape.id}_$stage.png';
        expect(asset, expected);
        final file = File('assets/$asset');
        expect(file.existsSync(), isTrue);
        final sheet = img.decodePng(file.readAsBytesSync())!;
        expect([sheet.width, sheet.height], [32 * 4, 32 * 8]);
        final rgba = Uint8List.fromList(
          sheet.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba),
        );
        final anchors = takeMouthAnchors(rgba, sheet.width, 32);
        expect(anchors.length, 32, reason: '칸마다 입 위치 표시가 하나씩');
      });
    }
  }
}
