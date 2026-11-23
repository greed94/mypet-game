import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mypet/services/gallery_photo.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('mypet-synthetic-photo-qa-');
  });
  tearDown(() async => root.delete(recursive: true));
  Future<File> make(String relative) async {
    final file = File('${root.path}/$relative');
    await file.parent.create(recursive: true);
    return file.writeAsString('synthetic');
  }

  test('선택 직후 캐시 사본이 사라지면 새 사진을 고를 수 있는 빈 결과로 돌아온다', () async {
    final missing = File('${root.path}/missing-image.jpg');
    expect(await boundedGalleryPixels(missing), isEmpty);
  });

  test('갤러리 정리는 지정된 캐시 바로 밑의 선택 사본 하나만 회수한다', () async {
    final id = ['00000000', '0000', '4000', '8000', '000000000000'].join('-');
    final cache = Directory('${root.path}/cache');
    final selected = await make('cache/$id/selected.jpg');
    final sibling = await make('cache/$id/other.jpg');
    final external = await make('gallery/$id/original.jpg');
    final regular = await make('cache/ordinary/user-photo.jpg');
    final nested = await make('cache/nested/$id/personal.jpg');
    for (final keep in [external, regular, nested]) {
      await discardPickerCopy(keep, cache);
      expect(await keep.readAsString(), 'synthetic');
    }
    await discardPickerCopy(selected, cache);
    expect(await selected.exists(), isFalse);
    expect(await sibling.readAsString(), 'synthetic');
    await discardPickerCopy(sibling, cache);
    expect(await sibling.parent.exists(), isFalse);
  });

  test('실제와 연습 DB의 참조·구형 파일·문서 밖 파일을 보존하고 미참조 초상화만 회수한다', () async {
    final docs = Directory('${root.path}/documents')..createSync();
    final old = await createPetPortrait(docs);
    final other = await createPetPortrait(docs);
    expect(other.path, isNot(old.path));
    final legacy = await make('documents/portrait.png');
    final outside = await make('gallery/portrait-123.png');
    final production = sqlite3.open('${docs.path}/mypet.sqlite');
    final practice = sqlite3.open('${docs.path}/mypet_test.sqlite');
    try {
      for (final db in [production, practice]) {
        db.execute('CREATE TABLE pets(portrait_path TEXT)');
        db.execute('INSERT INTO pets VALUES (?)', [old.path]);
      }
      production.execute('UPDATE pets SET portrait_path = ?', [other.path]);
      await retirePetPortrait(docs, old.path, other.path);
      expect(await old.exists(), isTrue);
      practice.execute('DELETE FROM pets');
      await retirePetPortrait(docs, old.path, other.path);
      expect(await old.exists(), isFalse);
      for (final safe in [legacy, outside, other]) {
        await retirePetPortrait(docs, safe.path, other.path);
        expect(await safe.exists(), isTrue);
      }
      final debug = sqlite3.open('${docs.path}/mypet_debug.sqlite');
      try {
        debug.execute('CREATE TABLE pets(portrait_path TEXT)');
        final debugPhoto = await createPetPortrait(docs);
        debug.execute('INSERT INTO pets VALUES (?)', [debugPhoto.path]);
        await retirePetPortrait(docs, debugPhoto.path, other.path);
        expect(await debugPhoto.exists(), isTrue);
      } finally {
        debug.close();
      }
      practice.execute('DROP TABLE pets');
      final unknown = await createPetPortrait(docs);
      await retirePetPortrait(docs, unknown.path, other.path);
      expect(await unknown.exists(), isTrue);
    } finally {
      production.close();
      practice.close();
    }
  });

  test('엔진의 축소 디코더가 세로 촬영 방향을 유지하고 사진의 메타데이터를 뺀다', () async {
    final input = img.Image(width: 1200, height: 600);
    img.fill(input, color: img.ColorRgb8(245, 235, 200));
    img.fillRect(
      input,
      x1: 0,
      y1: 0,
      x2: 500,
      y2: 599,
      color: img.ColorRgb8(210, 36, 24),
    );
    input.exif.imageIfd.orientation = 6;
    input.exif.imageIfd.make = 'FictionalCamera';
    final path = File('${root.path}/synthetic.jpg');
    await path.writeAsBytes(img.encodeJpg(input));
    final bounded = img.decodePng(await boundedGalleryPixels(path))!;
    expect((bounded.width, bounded.height), (384, 768));
    final top = bounded.getPixel(150, 100), bottom = bounded.getPixel(150, 600);
    expect(top.r - top.g, greaterThan(100));
    expect(bottom.r - bottom.g, lessThan(30));
    expect(bounded.exif.imageIfd.make, isNull);
    expect(bounded.exif.imageIfd.orientation, isNull);
    expect(
      img.decodeJpg(await path.readAsBytes())!.exif.imageIfd.make,
      'FictionalCamera',
    );
  });
}
