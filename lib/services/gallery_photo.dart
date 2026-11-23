import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/database.dart' show AppDatabase;

/// Android 갤러리 원본은 소유자 갤러리에 둔다. 플러그인이 별도로 만든 앱 캐시 사본만 회수한다.
Future<Uint8List?> pickPetPhotoBytes(bool Function() current) async {
  final android = Platform.isAndroid;
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    requestFullMetadata: false,
    maxWidth: android ? null : 1200,
    maxHeight: android ? null : 1200,
  );
  if (picked == null) return null;
  final file = File(picked.path);
  try {
    if (!current()) return null;
    if (!android) return await picked.readAsBytes();
    return await boundedGalleryPixels(file);
  } finally {
    if (android) {
      try {
        await discardPickerCopy(file, await getTemporaryDirectory());
      } on Exception {
        // 앱 캐시 소유를 확인하지 못한 파일은 건드리지 않는다.
      }
    }
  }
}

/// 카메라 원본을 Dart RGBA 버퍼로 펼치기 전에 엔진 디코더에 최대 길이를 지정한다.
Future<Uint8List> boundedGalleryPixels(File file) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final scale = min(1.0, 768 / max(descriptor.width, descriptor.height));
    codec = await descriptor.instantiateCodec(
      targetWidth: max(1, (descriptor.width * scale).round()),
      targetHeight: max(1, (descriptor.height * scale).round()),
    );
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes) ??
        Uint8List(0);
  } on Exception {
    return Uint8List(0);
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

final _pickerId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

Future<void> discardPickerCopy(File picked, Directory cache) async {
  final directory = picked.absolute.parent;
  final parts = directory.uri.pathSegments.where((s) => s.isNotEmpty);
  if (parts.isEmpty || !_pickerId.hasMatch(parts.last)) return;
  if (await FileSystemEntity.type(directory.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      await FileSystemEntity.type(picked.path, followLinks: false) !=
          FileSystemEntityType.file) {
    return;
  }
  final root = await cache.resolveSymbolicLinks();
  final resolved = await picked.resolveSymbolicLinks();
  final parent = await directory.resolveSymbolicLinks();
  if (Directory(parent).parent.path != root ||
      File(resolved).parent.path != parent) {
    return;
  }
  await picked.delete();
  try {
    await directory.delete();
  } on FileSystemException {
    // 같은 디렉터리의 다른 파일은 소유하지 않는다.
  }
}

Future<File> createPetPortrait(Directory documents) async {
  var stamp = DateTime.now().microsecondsSinceEpoch;
  while (true) {
    final file = File('${documents.path}/portrait-${stamp++}.png');
    try {
      return await file.create(exclusive: true);
    } on FileSystemException {
      if (!await file.exists()) rethrow;
    }
  }
}

/// 확정한 PNG를 완성하고, 선택을 확정한 펫이 유효한 동안 DB에 연결한다.
Future<bool> storePetPortrait(
  Uint8List png, {
  required bool Function() current,
  required Future<({String? previousPortrait})?> Function(String path) commit,
}) async {
  File? pending;
  try {
    final directory = await getApplicationDocumentsDirectory();
    if (!current()) return false;
    pending = await createPetPortrait(directory);
    await pending.writeAsBytes(png, flush: true);
    if (!current()) return false;
    final path = pending.path;
    final saved = await commit(path);
    if (saved == null) return false;
    pending = null;
    await retirePetPortrait(directory, saved.previousPortrait, path);
    return true;
  } on Exception {
    return false;
  } finally {
    if (pending != null) {
      try {
        await pending.delete();
      } on FileSystemException {
        // DB가 참조하는 기존 파일은 이 작업에 속하지 않는다.
      }
    }
  }
}

/// 이름·형식·위치를 확인한 앱 생성 초상화만, 이 앱의 DB 어디에도 참조가 없을 때 제거한다.
Future<void> retirePetPortrait(
  Directory documents,
  String? oldPath,
  String activePath,
) async {
  if (oldPath == null || oldPath == activePath) return;
  final name = File(oldPath).uri.pathSegments.last;
  if (!RegExp(r'^portrait-[0-9]+\.png$').hasMatch(name)) return;
  try {
    final old = File(oldPath);
    if (await FileSystemEntity.type(old.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return;
    }
    final root = await documents.resolveSymbolicLinks();
    final canonical = await old.resolveSymbolicLinks();
    if (File(canonical).parent.path != root) return;
    // 파일 경로나 DB 형식이 불확실하면 보존한다.
    if (await compute(_portraitInUse, (root: root, path: canonical))) return;
    await old.delete();
  } on Exception {
    // 사용 중인 경로일 수 있으면 다음 사진을 위태롭게 하지 않는다.
  }
}

bool _portraitInUse(({String root, String path}) args) {
  for (final name in const [
    AppDatabase.realName,
    AppDatabase.practiceName,
    AppDatabase.debugName,
  ]) {
    final file = File('${args.root}/$name.sqlite');
    if (!file.existsSync()) continue;
    final reader = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final rows = reader.select(
        'SELECT portrait_path FROM pets WHERE portrait_path IS NOT NULL',
      );
      for (final row in rows) {
        final value = row['portrait_path'] as String;
        final portrait = File(value);
        if (portrait.absolute.path == args.path ||
            (portrait.existsSync() &&
                portrait.resolveSymbolicLinksSync() == args.path)) {
          return true;
        }
      }
    } finally {
      reader.close();
    }
  }
  return false;
}
