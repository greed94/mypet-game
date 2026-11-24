import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gallery_photo.dart';

import '../art/photo_art.dart';
import 'photo_framing_screen.dart';
import '../pet/friends.dart';
import '../pet/guest.dart';
import '../pet/josa.dart';
import '../pet/pet_controller.dart';
import '../pet/pet_rules.dart';
import '../pet/shapes.dart';
import 'friends.dart';
import 'keep_words.dart';
import 'shape_picker.dart';

/// 아는 강아지(친구·가족네) 데려오기와 고치기. [dog]이 있으면 고치기.
/// 사진은 털색만 뽑고 저장하지 않는다. 지우면 true로 닫힌다.
class KnownDogScreen extends StatefulWidget {
  const KnownDogScreen({super.key, required this.controller, this.dog});

  final PetController controller;
  final Guest? dog;

  @override
  State<KnownDogScreen> createState() => _KnownDogScreenState();
}

class _KnownDogScreenState extends State<KnownDogScreen> {
  late final _name = TextEditingController(
    text: switch (widget.dog) {
      final d? => widget.controller.friends[d.id]?.name ?? '',
      null => '',
    },
  );
  late PetColors _colors = switch (widget.dog) {
    final d? => PetColors(main: d.main, second: d.second, marking: d.marking),
    null => PetColors(
      main: furPresets[1].$2,
      second: furPresets[1].$3,
      marking: furPresets[1].$4,
    ),
  };
  late String _shape = widget.dog?.shape ?? friendShapes.first.id;
  late bool _puppy = widget.dog?.puppy ?? false;
  bool _fromPhoto = false;
  EditablePetPhoto? _editablePhoto;
  bool _picking = false;
  bool _saving = false;
  int _photoGen = 0;

  bool get _canEdit => !_saving && !widget.controller.isDisposed;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Guest get _preview => knownGuest(
    id: widget.dog?.id ?? 'preview',
    shape: _shape,
    main: _colors.main,
    second: _colors.second,
    marking: _colors.marking,
    puppy: _puppy,
  );

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _usePhoto(EditablePetPhoto photo) {
    setState(() {
      _editablePhoto = photo;
      _colors = photo.selection.look.colors;
      _fromPhoto = true;
    });
  }

  void _choosePreset(int i) {
    if (!mounted || !_canEdit) return;
    _photoGen++;
    final p = furPresets[i];
    setState(() {
      _colors = PetColors(main: p.$2, second: p.$3, marking: p.$4);
      _fromPhoto = false;
      _editablePhoto = null;
    });
  }

  Future<void> _pickPhoto() async {
    if (!mounted || _picking || !_canEdit) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    final mine = ++_photoGen;
    bool current() =>
        mounted && !widget.controller.isDisposed && mine == _photoGen;
    setState(() => _picking = true);
    try {
      final bytes = await pickPetPhotoBytes(current);
      if (!current() || bytes == null) return;
      final source = await compute(preparePetPhoto, bytes);
      if (!current()) return;
      if (source == null) {
        _snack('사진을 읽지 못했어요. 다른 사진으로 해볼까요?');
        return;
      }
      _usePhoto(centerPetPhoto(source));
    } on PlatformException {
      if (current()) _snack('사진을 열지 못했어요. 다시 골라 볼까요?');
    } on FileSystemException {
      if (current()) _snack('사진을 읽지 못했어요. 다른 사진으로 해볼까요?');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!mounted || !_canEdit || _picking) return;
    final name = cleanFriendName(_name.text);
    if (name == null) return;
    setState(() => _saving = true);
    final c = widget.controller;
    try {
      if (widget.dog case final dog?) {
        await c.editKnownDog(
          dog.id,
          name: name,
          shape: _shape,
          colors: _colors,
          puppy: _puppy,
          fromPhoto: _fromPhoto,
        );
        if (mounted && !c.isDisposed) Navigator.pop(context, false);
        return;
      }
      final added = await c.addKnownDog(
        name: name,
        shape: _shape,
        colors: _colors,
        puppy: _puppy,
        fromPhoto: _fromPhoto,
      );
      if (!mounted || c.isDisposed) return;
      if (added == null) {
        _snack('아는 강아지는 $maxKnownDogs마리까지 데려올 수 있어요.');
        return;
      }
      _snack('${josa(name, '이/가')} 다음에 카페에 가면 와 있어요.');
      Navigator.pop(context, false);
    } on Exception {
      if (mounted) _snack('저장하지 못했어요. 다시 해볼까요?');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    if (!mounted || !_canEdit || _picking) return;
    final dog = widget.dog;
    if (dog == null) return;
    final c = widget.controller;
    final name = friendName(dog, c.friends[dog.id]);
    setState(() => _saving = true);
    var answered = false;
    void answer(BuildContext dialogContext, bool yes) {
      if (answered) return;
      answered = true;
      Navigator.pop(dialogContext, yes);
    }

    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${josa(name, '을/를')} 지울까요?'),
          content: const Text('사이와 이름도 같이 지워져요. 일기에 남은 이야기는 그대로예요.'),
          actions: [
            TextButton(
              onPressed: () => answer(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => answer(context, true),
              child: const Text('지우기'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted || c.isDisposed) return;
      await c.removeKnownDog(dog.id);
      if (mounted && !c.isDisposed) Navigator.pop(context, true);
    } on Exception {
      if (mounted && !c.isDisposed) _snack('지우지 못했어요. 다시 해볼까요?');
    } finally {
      answered = true;
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.dog != null;
    final label = Theme.of(context).textTheme.labelLarge;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? '아는 강아지 고치기' : '아는 강아지 데려오기')),
      body: ListView(
        padding:
            MediaQuery.paddingOf(context).copyWith(top: 0) +
            const EdgeInsets.all(16),
        children: [
          Center(child: GuestFace(_preview, box: 112, cache: false)),
          const SizedBox(height: 8),
          Text(
            keepWords(
              '친구나 가족네 강아지를 데려오면 동네 카페에 놀러 와요. '
              '처음엔 서로 낯설어하고, 만날수록 가까워져요.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            enabled: _canEdit,
            maxLength: 10,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '예: 초코',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _picking || !_canEdit ? null : _pickPhoto,
            icon: const Icon(Icons.photo_outlined),
            label: Text(_picking ? '읽는 중…' : '사진에서 털색 뽑기'),
          ),
          if (_editablePhoto case final photo?)
            PhotoFrameButton(
              shape: _shape,
              stage: _puppy ? PetStage.puppy : PetStage.adult,
              photo: photo,
              onApply: _picking || !_canEdit
                  ? null
                  : (next) {
                      if (_canEdit &&
                          identical(
                            _editablePhoto?.source.pixels,
                            next.source.pixels,
                          )) {
                        _usePhoto(next);
                      }
                    },
            ),
          const SizedBox(height: 12),
          Text('또는 색 고르기', style: label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (i, p) in furPresets.indexed)
                ChoiceChip(
                  label: Text(p.$1),
                  avatar: CircleAvatar(backgroundColor: Color(p.$2)),
                  selected: !_fromPhoto && _colors.main == p.$2,
                  onSelected: _canEdit ? (_) => _choosePreset(i) : null,
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('아기 강아지예요'),
            value: _puppy,
            onChanged: _canEdit ? (v) => setState(() => _puppy = v) : null,
          ),
          Text('어떤 모양이 가장 닮았나요?', style: label),
          const SizedBox(height: 8),
          ShapePicker(
            colors: _colors,
            selected: _shape,
            shapes: friendShapes,
            stage: _puppy ? PetStage.puppy : PetStage.adult,
            onSelect: (id) {
              if (!mounted || !_canEdit) return;
              setState(() => _shape = id);
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                !_canEdit || _picking || cleanFriendName(_name.text) == null
                ? null
                : _save,
            child: Text(editing ? '저장' : '데려오기'),
          ),
          if (editing) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: !_canEdit || _picking ? null : _remove,
              child: const Text('이 친구 지우기'),
            ),
          ],
        ],
      ),
    );
  }
}
