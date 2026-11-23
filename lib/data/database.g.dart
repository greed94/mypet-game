// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PetsTable extends Pets with TableInfo<$PetsTable, Pet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PetStage, String> stage =
      GeneratedColumn<String>(
        'stage',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PetStage>($PetsTable.$converterstage);
  static const VerificationMeta _furMainMeta = const VerificationMeta(
    'furMain',
  );
  @override
  late final GeneratedColumn<int> furMain = GeneratedColumn<int>(
    'fur_main',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _furSecondMeta = const VerificationMeta(
    'furSecond',
  );
  @override
  late final GeneratedColumn<int> furSecond = GeneratedColumn<int>(
    'fur_second',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accentMeta = const VerificationMeta('accent');
  @override
  late final GeneratedColumn<int> accent = GeneratedColumn<int>(
    'accent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markingMeta = const VerificationMeta(
    'marking',
  );
  @override
  late final GeneratedColumn<int> marking = GeneratedColumn<int>(
    'marking',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF914F28),
  );
  static const VerificationMeta _bornAtMeta = const VerificationMeta('bornAt');
  @override
  late final GeneratedColumn<DateTime> bornAt = GeneratedColumn<DateTime>(
    'born_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<double> mood = GeneratedColumn<double>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hungerMeta = const VerificationMeta('hunger');
  @override
  late final GeneratedColumn<double> hunger = GeneratedColumn<double>(
    'hunger',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _energyMeta = const VerificationMeta('energy');
  @override
  late final GeneratedColumn<double> energy = GeneratedColumn<double>(
    'energy',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _affectionMeta = const VerificationMeta(
    'affection',
  );
  @override
  late final GeneratedColumn<double> affection = GeneratedColumn<double>(
    'affection',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _careScoreMeta = const VerificationMeta(
    'careScore',
  );
  @override
  late final GeneratedColumn<double> careScore = GeneratedColumn<double>(
    'care_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _regionNameMeta = const VerificationMeta(
    'regionName',
  );
  @override
  late final GeneratedColumn<String> regionName = GeneratedColumn<String>(
    'region_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portraitPathMeta = const VerificationMeta(
    'portraitPath',
  );
  @override
  late final GeneratedColumn<String> portraitPath = GeneratedColumn<String>(
    'portrait_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shapeMeta = const VerificationMeta('shape');
  @override
  late final GeneratedColumn<String> shape = GeneratedColumn<String>(
    'shape',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('papillon'),
  );
  static const VerificationMeta _countDayMeta = const VerificationMeta(
    'countDay',
  );
  @override
  late final GeneratedColumn<String> countDay = GeneratedColumn<String>(
    'count_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bondTodayMeta = const VerificationMeta(
    'bondToday',
  );
  @override
  late final GeneratedColumn<double> bondToday = GeneratedColumn<double>(
    'bond_today',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _talksTodayMeta = const VerificationMeta(
    'talksToday',
  );
  @override
  late final GeneratedColumn<int> talksToday = GeneratedColumn<int>(
    'talks_today',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _activityMeta = const VerificationMeta(
    'activity',
  );
  @override
  late final GeneratedColumn<double> activity = GeneratedColumn<double>(
    'activity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentMeta = const VerificationMeta(
    'attachment',
  );
  @override
  late final GeneratedColumn<double> attachment = GeneratedColumn<double>(
    'attachment',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rhythmMeta = const VerificationMeta('rhythm');
  @override
  late final GeneratedColumn<String> rhythm = GeneratedColumn<String>(
    'rhythm',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Taste?, String> likeTaste =
      GeneratedColumn<String>(
        'like_taste',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Taste?>($PetsTable.$converterlikeTasten);
  @override
  late final GeneratedColumnWithTypeConverter<Taste?, String> dislikeTaste =
      GeneratedColumn<String>(
        'dislike_taste',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Taste?>($PetsTable.$converterdislikeTasten);
  static const VerificationMeta _lastStepTotalMeta = const VerificationMeta(
    'lastStepTotal',
  );
  @override
  late final GeneratedColumn<int> lastStepTotal = GeneratedColumn<int>(
    'last_step_total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pocketDayMeta = const VerificationMeta(
    'pocketDay',
  );
  @override
  late final GeneratedColumn<String> pocketDay = GeneratedColumn<String>(
    'pocket_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pocketCountMeta = const VerificationMeta(
    'pocketCount',
  );
  @override
  late final GeneratedColumn<int> pocketCount = GeneratedColumn<int>(
    'pocket_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _windowNightMeta = const VerificationMeta(
    'windowNight',
  );
  @override
  late final GeneratedColumn<String> windowNight = GeneratedColumn<String>(
    'window_night',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _giftDayMeta = const VerificationMeta(
    'giftDay',
  );
  @override
  late final GeneratedColumn<String> giftDay = GeneratedColumn<String>(
    'gift_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snowDayMeta = const VerificationMeta(
    'snowDay',
  );
  @override
  late final GeneratedColumn<String> snowDay = GeneratedColumn<String>(
    'snow_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _comfortDueMeta = const VerificationMeta(
    'comfortDue',
  );
  @override
  late final GeneratedColumn<bool> comfortDue = GeneratedColumn<bool>(
    'comfort_due',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("comfort_due" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _comfortDayMeta = const VerificationMeta(
    'comfortDay',
  );
  @override
  late final GeneratedColumn<String> comfortDay = GeneratedColumn<String>(
    'comfort_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pottyAtMeta = const VerificationMeta(
    'pottyAt',
  );
  @override
  late final GeneratedColumn<DateTime> pottyAt = GeneratedColumn<DateTime>(
    'potty_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCrisisAtMeta = const VerificationMeta(
    'lastCrisisAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCrisisAt = GeneratedColumn<DateTime>(
    'last_crisis_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _daycareFromMeta = const VerificationMeta(
    'daycareFrom',
  );
  @override
  late final GeneratedColumn<DateTime> daycareFrom = GeneratedColumn<DateTime>(
    'daycare_from',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _daycareLessonMeta = const VerificationMeta(
    'daycareLesson',
  );
  @override
  late final GeneratedColumn<String> daycareLesson = GeneratedColumn<String>(
    'daycare_lesson',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _daycareRecitalStatsMeta =
      const VerificationMeta('daycareRecitalStats');
  @override
  late final GeneratedColumn<String> daycareRecitalStats =
      GeneratedColumn<String>(
        'daycare_recital_stats',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recitalDaysMeta = const VerificationMeta(
    'recitalDays',
  );
  @override
  late final GeneratedColumn<String> recitalDays = GeneratedColumn<String>(
    'recital_days',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wishMeta = const VerificationMeta('wish');
  @override
  late final GeneratedColumn<String> wish = GeneratedColumn<String>(
    'wish',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wishDayMeta = const VerificationMeta(
    'wishDay',
  );
  @override
  late final GeneratedColumn<String> wishDay = GeneratedColumn<String>(
    'wish_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wishDoneMeta = const VerificationMeta(
    'wishDone',
  );
  @override
  late final GeneratedColumn<bool> wishDone = GeneratedColumn<bool>(
    'wish_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("wish_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pawsMeta = const VerificationMeta('paws');
  @override
  late final GeneratedColumn<int> paws = GeneratedColumn<int>(
    'paws',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pawsTodayMeta = const VerificationMeta(
    'pawsToday',
  );
  @override
  late final GeneratedColumn<int> pawsToday = GeneratedColumn<int>(
    'paws_today',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pawsDayMeta = const VerificationMeta(
    'pawsDay',
  );
  @override
  late final GeneratedColumn<String> pawsDay = GeneratedColumn<String>(
    'paws_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pawMarksMeta = const VerificationMeta(
    'pawMarks',
  );
  @override
  late final GeneratedColumn<String> pawMarks = GeneratedColumn<String>(
    'paw_marks',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eveningDayMeta = const VerificationMeta(
    'eveningDay',
  );
  @override
  late final GeneratedColumn<String> eveningDay = GeneratedColumn<String>(
    'evening_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rugMeta = const VerificationMeta('rug');
  @override
  late final GeneratedColumn<String> rug = GeneratedColumn<String>(
    'rug',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownedMeta = const VerificationMeta('owned');
  @override
  late final GeneratedColumn<String> owned = GeneratedColumn<String>(
    'owned',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _touchXMeta = const VerificationMeta('touchX');
  @override
  late final GeneratedColumn<double> touchX = GeneratedColumn<double>(
    'touch_x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quirkMeta = const VerificationMeta('quirk');
  @override
  late final GeneratedColumn<String> quirk = GeneratedColumn<String>(
    'quirk',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doorNewsMeta = const VerificationMeta(
    'doorNews',
  );
  @override
  late final GeneratedColumn<String> doorNews = GeneratedColumn<String>(
    'door_news',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _habitMeta = const VerificationMeta('habit');
  @override
  late final GeneratedColumn<String> habit = GeneratedColumn<String>(
    'habit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _treatsTriedMeta = const VerificationMeta(
    'treatsTried',
  );
  @override
  late final GeneratedColumn<String> treatsTried = GeneratedColumn<String>(
    'treats_tried',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _treatSharesMeta = const VerificationMeta(
    'treatShares',
  );
  @override
  late final GeneratedColumn<String> treatShares = GeneratedColumn<String>(
    'treat_shares',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _treatPouchMeta = const VerificationMeta(
    'treatPouch',
  );
  @override
  late final GeneratedColumn<String> treatPouch = GeneratedColumn<String>(
    'treat_pouch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _treatDayMeta = const VerificationMeta(
    'treatDay',
  );
  @override
  late final GeneratedColumn<String> treatDay = GeneratedColumn<String>(
    'treat_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkupAtMeta = const VerificationMeta(
    'checkupAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkupAt = GeneratedColumn<DateTime>(
    'checkup_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkupsMeta = const VerificationMeta(
    'checkups',
  );
  @override
  late final GeneratedColumn<int> checkups = GeneratedColumn<int>(
    'checkups',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastWeightMeta = const VerificationMeta(
    'lastWeight',
  );
  @override
  late final GeneratedColumn<double> lastWeight = GeneratedColumn<double>(
    'last_weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    stage,
    furMain,
    furSecond,
    accent,
    marking,
    bornAt,
    lastSeenAt,
    mood,
    hunger,
    energy,
    affection,
    careScore,
    regionName,
    latitude,
    longitude,
    portraitPath,
    shape,
    countDay,
    bondToday,
    talksToday,
    activity,
    attachment,
    rhythm,
    likeTaste,
    dislikeTaste,
    lastStepTotal,
    pocketDay,
    pocketCount,
    windowNight,
    giftDay,
    snowDay,
    comfortDue,
    comfortDay,
    pottyAt,
    lastCrisisAt,
    daycareFrom,
    daycareLesson,
    daycareRecitalStats,
    recitalDays,
    wish,
    wishDay,
    wishDone,
    paws,
    pawsToday,
    pawsDay,
    pawMarks,
    eveningDay,
    rug,
    owned,
    touchX,
    quirk,
    doorNews,
    habit,
    treatsTried,
    treatShares,
    treatPouch,
    treatDay,
    checkupAt,
    checkups,
    lastWeight,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('fur_main')) {
      context.handle(
        _furMainMeta,
        furMain.isAcceptableOrUnknown(data['fur_main']!, _furMainMeta),
      );
    } else if (isInserting) {
      context.missing(_furMainMeta);
    }
    if (data.containsKey('fur_second')) {
      context.handle(
        _furSecondMeta,
        furSecond.isAcceptableOrUnknown(data['fur_second']!, _furSecondMeta),
      );
    } else if (isInserting) {
      context.missing(_furSecondMeta);
    }
    if (data.containsKey('accent')) {
      context.handle(
        _accentMeta,
        accent.isAcceptableOrUnknown(data['accent']!, _accentMeta),
      );
    } else if (isInserting) {
      context.missing(_accentMeta);
    }
    if (data.containsKey('marking')) {
      context.handle(
        _markingMeta,
        marking.isAcceptableOrUnknown(data['marking']!, _markingMeta),
      );
    }
    if (data.containsKey('born_at')) {
      context.handle(
        _bornAtMeta,
        bornAt.isAcceptableOrUnknown(data['born_at']!, _bornAtMeta),
      );
    } else if (isInserting) {
      context.missing(_bornAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    } else if (isInserting) {
      context.missing(_moodMeta);
    }
    if (data.containsKey('hunger')) {
      context.handle(
        _hungerMeta,
        hunger.isAcceptableOrUnknown(data['hunger']!, _hungerMeta),
      );
    } else if (isInserting) {
      context.missing(_hungerMeta);
    }
    if (data.containsKey('energy')) {
      context.handle(
        _energyMeta,
        energy.isAcceptableOrUnknown(data['energy']!, _energyMeta),
      );
    } else if (isInserting) {
      context.missing(_energyMeta);
    }
    if (data.containsKey('affection')) {
      context.handle(
        _affectionMeta,
        affection.isAcceptableOrUnknown(data['affection']!, _affectionMeta),
      );
    } else if (isInserting) {
      context.missing(_affectionMeta);
    }
    if (data.containsKey('care_score')) {
      context.handle(
        _careScoreMeta,
        careScore.isAcceptableOrUnknown(data['care_score']!, _careScoreMeta),
      );
    }
    if (data.containsKey('region_name')) {
      context.handle(
        _regionNameMeta,
        regionName.isAcceptableOrUnknown(data['region_name']!, _regionNameMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('portrait_path')) {
      context.handle(
        _portraitPathMeta,
        portraitPath.isAcceptableOrUnknown(
          data['portrait_path']!,
          _portraitPathMeta,
        ),
      );
    }
    if (data.containsKey('shape')) {
      context.handle(
        _shapeMeta,
        shape.isAcceptableOrUnknown(data['shape']!, _shapeMeta),
      );
    }
    if (data.containsKey('count_day')) {
      context.handle(
        _countDayMeta,
        countDay.isAcceptableOrUnknown(data['count_day']!, _countDayMeta),
      );
    }
    if (data.containsKey('bond_today')) {
      context.handle(
        _bondTodayMeta,
        bondToday.isAcceptableOrUnknown(data['bond_today']!, _bondTodayMeta),
      );
    }
    if (data.containsKey('talks_today')) {
      context.handle(
        _talksTodayMeta,
        talksToday.isAcceptableOrUnknown(data['talks_today']!, _talksTodayMeta),
      );
    }
    if (data.containsKey('activity')) {
      context.handle(
        _activityMeta,
        activity.isAcceptableOrUnknown(data['activity']!, _activityMeta),
      );
    }
    if (data.containsKey('attachment')) {
      context.handle(
        _attachmentMeta,
        attachment.isAcceptableOrUnknown(data['attachment']!, _attachmentMeta),
      );
    }
    if (data.containsKey('rhythm')) {
      context.handle(
        _rhythmMeta,
        rhythm.isAcceptableOrUnknown(data['rhythm']!, _rhythmMeta),
      );
    }
    if (data.containsKey('last_step_total')) {
      context.handle(
        _lastStepTotalMeta,
        lastStepTotal.isAcceptableOrUnknown(
          data['last_step_total']!,
          _lastStepTotalMeta,
        ),
      );
    }
    if (data.containsKey('pocket_day')) {
      context.handle(
        _pocketDayMeta,
        pocketDay.isAcceptableOrUnknown(data['pocket_day']!, _pocketDayMeta),
      );
    }
    if (data.containsKey('pocket_count')) {
      context.handle(
        _pocketCountMeta,
        pocketCount.isAcceptableOrUnknown(
          data['pocket_count']!,
          _pocketCountMeta,
        ),
      );
    }
    if (data.containsKey('window_night')) {
      context.handle(
        _windowNightMeta,
        windowNight.isAcceptableOrUnknown(
          data['window_night']!,
          _windowNightMeta,
        ),
      );
    }
    if (data.containsKey('gift_day')) {
      context.handle(
        _giftDayMeta,
        giftDay.isAcceptableOrUnknown(data['gift_day']!, _giftDayMeta),
      );
    }
    if (data.containsKey('snow_day')) {
      context.handle(
        _snowDayMeta,
        snowDay.isAcceptableOrUnknown(data['snow_day']!, _snowDayMeta),
      );
    }
    if (data.containsKey('comfort_due')) {
      context.handle(
        _comfortDueMeta,
        comfortDue.isAcceptableOrUnknown(data['comfort_due']!, _comfortDueMeta),
      );
    }
    if (data.containsKey('comfort_day')) {
      context.handle(
        _comfortDayMeta,
        comfortDay.isAcceptableOrUnknown(data['comfort_day']!, _comfortDayMeta),
      );
    }
    if (data.containsKey('potty_at')) {
      context.handle(
        _pottyAtMeta,
        pottyAt.isAcceptableOrUnknown(data['potty_at']!, _pottyAtMeta),
      );
    }
    if (data.containsKey('last_crisis_at')) {
      context.handle(
        _lastCrisisAtMeta,
        lastCrisisAt.isAcceptableOrUnknown(
          data['last_crisis_at']!,
          _lastCrisisAtMeta,
        ),
      );
    }
    if (data.containsKey('daycare_from')) {
      context.handle(
        _daycareFromMeta,
        daycareFrom.isAcceptableOrUnknown(
          data['daycare_from']!,
          _daycareFromMeta,
        ),
      );
    }
    if (data.containsKey('daycare_lesson')) {
      context.handle(
        _daycareLessonMeta,
        daycareLesson.isAcceptableOrUnknown(
          data['daycare_lesson']!,
          _daycareLessonMeta,
        ),
      );
    }
    if (data.containsKey('daycare_recital_stats')) {
      context.handle(
        _daycareRecitalStatsMeta,
        daycareRecitalStats.isAcceptableOrUnknown(
          data['daycare_recital_stats']!,
          _daycareRecitalStatsMeta,
        ),
      );
    }
    if (data.containsKey('recital_days')) {
      context.handle(
        _recitalDaysMeta,
        recitalDays.isAcceptableOrUnknown(
          data['recital_days']!,
          _recitalDaysMeta,
        ),
      );
    }
    if (data.containsKey('wish')) {
      context.handle(
        _wishMeta,
        wish.isAcceptableOrUnknown(data['wish']!, _wishMeta),
      );
    }
    if (data.containsKey('wish_day')) {
      context.handle(
        _wishDayMeta,
        wishDay.isAcceptableOrUnknown(data['wish_day']!, _wishDayMeta),
      );
    }
    if (data.containsKey('wish_done')) {
      context.handle(
        _wishDoneMeta,
        wishDone.isAcceptableOrUnknown(data['wish_done']!, _wishDoneMeta),
      );
    }
    if (data.containsKey('paws')) {
      context.handle(
        _pawsMeta,
        paws.isAcceptableOrUnknown(data['paws']!, _pawsMeta),
      );
    }
    if (data.containsKey('paws_today')) {
      context.handle(
        _pawsTodayMeta,
        pawsToday.isAcceptableOrUnknown(data['paws_today']!, _pawsTodayMeta),
      );
    }
    if (data.containsKey('paws_day')) {
      context.handle(
        _pawsDayMeta,
        pawsDay.isAcceptableOrUnknown(data['paws_day']!, _pawsDayMeta),
      );
    }
    if (data.containsKey('paw_marks')) {
      context.handle(
        _pawMarksMeta,
        pawMarks.isAcceptableOrUnknown(data['paw_marks']!, _pawMarksMeta),
      );
    }
    if (data.containsKey('evening_day')) {
      context.handle(
        _eveningDayMeta,
        eveningDay.isAcceptableOrUnknown(data['evening_day']!, _eveningDayMeta),
      );
    }
    if (data.containsKey('rug')) {
      context.handle(
        _rugMeta,
        rug.isAcceptableOrUnknown(data['rug']!, _rugMeta),
      );
    }
    if (data.containsKey('owned')) {
      context.handle(
        _ownedMeta,
        owned.isAcceptableOrUnknown(data['owned']!, _ownedMeta),
      );
    }
    if (data.containsKey('touch_x')) {
      context.handle(
        _touchXMeta,
        touchX.isAcceptableOrUnknown(data['touch_x']!, _touchXMeta),
      );
    }
    if (data.containsKey('quirk')) {
      context.handle(
        _quirkMeta,
        quirk.isAcceptableOrUnknown(data['quirk']!, _quirkMeta),
      );
    }
    if (data.containsKey('door_news')) {
      context.handle(
        _doorNewsMeta,
        doorNews.isAcceptableOrUnknown(data['door_news']!, _doorNewsMeta),
      );
    }
    if (data.containsKey('habit')) {
      context.handle(
        _habitMeta,
        habit.isAcceptableOrUnknown(data['habit']!, _habitMeta),
      );
    }
    if (data.containsKey('treats_tried')) {
      context.handle(
        _treatsTriedMeta,
        treatsTried.isAcceptableOrUnknown(
          data['treats_tried']!,
          _treatsTriedMeta,
        ),
      );
    }
    if (data.containsKey('treat_shares')) {
      context.handle(
        _treatSharesMeta,
        treatShares.isAcceptableOrUnknown(
          data['treat_shares']!,
          _treatSharesMeta,
        ),
      );
    }
    if (data.containsKey('treat_pouch')) {
      context.handle(
        _treatPouchMeta,
        treatPouch.isAcceptableOrUnknown(data['treat_pouch']!, _treatPouchMeta),
      );
    }
    if (data.containsKey('treat_day')) {
      context.handle(
        _treatDayMeta,
        treatDay.isAcceptableOrUnknown(data['treat_day']!, _treatDayMeta),
      );
    }
    if (data.containsKey('checkup_at')) {
      context.handle(
        _checkupAtMeta,
        checkupAt.isAcceptableOrUnknown(data['checkup_at']!, _checkupAtMeta),
      );
    }
    if (data.containsKey('checkups')) {
      context.handle(
        _checkupsMeta,
        checkups.isAcceptableOrUnknown(data['checkups']!, _checkupsMeta),
      );
    }
    if (data.containsKey('last_weight')) {
      context.handle(
        _lastWeightMeta,
        lastWeight.isAcceptableOrUnknown(data['last_weight']!, _lastWeightMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      stage: $PetsTable.$converterstage.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}stage'],
        )!,
      ),
      furMain: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fur_main'],
      )!,
      furSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fur_second'],
      )!,
      accent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accent'],
      )!,
      marking: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}marking'],
      )!,
      bornAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}born_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mood'],
      )!,
      hunger: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hunger'],
      )!,
      energy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}energy'],
      )!,
      affection: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}affection'],
      )!,
      careScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}care_score'],
      )!,
      regionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region_name'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      portraitPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}portrait_path'],
      ),
      shape: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shape'],
      )!,
      countDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}count_day'],
      ),
      bondToday: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bond_today'],
      )!,
      talksToday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}talks_today'],
      )!,
      activity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}activity'],
      ),
      attachment: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}attachment'],
      ),
      rhythm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rhythm'],
      ),
      likeTaste: $PetsTable.$converterlikeTasten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}like_taste'],
        ),
      ),
      dislikeTaste: $PetsTable.$converterdislikeTasten.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}dislike_taste'],
        ),
      ),
      lastStepTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_step_total'],
      ),
      pocketDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pocket_day'],
      ),
      pocketCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pocket_count'],
      )!,
      windowNight: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}window_night'],
      ),
      giftDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gift_day'],
      ),
      snowDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snow_day'],
      ),
      comfortDue: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}comfort_due'],
      )!,
      comfortDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comfort_day'],
      ),
      pottyAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}potty_at'],
      ),
      lastCrisisAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_crisis_at'],
      ),
      daycareFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}daycare_from'],
      ),
      daycareLesson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}daycare_lesson'],
      ),
      daycareRecitalStats: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}daycare_recital_stats'],
      ),
      recitalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recital_days'],
      ),
      wish: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wish'],
      ),
      wishDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wish_day'],
      ),
      wishDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}wish_done'],
      )!,
      paws: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paws'],
      )!,
      pawsToday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paws_today'],
      )!,
      pawsDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paws_day'],
      ),
      pawMarks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paw_marks'],
      ),
      eveningDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evening_day'],
      ),
      rug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rug'],
      ),
      owned: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owned'],
      ),
      touchX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}touch_x'],
      ),
      quirk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quirk'],
      ),
      doorNews: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}door_news'],
      ),
      habit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit'],
      ),
      treatsTried: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}treats_tried'],
      ),
      treatShares: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}treat_shares'],
      ),
      treatPouch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}treat_pouch'],
      ),
      treatDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}treat_day'],
      ),
      checkupAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checkup_at'],
      ),
      checkups: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checkups'],
      )!,
      lastWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_weight'],
      ),
    );
  }

  @override
  $PetsTable createAlias(String alias) {
    return $PetsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PetStage, String, String> $converterstage =
      const EnumNameConverter<PetStage>(PetStage.values);
  static JsonTypeConverter2<Taste, String, String> $converterlikeTaste =
      const EnumNameConverter<Taste>(Taste.values);
  static JsonTypeConverter2<Taste?, String?, String?> $converterlikeTasten =
      JsonTypeConverter2.asNullable($converterlikeTaste);
  static JsonTypeConverter2<Taste, String, String> $converterdislikeTaste =
      const EnumNameConverter<Taste>(Taste.values);
  static JsonTypeConverter2<Taste?, String?, String?> $converterdislikeTasten =
      JsonTypeConverter2.asNullable($converterdislikeTaste);
}

class Pet extends DataClass implements Insertable<Pet> {
  final int id;
  final String name;
  final PetStage stage;
  final int furMain;
  final int furSecond;
  final int accent;
  final int marking;
  final DateTime bornAt;
  final DateTime lastSeenAt;
  final double mood;
  final double hunger;
  final double energy;
  final double affection;
  final double careScore;
  final String? regionName;
  final double? latitude;
  final double? longitude;
  final String? portraitPath;

  /// 강아지 모양 틀 id(lib/pet/shapes.dart). 모양을 고르기 전의 펫은 모두 파피용 그림이었다.
  final String shape;

  /// 하루 한도(대화 횟수, 친밀도 몫)를 센 날. 앱을 다시 켜도 한도가 이어지게 여기 둔다.
  final String? countDay;
  final double bondToday;
  final int talksToday;

  /// 타고난 성격(0~1). 비어 있으면 컨트롤러가 펫 번호로 정해 저장한다.
  final double? activity;
  final double? attachment;

  /// 주인 생활 리듬(JSON, lib/pet/rhythm.dart).
  final String? rhythm;
  final Taste? likeTaste;
  final Taste? dislikeTaste;

  /// 폰 누적 걸음을 마지막으로 읽은 값. 다음에 열 때 이 값과의 차이만 쓴다.
  final int? lastStepTotal;
  final String? pocketDay;
  final int pocketCount;
  final String? windowNight;
  final String? giftDay;

  /// 올겨울 첫눈을 본 날. 그날 하루 창문에 코 자국이 남는다.
  final String? snowDay;

  /// 주인이 지친 말을 했다. 다음에 열 때 좋아하는 걸 하나 챙겨 온다.
  final bool comfortDue;
  final String? comfortDay;

  /// 마지막으로 쉬한 때(패드든 바닥이든). 앱을 열어 둔 동안 세 시간 지나면 다시 마렵다.
  final DateTime? pottyAt;

  /// 위기 안내를 띄운 때. 그 뒤 하루는 위로 선물로 안내를 가볍게 만들지 않는다.
  final DateTime? lastCrisisAt;

  /// 유치원에 맡긴 때. 하원(데리러 가거나 저녁 7시 버스)하면 비운다.
  final DateTime? daycareFrom;

  /// 맡길 때 고른 오늘 수업(개인기 이름, 자유 놀이면 'free'). 하원하면 비운다.
  final String? daycareLesson;

  /// 15시 발표회 상태. 그 뒤 앱 프로세스가 끝나도 다음 날 배고픔으로 판정하지 않게 보관한다.
  final String? daycareRecitalStats;

  /// 유치원 발표회에서 도장을 받은 날들(dayKey를 쉼표로). 방 벽 도장판과 훈련 수첩에 쓴다.
  final String? recitalDays;

  /// 오늘의 소원(lib/pet/wish.dart Wish.encode), 그 펫의 하루(dayKey), 들어줬는지.
  final String? wish;
  final String? wishDay;
  final bool wishDone;

  /// 발도장(lib/pet/paws.dart). 가진 수, 오늘(펫의 하루) 번 수와 그날, 받은 이정표와 한 번 해 본 것(쉼표, 'hand'는 손 베개),
  /// 저녁 이야기를 센 날, 깐 방석과 바꾼 꾸미기(쉼표). 목걸이 색은 accent 칸을 쓴다.
  final int paws;
  final int pawsToday;
  final String? pawsDay;
  final String? pawMarks;
  final String? eveningDay;
  final String? rug;
  final String? owned;

  /// 주인이 마지막으로 쓰다듬거나 손을 내민 바닥 자리(0~1). 가족이 되면 밤에 거기서 잔다.
  final double? touchX;

  /// 우리 애만의 버릇(lib/pet/quirks.dart의 이름). 처음 열 때 정해 남긴다.
  final String? quirk;

  /// 아침 현관 소식('펫의 날짜:물건 이름', 안 뒀거나 주인이 챙겼으면 '날짜:-'). 하루에 한 번.
  final String? doorNews;

  /// 카페 친구한테 옮은 버릇('버릇 이름|손님 id'). 그 친구를 오래 못 보면 사라진다.
  final String? habit;

  /// 먹여 본 간식과 반응('간식 id:love', 쉼표). 도감의 입맛 칸.
  final String? treatsTried;

  /// 오늘 간식을 나눠 준 카페 친구('dayKey|손님 id,손님 id'). 친구마다 하루 한 번.
  final String? treatShares;

  /// 간식 주머니(간식 id를 쉼표로)와 마지막으로 간식을 산 날(dayKey). 하루 한 번만 산다.
  final String? treatPouch;
  final String? treatDay;

  /// 마지막 검진 때·검진 횟수·그때 몸무게. 건강 수첩에 지난번과 비교해 보인다.
  final DateTime? checkupAt;
  final int checkups;
  final double? lastWeight;
  const Pet({
    required this.id,
    required this.name,
    required this.stage,
    required this.furMain,
    required this.furSecond,
    required this.accent,
    required this.marking,
    required this.bornAt,
    required this.lastSeenAt,
    required this.mood,
    required this.hunger,
    required this.energy,
    required this.affection,
    required this.careScore,
    this.regionName,
    this.latitude,
    this.longitude,
    this.portraitPath,
    required this.shape,
    this.countDay,
    required this.bondToday,
    required this.talksToday,
    this.activity,
    this.attachment,
    this.rhythm,
    this.likeTaste,
    this.dislikeTaste,
    this.lastStepTotal,
    this.pocketDay,
    required this.pocketCount,
    this.windowNight,
    this.giftDay,
    this.snowDay,
    required this.comfortDue,
    this.comfortDay,
    this.pottyAt,
    this.lastCrisisAt,
    this.daycareFrom,
    this.daycareLesson,
    this.daycareRecitalStats,
    this.recitalDays,
    this.wish,
    this.wishDay,
    required this.wishDone,
    required this.paws,
    required this.pawsToday,
    this.pawsDay,
    this.pawMarks,
    this.eveningDay,
    this.rug,
    this.owned,
    this.touchX,
    this.quirk,
    this.doorNews,
    this.habit,
    this.treatsTried,
    this.treatShares,
    this.treatPouch,
    this.treatDay,
    this.checkupAt,
    required this.checkups,
    this.lastWeight,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    {
      map['stage'] = Variable<String>($PetsTable.$converterstage.toSql(stage));
    }
    map['fur_main'] = Variable<int>(furMain);
    map['fur_second'] = Variable<int>(furSecond);
    map['accent'] = Variable<int>(accent);
    map['marking'] = Variable<int>(marking);
    map['born_at'] = Variable<DateTime>(bornAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    map['mood'] = Variable<double>(mood);
    map['hunger'] = Variable<double>(hunger);
    map['energy'] = Variable<double>(energy);
    map['affection'] = Variable<double>(affection);
    map['care_score'] = Variable<double>(careScore);
    if (!nullToAbsent || regionName != null) {
      map['region_name'] = Variable<String>(regionName);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || portraitPath != null) {
      map['portrait_path'] = Variable<String>(portraitPath);
    }
    map['shape'] = Variable<String>(shape);
    if (!nullToAbsent || countDay != null) {
      map['count_day'] = Variable<String>(countDay);
    }
    map['bond_today'] = Variable<double>(bondToday);
    map['talks_today'] = Variable<int>(talksToday);
    if (!nullToAbsent || activity != null) {
      map['activity'] = Variable<double>(activity);
    }
    if (!nullToAbsent || attachment != null) {
      map['attachment'] = Variable<double>(attachment);
    }
    if (!nullToAbsent || rhythm != null) {
      map['rhythm'] = Variable<String>(rhythm);
    }
    if (!nullToAbsent || likeTaste != null) {
      map['like_taste'] = Variable<String>(
        $PetsTable.$converterlikeTasten.toSql(likeTaste),
      );
    }
    if (!nullToAbsent || dislikeTaste != null) {
      map['dislike_taste'] = Variable<String>(
        $PetsTable.$converterdislikeTasten.toSql(dislikeTaste),
      );
    }
    if (!nullToAbsent || lastStepTotal != null) {
      map['last_step_total'] = Variable<int>(lastStepTotal);
    }
    if (!nullToAbsent || pocketDay != null) {
      map['pocket_day'] = Variable<String>(pocketDay);
    }
    map['pocket_count'] = Variable<int>(pocketCount);
    if (!nullToAbsent || windowNight != null) {
      map['window_night'] = Variable<String>(windowNight);
    }
    if (!nullToAbsent || giftDay != null) {
      map['gift_day'] = Variable<String>(giftDay);
    }
    if (!nullToAbsent || snowDay != null) {
      map['snow_day'] = Variable<String>(snowDay);
    }
    map['comfort_due'] = Variable<bool>(comfortDue);
    if (!nullToAbsent || comfortDay != null) {
      map['comfort_day'] = Variable<String>(comfortDay);
    }
    if (!nullToAbsent || pottyAt != null) {
      map['potty_at'] = Variable<DateTime>(pottyAt);
    }
    if (!nullToAbsent || lastCrisisAt != null) {
      map['last_crisis_at'] = Variable<DateTime>(lastCrisisAt);
    }
    if (!nullToAbsent || daycareFrom != null) {
      map['daycare_from'] = Variable<DateTime>(daycareFrom);
    }
    if (!nullToAbsent || daycareLesson != null) {
      map['daycare_lesson'] = Variable<String>(daycareLesson);
    }
    if (!nullToAbsent || daycareRecitalStats != null) {
      map['daycare_recital_stats'] = Variable<String>(daycareRecitalStats);
    }
    if (!nullToAbsent || recitalDays != null) {
      map['recital_days'] = Variable<String>(recitalDays);
    }
    if (!nullToAbsent || wish != null) {
      map['wish'] = Variable<String>(wish);
    }
    if (!nullToAbsent || wishDay != null) {
      map['wish_day'] = Variable<String>(wishDay);
    }
    map['wish_done'] = Variable<bool>(wishDone);
    map['paws'] = Variable<int>(paws);
    map['paws_today'] = Variable<int>(pawsToday);
    if (!nullToAbsent || pawsDay != null) {
      map['paws_day'] = Variable<String>(pawsDay);
    }
    if (!nullToAbsent || pawMarks != null) {
      map['paw_marks'] = Variable<String>(pawMarks);
    }
    if (!nullToAbsent || eveningDay != null) {
      map['evening_day'] = Variable<String>(eveningDay);
    }
    if (!nullToAbsent || rug != null) {
      map['rug'] = Variable<String>(rug);
    }
    if (!nullToAbsent || owned != null) {
      map['owned'] = Variable<String>(owned);
    }
    if (!nullToAbsent || touchX != null) {
      map['touch_x'] = Variable<double>(touchX);
    }
    if (!nullToAbsent || quirk != null) {
      map['quirk'] = Variable<String>(quirk);
    }
    if (!nullToAbsent || doorNews != null) {
      map['door_news'] = Variable<String>(doorNews);
    }
    if (!nullToAbsent || habit != null) {
      map['habit'] = Variable<String>(habit);
    }
    if (!nullToAbsent || treatsTried != null) {
      map['treats_tried'] = Variable<String>(treatsTried);
    }
    if (!nullToAbsent || treatShares != null) {
      map['treat_shares'] = Variable<String>(treatShares);
    }
    if (!nullToAbsent || treatPouch != null) {
      map['treat_pouch'] = Variable<String>(treatPouch);
    }
    if (!nullToAbsent || treatDay != null) {
      map['treat_day'] = Variable<String>(treatDay);
    }
    if (!nullToAbsent || checkupAt != null) {
      map['checkup_at'] = Variable<DateTime>(checkupAt);
    }
    map['checkups'] = Variable<int>(checkups);
    if (!nullToAbsent || lastWeight != null) {
      map['last_weight'] = Variable<double>(lastWeight);
    }
    return map;
  }

  PetsCompanion toCompanion(bool nullToAbsent) {
    return PetsCompanion(
      id: Value(id),
      name: Value(name),
      stage: Value(stage),
      furMain: Value(furMain),
      furSecond: Value(furSecond),
      accent: Value(accent),
      marking: Value(marking),
      bornAt: Value(bornAt),
      lastSeenAt: Value(lastSeenAt),
      mood: Value(mood),
      hunger: Value(hunger),
      energy: Value(energy),
      affection: Value(affection),
      careScore: Value(careScore),
      regionName: regionName == null && nullToAbsent
          ? const Value.absent()
          : Value(regionName),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      portraitPath: portraitPath == null && nullToAbsent
          ? const Value.absent()
          : Value(portraitPath),
      shape: Value(shape),
      countDay: countDay == null && nullToAbsent
          ? const Value.absent()
          : Value(countDay),
      bondToday: Value(bondToday),
      talksToday: Value(talksToday),
      activity: activity == null && nullToAbsent
          ? const Value.absent()
          : Value(activity),
      attachment: attachment == null && nullToAbsent
          ? const Value.absent()
          : Value(attachment),
      rhythm: rhythm == null && nullToAbsent
          ? const Value.absent()
          : Value(rhythm),
      likeTaste: likeTaste == null && nullToAbsent
          ? const Value.absent()
          : Value(likeTaste),
      dislikeTaste: dislikeTaste == null && nullToAbsent
          ? const Value.absent()
          : Value(dislikeTaste),
      lastStepTotal: lastStepTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStepTotal),
      pocketDay: pocketDay == null && nullToAbsent
          ? const Value.absent()
          : Value(pocketDay),
      pocketCount: Value(pocketCount),
      windowNight: windowNight == null && nullToAbsent
          ? const Value.absent()
          : Value(windowNight),
      giftDay: giftDay == null && nullToAbsent
          ? const Value.absent()
          : Value(giftDay),
      snowDay: snowDay == null && nullToAbsent
          ? const Value.absent()
          : Value(snowDay),
      comfortDue: Value(comfortDue),
      comfortDay: comfortDay == null && nullToAbsent
          ? const Value.absent()
          : Value(comfortDay),
      pottyAt: pottyAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pottyAt),
      lastCrisisAt: lastCrisisAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCrisisAt),
      daycareFrom: daycareFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(daycareFrom),
      daycareLesson: daycareLesson == null && nullToAbsent
          ? const Value.absent()
          : Value(daycareLesson),
      daycareRecitalStats: daycareRecitalStats == null && nullToAbsent
          ? const Value.absent()
          : Value(daycareRecitalStats),
      recitalDays: recitalDays == null && nullToAbsent
          ? const Value.absent()
          : Value(recitalDays),
      wish: wish == null && nullToAbsent ? const Value.absent() : Value(wish),
      wishDay: wishDay == null && nullToAbsent
          ? const Value.absent()
          : Value(wishDay),
      wishDone: Value(wishDone),
      paws: Value(paws),
      pawsToday: Value(pawsToday),
      pawsDay: pawsDay == null && nullToAbsent
          ? const Value.absent()
          : Value(pawsDay),
      pawMarks: pawMarks == null && nullToAbsent
          ? const Value.absent()
          : Value(pawMarks),
      eveningDay: eveningDay == null && nullToAbsent
          ? const Value.absent()
          : Value(eveningDay),
      rug: rug == null && nullToAbsent ? const Value.absent() : Value(rug),
      owned: owned == null && nullToAbsent
          ? const Value.absent()
          : Value(owned),
      touchX: touchX == null && nullToAbsent
          ? const Value.absent()
          : Value(touchX),
      quirk: quirk == null && nullToAbsent
          ? const Value.absent()
          : Value(quirk),
      doorNews: doorNews == null && nullToAbsent
          ? const Value.absent()
          : Value(doorNews),
      habit: habit == null && nullToAbsent
          ? const Value.absent()
          : Value(habit),
      treatsTried: treatsTried == null && nullToAbsent
          ? const Value.absent()
          : Value(treatsTried),
      treatShares: treatShares == null && nullToAbsent
          ? const Value.absent()
          : Value(treatShares),
      treatPouch: treatPouch == null && nullToAbsent
          ? const Value.absent()
          : Value(treatPouch),
      treatDay: treatDay == null && nullToAbsent
          ? const Value.absent()
          : Value(treatDay),
      checkupAt: checkupAt == null && nullToAbsent
          ? const Value.absent()
          : Value(checkupAt),
      checkups: Value(checkups),
      lastWeight: lastWeight == null && nullToAbsent
          ? const Value.absent()
          : Value(lastWeight),
    );
  }

  factory Pet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pet(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      stage: $PetsTable.$converterstage.fromJson(
        serializer.fromJson<String>(json['stage']),
      ),
      furMain: serializer.fromJson<int>(json['furMain']),
      furSecond: serializer.fromJson<int>(json['furSecond']),
      accent: serializer.fromJson<int>(json['accent']),
      marking: serializer.fromJson<int>(json['marking']),
      bornAt: serializer.fromJson<DateTime>(json['bornAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
      mood: serializer.fromJson<double>(json['mood']),
      hunger: serializer.fromJson<double>(json['hunger']),
      energy: serializer.fromJson<double>(json['energy']),
      affection: serializer.fromJson<double>(json['affection']),
      careScore: serializer.fromJson<double>(json['careScore']),
      regionName: serializer.fromJson<String?>(json['regionName']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      portraitPath: serializer.fromJson<String?>(json['portraitPath']),
      shape: serializer.fromJson<String>(json['shape']),
      countDay: serializer.fromJson<String?>(json['countDay']),
      bondToday: serializer.fromJson<double>(json['bondToday']),
      talksToday: serializer.fromJson<int>(json['talksToday']),
      activity: serializer.fromJson<double?>(json['activity']),
      attachment: serializer.fromJson<double?>(json['attachment']),
      rhythm: serializer.fromJson<String?>(json['rhythm']),
      likeTaste: $PetsTable.$converterlikeTasten.fromJson(
        serializer.fromJson<String?>(json['likeTaste']),
      ),
      dislikeTaste: $PetsTable.$converterdislikeTasten.fromJson(
        serializer.fromJson<String?>(json['dislikeTaste']),
      ),
      lastStepTotal: serializer.fromJson<int?>(json['lastStepTotal']),
      pocketDay: serializer.fromJson<String?>(json['pocketDay']),
      pocketCount: serializer.fromJson<int>(json['pocketCount']),
      windowNight: serializer.fromJson<String?>(json['windowNight']),
      giftDay: serializer.fromJson<String?>(json['giftDay']),
      snowDay: serializer.fromJson<String?>(json['snowDay']),
      comfortDue: serializer.fromJson<bool>(json['comfortDue']),
      comfortDay: serializer.fromJson<String?>(json['comfortDay']),
      pottyAt: serializer.fromJson<DateTime?>(json['pottyAt']),
      lastCrisisAt: serializer.fromJson<DateTime?>(json['lastCrisisAt']),
      daycareFrom: serializer.fromJson<DateTime?>(json['daycareFrom']),
      daycareLesson: serializer.fromJson<String?>(json['daycareLesson']),
      daycareRecitalStats: serializer.fromJson<String?>(
        json['daycareRecitalStats'],
      ),
      recitalDays: serializer.fromJson<String?>(json['recitalDays']),
      wish: serializer.fromJson<String?>(json['wish']),
      wishDay: serializer.fromJson<String?>(json['wishDay']),
      wishDone: serializer.fromJson<bool>(json['wishDone']),
      paws: serializer.fromJson<int>(json['paws']),
      pawsToday: serializer.fromJson<int>(json['pawsToday']),
      pawsDay: serializer.fromJson<String?>(json['pawsDay']),
      pawMarks: serializer.fromJson<String?>(json['pawMarks']),
      eveningDay: serializer.fromJson<String?>(json['eveningDay']),
      rug: serializer.fromJson<String?>(json['rug']),
      owned: serializer.fromJson<String?>(json['owned']),
      touchX: serializer.fromJson<double?>(json['touchX']),
      quirk: serializer.fromJson<String?>(json['quirk']),
      doorNews: serializer.fromJson<String?>(json['doorNews']),
      habit: serializer.fromJson<String?>(json['habit']),
      treatsTried: serializer.fromJson<String?>(json['treatsTried']),
      treatShares: serializer.fromJson<String?>(json['treatShares']),
      treatPouch: serializer.fromJson<String?>(json['treatPouch']),
      treatDay: serializer.fromJson<String?>(json['treatDay']),
      checkupAt: serializer.fromJson<DateTime?>(json['checkupAt']),
      checkups: serializer.fromJson<int>(json['checkups']),
      lastWeight: serializer.fromJson<double?>(json['lastWeight']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'stage': serializer.toJson<String>(
        $PetsTable.$converterstage.toJson(stage),
      ),
      'furMain': serializer.toJson<int>(furMain),
      'furSecond': serializer.toJson<int>(furSecond),
      'accent': serializer.toJson<int>(accent),
      'marking': serializer.toJson<int>(marking),
      'bornAt': serializer.toJson<DateTime>(bornAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
      'mood': serializer.toJson<double>(mood),
      'hunger': serializer.toJson<double>(hunger),
      'energy': serializer.toJson<double>(energy),
      'affection': serializer.toJson<double>(affection),
      'careScore': serializer.toJson<double>(careScore),
      'regionName': serializer.toJson<String?>(regionName),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'portraitPath': serializer.toJson<String?>(portraitPath),
      'shape': serializer.toJson<String>(shape),
      'countDay': serializer.toJson<String?>(countDay),
      'bondToday': serializer.toJson<double>(bondToday),
      'talksToday': serializer.toJson<int>(talksToday),
      'activity': serializer.toJson<double?>(activity),
      'attachment': serializer.toJson<double?>(attachment),
      'rhythm': serializer.toJson<String?>(rhythm),
      'likeTaste': serializer.toJson<String?>(
        $PetsTable.$converterlikeTasten.toJson(likeTaste),
      ),
      'dislikeTaste': serializer.toJson<String?>(
        $PetsTable.$converterdislikeTasten.toJson(dislikeTaste),
      ),
      'lastStepTotal': serializer.toJson<int?>(lastStepTotal),
      'pocketDay': serializer.toJson<String?>(pocketDay),
      'pocketCount': serializer.toJson<int>(pocketCount),
      'windowNight': serializer.toJson<String?>(windowNight),
      'giftDay': serializer.toJson<String?>(giftDay),
      'snowDay': serializer.toJson<String?>(snowDay),
      'comfortDue': serializer.toJson<bool>(comfortDue),
      'comfortDay': serializer.toJson<String?>(comfortDay),
      'pottyAt': serializer.toJson<DateTime?>(pottyAt),
      'lastCrisisAt': serializer.toJson<DateTime?>(lastCrisisAt),
      'daycareFrom': serializer.toJson<DateTime?>(daycareFrom),
      'daycareLesson': serializer.toJson<String?>(daycareLesson),
      'daycareRecitalStats': serializer.toJson<String?>(daycareRecitalStats),
      'recitalDays': serializer.toJson<String?>(recitalDays),
      'wish': serializer.toJson<String?>(wish),
      'wishDay': serializer.toJson<String?>(wishDay),
      'wishDone': serializer.toJson<bool>(wishDone),
      'paws': serializer.toJson<int>(paws),
      'pawsToday': serializer.toJson<int>(pawsToday),
      'pawsDay': serializer.toJson<String?>(pawsDay),
      'pawMarks': serializer.toJson<String?>(pawMarks),
      'eveningDay': serializer.toJson<String?>(eveningDay),
      'rug': serializer.toJson<String?>(rug),
      'owned': serializer.toJson<String?>(owned),
      'touchX': serializer.toJson<double?>(touchX),
      'quirk': serializer.toJson<String?>(quirk),
      'doorNews': serializer.toJson<String?>(doorNews),
      'habit': serializer.toJson<String?>(habit),
      'treatsTried': serializer.toJson<String?>(treatsTried),
      'treatShares': serializer.toJson<String?>(treatShares),
      'treatPouch': serializer.toJson<String?>(treatPouch),
      'treatDay': serializer.toJson<String?>(treatDay),
      'checkupAt': serializer.toJson<DateTime?>(checkupAt),
      'checkups': serializer.toJson<int>(checkups),
      'lastWeight': serializer.toJson<double?>(lastWeight),
    };
  }

  Pet copyWith({
    int? id,
    String? name,
    PetStage? stage,
    int? furMain,
    int? furSecond,
    int? accent,
    int? marking,
    DateTime? bornAt,
    DateTime? lastSeenAt,
    double? mood,
    double? hunger,
    double? energy,
    double? affection,
    double? careScore,
    Value<String?> regionName = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<String?> portraitPath = const Value.absent(),
    String? shape,
    Value<String?> countDay = const Value.absent(),
    double? bondToday,
    int? talksToday,
    Value<double?> activity = const Value.absent(),
    Value<double?> attachment = const Value.absent(),
    Value<String?> rhythm = const Value.absent(),
    Value<Taste?> likeTaste = const Value.absent(),
    Value<Taste?> dislikeTaste = const Value.absent(),
    Value<int?> lastStepTotal = const Value.absent(),
    Value<String?> pocketDay = const Value.absent(),
    int? pocketCount,
    Value<String?> windowNight = const Value.absent(),
    Value<String?> giftDay = const Value.absent(),
    Value<String?> snowDay = const Value.absent(),
    bool? comfortDue,
    Value<String?> comfortDay = const Value.absent(),
    Value<DateTime?> pottyAt = const Value.absent(),
    Value<DateTime?> lastCrisisAt = const Value.absent(),
    Value<DateTime?> daycareFrom = const Value.absent(),
    Value<String?> daycareLesson = const Value.absent(),
    Value<String?> daycareRecitalStats = const Value.absent(),
    Value<String?> recitalDays = const Value.absent(),
    Value<String?> wish = const Value.absent(),
    Value<String?> wishDay = const Value.absent(),
    bool? wishDone,
    int? paws,
    int? pawsToday,
    Value<String?> pawsDay = const Value.absent(),
    Value<String?> pawMarks = const Value.absent(),
    Value<String?> eveningDay = const Value.absent(),
    Value<String?> rug = const Value.absent(),
    Value<String?> owned = const Value.absent(),
    Value<double?> touchX = const Value.absent(),
    Value<String?> quirk = const Value.absent(),
    Value<String?> doorNews = const Value.absent(),
    Value<String?> habit = const Value.absent(),
    Value<String?> treatsTried = const Value.absent(),
    Value<String?> treatShares = const Value.absent(),
    Value<String?> treatPouch = const Value.absent(),
    Value<String?> treatDay = const Value.absent(),
    Value<DateTime?> checkupAt = const Value.absent(),
    int? checkups,
    Value<double?> lastWeight = const Value.absent(),
  }) => Pet(
    id: id ?? this.id,
    name: name ?? this.name,
    stage: stage ?? this.stage,
    furMain: furMain ?? this.furMain,
    furSecond: furSecond ?? this.furSecond,
    accent: accent ?? this.accent,
    marking: marking ?? this.marking,
    bornAt: bornAt ?? this.bornAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    mood: mood ?? this.mood,
    hunger: hunger ?? this.hunger,
    energy: energy ?? this.energy,
    affection: affection ?? this.affection,
    careScore: careScore ?? this.careScore,
    regionName: regionName.present ? regionName.value : this.regionName,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    portraitPath: portraitPath.present ? portraitPath.value : this.portraitPath,
    shape: shape ?? this.shape,
    countDay: countDay.present ? countDay.value : this.countDay,
    bondToday: bondToday ?? this.bondToday,
    talksToday: talksToday ?? this.talksToday,
    activity: activity.present ? activity.value : this.activity,
    attachment: attachment.present ? attachment.value : this.attachment,
    rhythm: rhythm.present ? rhythm.value : this.rhythm,
    likeTaste: likeTaste.present ? likeTaste.value : this.likeTaste,
    dislikeTaste: dislikeTaste.present ? dislikeTaste.value : this.dislikeTaste,
    lastStepTotal: lastStepTotal.present
        ? lastStepTotal.value
        : this.lastStepTotal,
    pocketDay: pocketDay.present ? pocketDay.value : this.pocketDay,
    pocketCount: pocketCount ?? this.pocketCount,
    windowNight: windowNight.present ? windowNight.value : this.windowNight,
    giftDay: giftDay.present ? giftDay.value : this.giftDay,
    snowDay: snowDay.present ? snowDay.value : this.snowDay,
    comfortDue: comfortDue ?? this.comfortDue,
    comfortDay: comfortDay.present ? comfortDay.value : this.comfortDay,
    pottyAt: pottyAt.present ? pottyAt.value : this.pottyAt,
    lastCrisisAt: lastCrisisAt.present ? lastCrisisAt.value : this.lastCrisisAt,
    daycareFrom: daycareFrom.present ? daycareFrom.value : this.daycareFrom,
    daycareLesson: daycareLesson.present
        ? daycareLesson.value
        : this.daycareLesson,
    daycareRecitalStats: daycareRecitalStats.present
        ? daycareRecitalStats.value
        : this.daycareRecitalStats,
    recitalDays: recitalDays.present ? recitalDays.value : this.recitalDays,
    wish: wish.present ? wish.value : this.wish,
    wishDay: wishDay.present ? wishDay.value : this.wishDay,
    wishDone: wishDone ?? this.wishDone,
    paws: paws ?? this.paws,
    pawsToday: pawsToday ?? this.pawsToday,
    pawsDay: pawsDay.present ? pawsDay.value : this.pawsDay,
    pawMarks: pawMarks.present ? pawMarks.value : this.pawMarks,
    eveningDay: eveningDay.present ? eveningDay.value : this.eveningDay,
    rug: rug.present ? rug.value : this.rug,
    owned: owned.present ? owned.value : this.owned,
    touchX: touchX.present ? touchX.value : this.touchX,
    quirk: quirk.present ? quirk.value : this.quirk,
    doorNews: doorNews.present ? doorNews.value : this.doorNews,
    habit: habit.present ? habit.value : this.habit,
    treatsTried: treatsTried.present ? treatsTried.value : this.treatsTried,
    treatShares: treatShares.present ? treatShares.value : this.treatShares,
    treatPouch: treatPouch.present ? treatPouch.value : this.treatPouch,
    treatDay: treatDay.present ? treatDay.value : this.treatDay,
    checkupAt: checkupAt.present ? checkupAt.value : this.checkupAt,
    checkups: checkups ?? this.checkups,
    lastWeight: lastWeight.present ? lastWeight.value : this.lastWeight,
  );
  Pet copyWithCompanion(PetsCompanion data) {
    return Pet(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      stage: data.stage.present ? data.stage.value : this.stage,
      furMain: data.furMain.present ? data.furMain.value : this.furMain,
      furSecond: data.furSecond.present ? data.furSecond.value : this.furSecond,
      accent: data.accent.present ? data.accent.value : this.accent,
      marking: data.marking.present ? data.marking.value : this.marking,
      bornAt: data.bornAt.present ? data.bornAt.value : this.bornAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      mood: data.mood.present ? data.mood.value : this.mood,
      hunger: data.hunger.present ? data.hunger.value : this.hunger,
      energy: data.energy.present ? data.energy.value : this.energy,
      affection: data.affection.present ? data.affection.value : this.affection,
      careScore: data.careScore.present ? data.careScore.value : this.careScore,
      regionName: data.regionName.present
          ? data.regionName.value
          : this.regionName,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      portraitPath: data.portraitPath.present
          ? data.portraitPath.value
          : this.portraitPath,
      shape: data.shape.present ? data.shape.value : this.shape,
      countDay: data.countDay.present ? data.countDay.value : this.countDay,
      bondToday: data.bondToday.present ? data.bondToday.value : this.bondToday,
      talksToday: data.talksToday.present
          ? data.talksToday.value
          : this.talksToday,
      activity: data.activity.present ? data.activity.value : this.activity,
      attachment: data.attachment.present
          ? data.attachment.value
          : this.attachment,
      rhythm: data.rhythm.present ? data.rhythm.value : this.rhythm,
      likeTaste: data.likeTaste.present ? data.likeTaste.value : this.likeTaste,
      dislikeTaste: data.dislikeTaste.present
          ? data.dislikeTaste.value
          : this.dislikeTaste,
      lastStepTotal: data.lastStepTotal.present
          ? data.lastStepTotal.value
          : this.lastStepTotal,
      pocketDay: data.pocketDay.present ? data.pocketDay.value : this.pocketDay,
      pocketCount: data.pocketCount.present
          ? data.pocketCount.value
          : this.pocketCount,
      windowNight: data.windowNight.present
          ? data.windowNight.value
          : this.windowNight,
      giftDay: data.giftDay.present ? data.giftDay.value : this.giftDay,
      snowDay: data.snowDay.present ? data.snowDay.value : this.snowDay,
      comfortDue: data.comfortDue.present
          ? data.comfortDue.value
          : this.comfortDue,
      comfortDay: data.comfortDay.present
          ? data.comfortDay.value
          : this.comfortDay,
      pottyAt: data.pottyAt.present ? data.pottyAt.value : this.pottyAt,
      lastCrisisAt: data.lastCrisisAt.present
          ? data.lastCrisisAt.value
          : this.lastCrisisAt,
      daycareFrom: data.daycareFrom.present
          ? data.daycareFrom.value
          : this.daycareFrom,
      daycareLesson: data.daycareLesson.present
          ? data.daycareLesson.value
          : this.daycareLesson,
      daycareRecitalStats: data.daycareRecitalStats.present
          ? data.daycareRecitalStats.value
          : this.daycareRecitalStats,
      recitalDays: data.recitalDays.present
          ? data.recitalDays.value
          : this.recitalDays,
      wish: data.wish.present ? data.wish.value : this.wish,
      wishDay: data.wishDay.present ? data.wishDay.value : this.wishDay,
      wishDone: data.wishDone.present ? data.wishDone.value : this.wishDone,
      paws: data.paws.present ? data.paws.value : this.paws,
      pawsToday: data.pawsToday.present ? data.pawsToday.value : this.pawsToday,
      pawsDay: data.pawsDay.present ? data.pawsDay.value : this.pawsDay,
      pawMarks: data.pawMarks.present ? data.pawMarks.value : this.pawMarks,
      eveningDay: data.eveningDay.present
          ? data.eveningDay.value
          : this.eveningDay,
      rug: data.rug.present ? data.rug.value : this.rug,
      owned: data.owned.present ? data.owned.value : this.owned,
      touchX: data.touchX.present ? data.touchX.value : this.touchX,
      quirk: data.quirk.present ? data.quirk.value : this.quirk,
      doorNews: data.doorNews.present ? data.doorNews.value : this.doorNews,
      habit: data.habit.present ? data.habit.value : this.habit,
      treatsTried: data.treatsTried.present
          ? data.treatsTried.value
          : this.treatsTried,
      treatShares: data.treatShares.present
          ? data.treatShares.value
          : this.treatShares,
      treatPouch: data.treatPouch.present
          ? data.treatPouch.value
          : this.treatPouch,
      treatDay: data.treatDay.present ? data.treatDay.value : this.treatDay,
      checkupAt: data.checkupAt.present ? data.checkupAt.value : this.checkupAt,
      checkups: data.checkups.present ? data.checkups.value : this.checkups,
      lastWeight: data.lastWeight.present
          ? data.lastWeight.value
          : this.lastWeight,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pet(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('stage: $stage, ')
          ..write('furMain: $furMain, ')
          ..write('furSecond: $furSecond, ')
          ..write('accent: $accent, ')
          ..write('marking: $marking, ')
          ..write('bornAt: $bornAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('mood: $mood, ')
          ..write('hunger: $hunger, ')
          ..write('energy: $energy, ')
          ..write('affection: $affection, ')
          ..write('careScore: $careScore, ')
          ..write('regionName: $regionName, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('portraitPath: $portraitPath, ')
          ..write('shape: $shape, ')
          ..write('countDay: $countDay, ')
          ..write('bondToday: $bondToday, ')
          ..write('talksToday: $talksToday, ')
          ..write('activity: $activity, ')
          ..write('attachment: $attachment, ')
          ..write('rhythm: $rhythm, ')
          ..write('likeTaste: $likeTaste, ')
          ..write('dislikeTaste: $dislikeTaste, ')
          ..write('lastStepTotal: $lastStepTotal, ')
          ..write('pocketDay: $pocketDay, ')
          ..write('pocketCount: $pocketCount, ')
          ..write('windowNight: $windowNight, ')
          ..write('giftDay: $giftDay, ')
          ..write('snowDay: $snowDay, ')
          ..write('comfortDue: $comfortDue, ')
          ..write('comfortDay: $comfortDay, ')
          ..write('pottyAt: $pottyAt, ')
          ..write('lastCrisisAt: $lastCrisisAt, ')
          ..write('daycareFrom: $daycareFrom, ')
          ..write('daycareLesson: $daycareLesson, ')
          ..write('daycareRecitalStats: $daycareRecitalStats, ')
          ..write('recitalDays: $recitalDays, ')
          ..write('wish: $wish, ')
          ..write('wishDay: $wishDay, ')
          ..write('wishDone: $wishDone, ')
          ..write('paws: $paws, ')
          ..write('pawsToday: $pawsToday, ')
          ..write('pawsDay: $pawsDay, ')
          ..write('pawMarks: $pawMarks, ')
          ..write('eveningDay: $eveningDay, ')
          ..write('rug: $rug, ')
          ..write('owned: $owned, ')
          ..write('touchX: $touchX, ')
          ..write('quirk: $quirk, ')
          ..write('doorNews: $doorNews, ')
          ..write('habit: $habit, ')
          ..write('treatsTried: $treatsTried, ')
          ..write('treatShares: $treatShares, ')
          ..write('treatPouch: $treatPouch, ')
          ..write('treatDay: $treatDay, ')
          ..write('checkupAt: $checkupAt, ')
          ..write('checkups: $checkups, ')
          ..write('lastWeight: $lastWeight')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    stage,
    furMain,
    furSecond,
    accent,
    marking,
    bornAt,
    lastSeenAt,
    mood,
    hunger,
    energy,
    affection,
    careScore,
    regionName,
    latitude,
    longitude,
    portraitPath,
    shape,
    countDay,
    bondToday,
    talksToday,
    activity,
    attachment,
    rhythm,
    likeTaste,
    dislikeTaste,
    lastStepTotal,
    pocketDay,
    pocketCount,
    windowNight,
    giftDay,
    snowDay,
    comfortDue,
    comfortDay,
    pottyAt,
    lastCrisisAt,
    daycareFrom,
    daycareLesson,
    daycareRecitalStats,
    recitalDays,
    wish,
    wishDay,
    wishDone,
    paws,
    pawsToday,
    pawsDay,
    pawMarks,
    eveningDay,
    rug,
    owned,
    touchX,
    quirk,
    doorNews,
    habit,
    treatsTried,
    treatShares,
    treatPouch,
    treatDay,
    checkupAt,
    checkups,
    lastWeight,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pet &&
          other.id == this.id &&
          other.name == this.name &&
          other.stage == this.stage &&
          other.furMain == this.furMain &&
          other.furSecond == this.furSecond &&
          other.accent == this.accent &&
          other.marking == this.marking &&
          other.bornAt == this.bornAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.mood == this.mood &&
          other.hunger == this.hunger &&
          other.energy == this.energy &&
          other.affection == this.affection &&
          other.careScore == this.careScore &&
          other.regionName == this.regionName &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.portraitPath == this.portraitPath &&
          other.shape == this.shape &&
          other.countDay == this.countDay &&
          other.bondToday == this.bondToday &&
          other.talksToday == this.talksToday &&
          other.activity == this.activity &&
          other.attachment == this.attachment &&
          other.rhythm == this.rhythm &&
          other.likeTaste == this.likeTaste &&
          other.dislikeTaste == this.dislikeTaste &&
          other.lastStepTotal == this.lastStepTotal &&
          other.pocketDay == this.pocketDay &&
          other.pocketCount == this.pocketCount &&
          other.windowNight == this.windowNight &&
          other.giftDay == this.giftDay &&
          other.snowDay == this.snowDay &&
          other.comfortDue == this.comfortDue &&
          other.comfortDay == this.comfortDay &&
          other.pottyAt == this.pottyAt &&
          other.lastCrisisAt == this.lastCrisisAt &&
          other.daycareFrom == this.daycareFrom &&
          other.daycareLesson == this.daycareLesson &&
          other.daycareRecitalStats == this.daycareRecitalStats &&
          other.recitalDays == this.recitalDays &&
          other.wish == this.wish &&
          other.wishDay == this.wishDay &&
          other.wishDone == this.wishDone &&
          other.paws == this.paws &&
          other.pawsToday == this.pawsToday &&
          other.pawsDay == this.pawsDay &&
          other.pawMarks == this.pawMarks &&
          other.eveningDay == this.eveningDay &&
          other.rug == this.rug &&
          other.owned == this.owned &&
          other.touchX == this.touchX &&
          other.quirk == this.quirk &&
          other.doorNews == this.doorNews &&
          other.habit == this.habit &&
          other.treatsTried == this.treatsTried &&
          other.treatShares == this.treatShares &&
          other.treatPouch == this.treatPouch &&
          other.treatDay == this.treatDay &&
          other.checkupAt == this.checkupAt &&
          other.checkups == this.checkups &&
          other.lastWeight == this.lastWeight);
}

class PetsCompanion extends UpdateCompanion<Pet> {
  final Value<int> id;
  final Value<String> name;
  final Value<PetStage> stage;
  final Value<int> furMain;
  final Value<int> furSecond;
  final Value<int> accent;
  final Value<int> marking;
  final Value<DateTime> bornAt;
  final Value<DateTime> lastSeenAt;
  final Value<double> mood;
  final Value<double> hunger;
  final Value<double> energy;
  final Value<double> affection;
  final Value<double> careScore;
  final Value<String?> regionName;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> portraitPath;
  final Value<String> shape;
  final Value<String?> countDay;
  final Value<double> bondToday;
  final Value<int> talksToday;
  final Value<double?> activity;
  final Value<double?> attachment;
  final Value<String?> rhythm;
  final Value<Taste?> likeTaste;
  final Value<Taste?> dislikeTaste;
  final Value<int?> lastStepTotal;
  final Value<String?> pocketDay;
  final Value<int> pocketCount;
  final Value<String?> windowNight;
  final Value<String?> giftDay;
  final Value<String?> snowDay;
  final Value<bool> comfortDue;
  final Value<String?> comfortDay;
  final Value<DateTime?> pottyAt;
  final Value<DateTime?> lastCrisisAt;
  final Value<DateTime?> daycareFrom;
  final Value<String?> daycareLesson;
  final Value<String?> daycareRecitalStats;
  final Value<String?> recitalDays;
  final Value<String?> wish;
  final Value<String?> wishDay;
  final Value<bool> wishDone;
  final Value<int> paws;
  final Value<int> pawsToday;
  final Value<String?> pawsDay;
  final Value<String?> pawMarks;
  final Value<String?> eveningDay;
  final Value<String?> rug;
  final Value<String?> owned;
  final Value<double?> touchX;
  final Value<String?> quirk;
  final Value<String?> doorNews;
  final Value<String?> habit;
  final Value<String?> treatsTried;
  final Value<String?> treatShares;
  final Value<String?> treatPouch;
  final Value<String?> treatDay;
  final Value<DateTime?> checkupAt;
  final Value<int> checkups;
  final Value<double?> lastWeight;
  const PetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.stage = const Value.absent(),
    this.furMain = const Value.absent(),
    this.furSecond = const Value.absent(),
    this.accent = const Value.absent(),
    this.marking = const Value.absent(),
    this.bornAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.mood = const Value.absent(),
    this.hunger = const Value.absent(),
    this.energy = const Value.absent(),
    this.affection = const Value.absent(),
    this.careScore = const Value.absent(),
    this.regionName = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.portraitPath = const Value.absent(),
    this.shape = const Value.absent(),
    this.countDay = const Value.absent(),
    this.bondToday = const Value.absent(),
    this.talksToday = const Value.absent(),
    this.activity = const Value.absent(),
    this.attachment = const Value.absent(),
    this.rhythm = const Value.absent(),
    this.likeTaste = const Value.absent(),
    this.dislikeTaste = const Value.absent(),
    this.lastStepTotal = const Value.absent(),
    this.pocketDay = const Value.absent(),
    this.pocketCount = const Value.absent(),
    this.windowNight = const Value.absent(),
    this.giftDay = const Value.absent(),
    this.snowDay = const Value.absent(),
    this.comfortDue = const Value.absent(),
    this.comfortDay = const Value.absent(),
    this.pottyAt = const Value.absent(),
    this.lastCrisisAt = const Value.absent(),
    this.daycareFrom = const Value.absent(),
    this.daycareLesson = const Value.absent(),
    this.daycareRecitalStats = const Value.absent(),
    this.recitalDays = const Value.absent(),
    this.wish = const Value.absent(),
    this.wishDay = const Value.absent(),
    this.wishDone = const Value.absent(),
    this.paws = const Value.absent(),
    this.pawsToday = const Value.absent(),
    this.pawsDay = const Value.absent(),
    this.pawMarks = const Value.absent(),
    this.eveningDay = const Value.absent(),
    this.rug = const Value.absent(),
    this.owned = const Value.absent(),
    this.touchX = const Value.absent(),
    this.quirk = const Value.absent(),
    this.doorNews = const Value.absent(),
    this.habit = const Value.absent(),
    this.treatsTried = const Value.absent(),
    this.treatShares = const Value.absent(),
    this.treatPouch = const Value.absent(),
    this.treatDay = const Value.absent(),
    this.checkupAt = const Value.absent(),
    this.checkups = const Value.absent(),
    this.lastWeight = const Value.absent(),
  });
  PetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required PetStage stage,
    required int furMain,
    required int furSecond,
    required int accent,
    this.marking = const Value.absent(),
    required DateTime bornAt,
    required DateTime lastSeenAt,
    required double mood,
    required double hunger,
    required double energy,
    required double affection,
    this.careScore = const Value.absent(),
    this.regionName = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.portraitPath = const Value.absent(),
    this.shape = const Value.absent(),
    this.countDay = const Value.absent(),
    this.bondToday = const Value.absent(),
    this.talksToday = const Value.absent(),
    this.activity = const Value.absent(),
    this.attachment = const Value.absent(),
    this.rhythm = const Value.absent(),
    this.likeTaste = const Value.absent(),
    this.dislikeTaste = const Value.absent(),
    this.lastStepTotal = const Value.absent(),
    this.pocketDay = const Value.absent(),
    this.pocketCount = const Value.absent(),
    this.windowNight = const Value.absent(),
    this.giftDay = const Value.absent(),
    this.snowDay = const Value.absent(),
    this.comfortDue = const Value.absent(),
    this.comfortDay = const Value.absent(),
    this.pottyAt = const Value.absent(),
    this.lastCrisisAt = const Value.absent(),
    this.daycareFrom = const Value.absent(),
    this.daycareLesson = const Value.absent(),
    this.daycareRecitalStats = const Value.absent(),
    this.recitalDays = const Value.absent(),
    this.wish = const Value.absent(),
    this.wishDay = const Value.absent(),
    this.wishDone = const Value.absent(),
    this.paws = const Value.absent(),
    this.pawsToday = const Value.absent(),
    this.pawsDay = const Value.absent(),
    this.pawMarks = const Value.absent(),
    this.eveningDay = const Value.absent(),
    this.rug = const Value.absent(),
    this.owned = const Value.absent(),
    this.touchX = const Value.absent(),
    this.quirk = const Value.absent(),
    this.doorNews = const Value.absent(),
    this.habit = const Value.absent(),
    this.treatsTried = const Value.absent(),
    this.treatShares = const Value.absent(),
    this.treatPouch = const Value.absent(),
    this.treatDay = const Value.absent(),
    this.checkupAt = const Value.absent(),
    this.checkups = const Value.absent(),
    this.lastWeight = const Value.absent(),
  }) : name = Value(name),
       stage = Value(stage),
       furMain = Value(furMain),
       furSecond = Value(furSecond),
       accent = Value(accent),
       bornAt = Value(bornAt),
       lastSeenAt = Value(lastSeenAt),
       mood = Value(mood),
       hunger = Value(hunger),
       energy = Value(energy),
       affection = Value(affection);
  static Insertable<Pet> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? stage,
    Expression<int>? furMain,
    Expression<int>? furSecond,
    Expression<int>? accent,
    Expression<int>? marking,
    Expression<DateTime>? bornAt,
    Expression<DateTime>? lastSeenAt,
    Expression<double>? mood,
    Expression<double>? hunger,
    Expression<double>? energy,
    Expression<double>? affection,
    Expression<double>? careScore,
    Expression<String>? regionName,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? portraitPath,
    Expression<String>? shape,
    Expression<String>? countDay,
    Expression<double>? bondToday,
    Expression<int>? talksToday,
    Expression<double>? activity,
    Expression<double>? attachment,
    Expression<String>? rhythm,
    Expression<String>? likeTaste,
    Expression<String>? dislikeTaste,
    Expression<int>? lastStepTotal,
    Expression<String>? pocketDay,
    Expression<int>? pocketCount,
    Expression<String>? windowNight,
    Expression<String>? giftDay,
    Expression<String>? snowDay,
    Expression<bool>? comfortDue,
    Expression<String>? comfortDay,
    Expression<DateTime>? pottyAt,
    Expression<DateTime>? lastCrisisAt,
    Expression<DateTime>? daycareFrom,
    Expression<String>? daycareLesson,
    Expression<String>? daycareRecitalStats,
    Expression<String>? recitalDays,
    Expression<String>? wish,
    Expression<String>? wishDay,
    Expression<bool>? wishDone,
    Expression<int>? paws,
    Expression<int>? pawsToday,
    Expression<String>? pawsDay,
    Expression<String>? pawMarks,
    Expression<String>? eveningDay,
    Expression<String>? rug,
    Expression<String>? owned,
    Expression<double>? touchX,
    Expression<String>? quirk,
    Expression<String>? doorNews,
    Expression<String>? habit,
    Expression<String>? treatsTried,
    Expression<String>? treatShares,
    Expression<String>? treatPouch,
    Expression<String>? treatDay,
    Expression<DateTime>? checkupAt,
    Expression<int>? checkups,
    Expression<double>? lastWeight,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (stage != null) 'stage': stage,
      if (furMain != null) 'fur_main': furMain,
      if (furSecond != null) 'fur_second': furSecond,
      if (accent != null) 'accent': accent,
      if (marking != null) 'marking': marking,
      if (bornAt != null) 'born_at': bornAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (mood != null) 'mood': mood,
      if (hunger != null) 'hunger': hunger,
      if (energy != null) 'energy': energy,
      if (affection != null) 'affection': affection,
      if (careScore != null) 'care_score': careScore,
      if (regionName != null) 'region_name': regionName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (portraitPath != null) 'portrait_path': portraitPath,
      if (shape != null) 'shape': shape,
      if (countDay != null) 'count_day': countDay,
      if (bondToday != null) 'bond_today': bondToday,
      if (talksToday != null) 'talks_today': talksToday,
      if (activity != null) 'activity': activity,
      if (attachment != null) 'attachment': attachment,
      if (rhythm != null) 'rhythm': rhythm,
      if (likeTaste != null) 'like_taste': likeTaste,
      if (dislikeTaste != null) 'dislike_taste': dislikeTaste,
      if (lastStepTotal != null) 'last_step_total': lastStepTotal,
      if (pocketDay != null) 'pocket_day': pocketDay,
      if (pocketCount != null) 'pocket_count': pocketCount,
      if (windowNight != null) 'window_night': windowNight,
      if (giftDay != null) 'gift_day': giftDay,
      if (snowDay != null) 'snow_day': snowDay,
      if (comfortDue != null) 'comfort_due': comfortDue,
      if (comfortDay != null) 'comfort_day': comfortDay,
      if (pottyAt != null) 'potty_at': pottyAt,
      if (lastCrisisAt != null) 'last_crisis_at': lastCrisisAt,
      if (daycareFrom != null) 'daycare_from': daycareFrom,
      if (daycareLesson != null) 'daycare_lesson': daycareLesson,
      if (daycareRecitalStats != null)
        'daycare_recital_stats': daycareRecitalStats,
      if (recitalDays != null) 'recital_days': recitalDays,
      if (wish != null) 'wish': wish,
      if (wishDay != null) 'wish_day': wishDay,
      if (wishDone != null) 'wish_done': wishDone,
      if (paws != null) 'paws': paws,
      if (pawsToday != null) 'paws_today': pawsToday,
      if (pawsDay != null) 'paws_day': pawsDay,
      if (pawMarks != null) 'paw_marks': pawMarks,
      if (eveningDay != null) 'evening_day': eveningDay,
      if (rug != null) 'rug': rug,
      if (owned != null) 'owned': owned,
      if (touchX != null) 'touch_x': touchX,
      if (quirk != null) 'quirk': quirk,
      if (doorNews != null) 'door_news': doorNews,
      if (habit != null) 'habit': habit,
      if (treatsTried != null) 'treats_tried': treatsTried,
      if (treatShares != null) 'treat_shares': treatShares,
      if (treatPouch != null) 'treat_pouch': treatPouch,
      if (treatDay != null) 'treat_day': treatDay,
      if (checkupAt != null) 'checkup_at': checkupAt,
      if (checkups != null) 'checkups': checkups,
      if (lastWeight != null) 'last_weight': lastWeight,
    });
  }

  PetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<PetStage>? stage,
    Value<int>? furMain,
    Value<int>? furSecond,
    Value<int>? accent,
    Value<int>? marking,
    Value<DateTime>? bornAt,
    Value<DateTime>? lastSeenAt,
    Value<double>? mood,
    Value<double>? hunger,
    Value<double>? energy,
    Value<double>? affection,
    Value<double>? careScore,
    Value<String?>? regionName,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String?>? portraitPath,
    Value<String>? shape,
    Value<String?>? countDay,
    Value<double>? bondToday,
    Value<int>? talksToday,
    Value<double?>? activity,
    Value<double?>? attachment,
    Value<String?>? rhythm,
    Value<Taste?>? likeTaste,
    Value<Taste?>? dislikeTaste,
    Value<int?>? lastStepTotal,
    Value<String?>? pocketDay,
    Value<int>? pocketCount,
    Value<String?>? windowNight,
    Value<String?>? giftDay,
    Value<String?>? snowDay,
    Value<bool>? comfortDue,
    Value<String?>? comfortDay,
    Value<DateTime?>? pottyAt,
    Value<DateTime?>? lastCrisisAt,
    Value<DateTime?>? daycareFrom,
    Value<String?>? daycareLesson,
    Value<String?>? daycareRecitalStats,
    Value<String?>? recitalDays,
    Value<String?>? wish,
    Value<String?>? wishDay,
    Value<bool>? wishDone,
    Value<int>? paws,
    Value<int>? pawsToday,
    Value<String?>? pawsDay,
    Value<String?>? pawMarks,
    Value<String?>? eveningDay,
    Value<String?>? rug,
    Value<String?>? owned,
    Value<double?>? touchX,
    Value<String?>? quirk,
    Value<String?>? doorNews,
    Value<String?>? habit,
    Value<String?>? treatsTried,
    Value<String?>? treatShares,
    Value<String?>? treatPouch,
    Value<String?>? treatDay,
    Value<DateTime?>? checkupAt,
    Value<int>? checkups,
    Value<double?>? lastWeight,
  }) {
    return PetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      stage: stage ?? this.stage,
      furMain: furMain ?? this.furMain,
      furSecond: furSecond ?? this.furSecond,
      accent: accent ?? this.accent,
      marking: marking ?? this.marking,
      bornAt: bornAt ?? this.bornAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      mood: mood ?? this.mood,
      hunger: hunger ?? this.hunger,
      energy: energy ?? this.energy,
      affection: affection ?? this.affection,
      careScore: careScore ?? this.careScore,
      regionName: regionName ?? this.regionName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      portraitPath: portraitPath ?? this.portraitPath,
      shape: shape ?? this.shape,
      countDay: countDay ?? this.countDay,
      bondToday: bondToday ?? this.bondToday,
      talksToday: talksToday ?? this.talksToday,
      activity: activity ?? this.activity,
      attachment: attachment ?? this.attachment,
      rhythm: rhythm ?? this.rhythm,
      likeTaste: likeTaste ?? this.likeTaste,
      dislikeTaste: dislikeTaste ?? this.dislikeTaste,
      lastStepTotal: lastStepTotal ?? this.lastStepTotal,
      pocketDay: pocketDay ?? this.pocketDay,
      pocketCount: pocketCount ?? this.pocketCount,
      windowNight: windowNight ?? this.windowNight,
      giftDay: giftDay ?? this.giftDay,
      snowDay: snowDay ?? this.snowDay,
      comfortDue: comfortDue ?? this.comfortDue,
      comfortDay: comfortDay ?? this.comfortDay,
      pottyAt: pottyAt ?? this.pottyAt,
      lastCrisisAt: lastCrisisAt ?? this.lastCrisisAt,
      daycareFrom: daycareFrom ?? this.daycareFrom,
      daycareLesson: daycareLesson ?? this.daycareLesson,
      daycareRecitalStats: daycareRecitalStats ?? this.daycareRecitalStats,
      recitalDays: recitalDays ?? this.recitalDays,
      wish: wish ?? this.wish,
      wishDay: wishDay ?? this.wishDay,
      wishDone: wishDone ?? this.wishDone,
      paws: paws ?? this.paws,
      pawsToday: pawsToday ?? this.pawsToday,
      pawsDay: pawsDay ?? this.pawsDay,
      pawMarks: pawMarks ?? this.pawMarks,
      eveningDay: eveningDay ?? this.eveningDay,
      rug: rug ?? this.rug,
      owned: owned ?? this.owned,
      touchX: touchX ?? this.touchX,
      quirk: quirk ?? this.quirk,
      doorNews: doorNews ?? this.doorNews,
      habit: habit ?? this.habit,
      treatsTried: treatsTried ?? this.treatsTried,
      treatShares: treatShares ?? this.treatShares,
      treatPouch: treatPouch ?? this.treatPouch,
      treatDay: treatDay ?? this.treatDay,
      checkupAt: checkupAt ?? this.checkupAt,
      checkups: checkups ?? this.checkups,
      lastWeight: lastWeight ?? this.lastWeight,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(
        $PetsTable.$converterstage.toSql(stage.value),
      );
    }
    if (furMain.present) {
      map['fur_main'] = Variable<int>(furMain.value);
    }
    if (furSecond.present) {
      map['fur_second'] = Variable<int>(furSecond.value);
    }
    if (accent.present) {
      map['accent'] = Variable<int>(accent.value);
    }
    if (marking.present) {
      map['marking'] = Variable<int>(marking.value);
    }
    if (bornAt.present) {
      map['born_at'] = Variable<DateTime>(bornAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (mood.present) {
      map['mood'] = Variable<double>(mood.value);
    }
    if (hunger.present) {
      map['hunger'] = Variable<double>(hunger.value);
    }
    if (energy.present) {
      map['energy'] = Variable<double>(energy.value);
    }
    if (affection.present) {
      map['affection'] = Variable<double>(affection.value);
    }
    if (careScore.present) {
      map['care_score'] = Variable<double>(careScore.value);
    }
    if (regionName.present) {
      map['region_name'] = Variable<String>(regionName.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (portraitPath.present) {
      map['portrait_path'] = Variable<String>(portraitPath.value);
    }
    if (shape.present) {
      map['shape'] = Variable<String>(shape.value);
    }
    if (countDay.present) {
      map['count_day'] = Variable<String>(countDay.value);
    }
    if (bondToday.present) {
      map['bond_today'] = Variable<double>(bondToday.value);
    }
    if (talksToday.present) {
      map['talks_today'] = Variable<int>(talksToday.value);
    }
    if (activity.present) {
      map['activity'] = Variable<double>(activity.value);
    }
    if (attachment.present) {
      map['attachment'] = Variable<double>(attachment.value);
    }
    if (rhythm.present) {
      map['rhythm'] = Variable<String>(rhythm.value);
    }
    if (likeTaste.present) {
      map['like_taste'] = Variable<String>(
        $PetsTable.$converterlikeTasten.toSql(likeTaste.value),
      );
    }
    if (dislikeTaste.present) {
      map['dislike_taste'] = Variable<String>(
        $PetsTable.$converterdislikeTasten.toSql(dislikeTaste.value),
      );
    }
    if (lastStepTotal.present) {
      map['last_step_total'] = Variable<int>(lastStepTotal.value);
    }
    if (pocketDay.present) {
      map['pocket_day'] = Variable<String>(pocketDay.value);
    }
    if (pocketCount.present) {
      map['pocket_count'] = Variable<int>(pocketCount.value);
    }
    if (windowNight.present) {
      map['window_night'] = Variable<String>(windowNight.value);
    }
    if (giftDay.present) {
      map['gift_day'] = Variable<String>(giftDay.value);
    }
    if (snowDay.present) {
      map['snow_day'] = Variable<String>(snowDay.value);
    }
    if (comfortDue.present) {
      map['comfort_due'] = Variable<bool>(comfortDue.value);
    }
    if (comfortDay.present) {
      map['comfort_day'] = Variable<String>(comfortDay.value);
    }
    if (pottyAt.present) {
      map['potty_at'] = Variable<DateTime>(pottyAt.value);
    }
    if (lastCrisisAt.present) {
      map['last_crisis_at'] = Variable<DateTime>(lastCrisisAt.value);
    }
    if (daycareFrom.present) {
      map['daycare_from'] = Variable<DateTime>(daycareFrom.value);
    }
    if (daycareLesson.present) {
      map['daycare_lesson'] = Variable<String>(daycareLesson.value);
    }
    if (daycareRecitalStats.present) {
      map['daycare_recital_stats'] = Variable<String>(
        daycareRecitalStats.value,
      );
    }
    if (recitalDays.present) {
      map['recital_days'] = Variable<String>(recitalDays.value);
    }
    if (wish.present) {
      map['wish'] = Variable<String>(wish.value);
    }
    if (wishDay.present) {
      map['wish_day'] = Variable<String>(wishDay.value);
    }
    if (wishDone.present) {
      map['wish_done'] = Variable<bool>(wishDone.value);
    }
    if (paws.present) {
      map['paws'] = Variable<int>(paws.value);
    }
    if (pawsToday.present) {
      map['paws_today'] = Variable<int>(pawsToday.value);
    }
    if (pawsDay.present) {
      map['paws_day'] = Variable<String>(pawsDay.value);
    }
    if (pawMarks.present) {
      map['paw_marks'] = Variable<String>(pawMarks.value);
    }
    if (eveningDay.present) {
      map['evening_day'] = Variable<String>(eveningDay.value);
    }
    if (rug.present) {
      map['rug'] = Variable<String>(rug.value);
    }
    if (owned.present) {
      map['owned'] = Variable<String>(owned.value);
    }
    if (touchX.present) {
      map['touch_x'] = Variable<double>(touchX.value);
    }
    if (quirk.present) {
      map['quirk'] = Variable<String>(quirk.value);
    }
    if (doorNews.present) {
      map['door_news'] = Variable<String>(doorNews.value);
    }
    if (habit.present) {
      map['habit'] = Variable<String>(habit.value);
    }
    if (treatsTried.present) {
      map['treats_tried'] = Variable<String>(treatsTried.value);
    }
    if (treatShares.present) {
      map['treat_shares'] = Variable<String>(treatShares.value);
    }
    if (treatPouch.present) {
      map['treat_pouch'] = Variable<String>(treatPouch.value);
    }
    if (treatDay.present) {
      map['treat_day'] = Variable<String>(treatDay.value);
    }
    if (checkupAt.present) {
      map['checkup_at'] = Variable<DateTime>(checkupAt.value);
    }
    if (checkups.present) {
      map['checkups'] = Variable<int>(checkups.value);
    }
    if (lastWeight.present) {
      map['last_weight'] = Variable<double>(lastWeight.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('stage: $stage, ')
          ..write('furMain: $furMain, ')
          ..write('furSecond: $furSecond, ')
          ..write('accent: $accent, ')
          ..write('marking: $marking, ')
          ..write('bornAt: $bornAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('mood: $mood, ')
          ..write('hunger: $hunger, ')
          ..write('energy: $energy, ')
          ..write('affection: $affection, ')
          ..write('careScore: $careScore, ')
          ..write('regionName: $regionName, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('portraitPath: $portraitPath, ')
          ..write('shape: $shape, ')
          ..write('countDay: $countDay, ')
          ..write('bondToday: $bondToday, ')
          ..write('talksToday: $talksToday, ')
          ..write('activity: $activity, ')
          ..write('attachment: $attachment, ')
          ..write('rhythm: $rhythm, ')
          ..write('likeTaste: $likeTaste, ')
          ..write('dislikeTaste: $dislikeTaste, ')
          ..write('lastStepTotal: $lastStepTotal, ')
          ..write('pocketDay: $pocketDay, ')
          ..write('pocketCount: $pocketCount, ')
          ..write('windowNight: $windowNight, ')
          ..write('giftDay: $giftDay, ')
          ..write('snowDay: $snowDay, ')
          ..write('comfortDue: $comfortDue, ')
          ..write('comfortDay: $comfortDay, ')
          ..write('pottyAt: $pottyAt, ')
          ..write('lastCrisisAt: $lastCrisisAt, ')
          ..write('daycareFrom: $daycareFrom, ')
          ..write('daycareLesson: $daycareLesson, ')
          ..write('daycareRecitalStats: $daycareRecitalStats, ')
          ..write('recitalDays: $recitalDays, ')
          ..write('wish: $wish, ')
          ..write('wishDay: $wishDay, ')
          ..write('wishDone: $wishDone, ')
          ..write('paws: $paws, ')
          ..write('pawsToday: $pawsToday, ')
          ..write('pawsDay: $pawsDay, ')
          ..write('pawMarks: $pawMarks, ')
          ..write('eveningDay: $eveningDay, ')
          ..write('rug: $rug, ')
          ..write('owned: $owned, ')
          ..write('touchX: $touchX, ')
          ..write('quirk: $quirk, ')
          ..write('doorNews: $doorNews, ')
          ..write('habit: $habit, ')
          ..write('treatsTried: $treatsTried, ')
          ..write('treatShares: $treatShares, ')
          ..write('treatPouch: $treatPouch, ')
          ..write('treatDay: $treatDay, ')
          ..write('checkupAt: $checkupAt, ')
          ..write('checkups: $checkups, ')
          ..write('lastWeight: $lastWeight')
          ..write(')'))
        .toString();
  }
}

class $MemoriesTable extends Memories with TableInfo<$MemoriesTable, Memory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, content, createdAt, pinned];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Memory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Memory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Memory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
    );
  }

  @override
  $MemoriesTable createAlias(String alias) {
    return $MemoriesTable(attachedDatabase, alias);
  }
}

class Memory extends DataClass implements Insertable<Memory> {
  final int id;
  final String content;
  final DateTime createdAt;
  final bool pinned;
  const Memory({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.pinned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['pinned'] = Variable<bool>(pinned);
    return map;
  }

  MemoriesCompanion toCompanion(bool nullToAbsent) {
    return MemoriesCompanion(
      id: Value(id),
      content: Value(content),
      createdAt: Value(createdAt),
      pinned: Value(pinned),
    );
  }

  factory Memory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Memory(
      id: serializer.fromJson<int>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      pinned: serializer.fromJson<bool>(json['pinned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'pinned': serializer.toJson<bool>(pinned),
    };
  }

  Memory copyWith({
    int? id,
    String? content,
    DateTime? createdAt,
    bool? pinned,
  }) => Memory(
    id: id ?? this.id,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    pinned: pinned ?? this.pinned,
  );
  Memory copyWithCompanion(MemoriesCompanion data) {
    return Memory(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Memory(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('pinned: $pinned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, content, createdAt, pinned);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Memory &&
          other.id == this.id &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.pinned == this.pinned);
}

class MemoriesCompanion extends UpdateCompanion<Memory> {
  final Value<int> id;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<bool> pinned;
  const MemoriesCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pinned = const Value.absent(),
  });
  MemoriesCompanion.insert({
    this.id = const Value.absent(),
    required String content,
    required DateTime createdAt,
    this.pinned = const Value.absent(),
  }) : content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<Memory> custom({
    Expression<int>? id,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<bool>? pinned,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (pinned != null) 'pinned': pinned,
    });
  }

  MemoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<bool>? pinned,
  }) {
    return MemoriesCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      pinned: pinned ?? this.pinned,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoriesCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('pinned: $pinned')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, detail, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<Event> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    } else if (isInserting) {
      context.missing(_detailMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class Event extends DataClass implements Insertable<Event> {
  final int id;
  final String kind;
  final String detail;
  final DateTime at;
  const Event({
    required this.id,
    required this.kind,
    required this.detail,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['detail'] = Variable<String>(detail);
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      kind: Value(kind),
      detail: Value(detail),
      at: Value(at),
    );
  }

  factory Event.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Event(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      detail: serializer.fromJson<String>(json['detail']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'detail': serializer.toJson<String>(detail),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  Event copyWith({int? id, String? kind, String? detail, DateTime? at}) =>
      Event(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        detail: detail ?? this.detail,
        at: at ?? this.at,
      );
  Event copyWithCompanion(EventsCompanion data) {
    return Event(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      detail: data.detail.present ? data.detail.value : this.detail,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Event(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('detail: $detail, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, detail, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Event &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.detail == this.detail &&
          other.at == this.at);
}

class EventsCompanion extends UpdateCompanion<Event> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> detail;
  final Value<DateTime> at;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.detail = const Value.absent(),
    this.at = const Value.absent(),
  });
  EventsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String detail,
    required DateTime at,
  }) : kind = Value(kind),
       detail = Value(detail),
       at = Value(at);
  static Insertable<Event> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? detail,
    Expression<DateTime>? at,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (detail != null) 'detail': detail,
      if (at != null) 'at': at,
    });
  }

  EventsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? detail,
    Value<DateTime>? at,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      detail: detail ?? this.detail,
      at: at ?? this.at,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('detail: $detail, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

class $DiariesTable extends Diaries with TableInfo<$DiariesTable, Diary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byAiMeta = const VerificationMeta('byAi');
  @override
  late final GeneratedColumn<bool> byAi = GeneratedColumn<bool>(
    'by_ai',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("by_ai" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [id, day, content, createdAt, byAi];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Diary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('by_ai')) {
      context.handle(
        _byAiMeta,
        byAi.isAcceptableOrUnknown(data['by_ai']!, _byAiMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Diary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Diary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      byAi: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}by_ai'],
      )!,
    );
  }

  @override
  $DiariesTable createAlias(String alias) {
    return $DiariesTable(attachedDatabase, alias);
  }
}

class Diary extends DataClass implements Insertable<Diary> {
  final int id;
  final String day;
  final String content;
  final DateTime createdAt;

  /// AI가 쓴 일기에만 AI 표시를 붙인다(AI 기본법 고지). AI가 없을 때는 폰이 쓴다.
  final bool byAi;
  const Diary({
    required this.id,
    required this.day,
    required this.content,
    required this.createdAt,
    required this.byAi,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['day'] = Variable<String>(day);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['by_ai'] = Variable<bool>(byAi);
    return map;
  }

  DiariesCompanion toCompanion(bool nullToAbsent) {
    return DiariesCompanion(
      id: Value(id),
      day: Value(day),
      content: Value(content),
      createdAt: Value(createdAt),
      byAi: Value(byAi),
    );
  }

  factory Diary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Diary(
      id: serializer.fromJson<int>(json['id']),
      day: serializer.fromJson<String>(json['day']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      byAi: serializer.fromJson<bool>(json['byAi']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'day': serializer.toJson<String>(day),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'byAi': serializer.toJson<bool>(byAi),
    };
  }

  Diary copyWith({
    int? id,
    String? day,
    String? content,
    DateTime? createdAt,
    bool? byAi,
  }) => Diary(
    id: id ?? this.id,
    day: day ?? this.day,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    byAi: byAi ?? this.byAi,
  );
  Diary copyWithCompanion(DiariesCompanion data) {
    return Diary(
      id: data.id.present ? data.id.value : this.id,
      day: data.day.present ? data.day.value : this.day,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      byAi: data.byAi.present ? data.byAi.value : this.byAi,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Diary(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('byAi: $byAi')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, day, content, createdAt, byAi);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Diary &&
          other.id == this.id &&
          other.day == this.day &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.byAi == this.byAi);
}

class DiariesCompanion extends UpdateCompanion<Diary> {
  final Value<int> id;
  final Value<String> day;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<bool> byAi;
  const DiariesCompanion({
    this.id = const Value.absent(),
    this.day = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.byAi = const Value.absent(),
  });
  DiariesCompanion.insert({
    this.id = const Value.absent(),
    required String day,
    required String content,
    required DateTime createdAt,
    this.byAi = const Value.absent(),
  }) : day = Value(day),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<Diary> custom({
    Expression<int>? id,
    Expression<String>? day,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<bool>? byAi,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (day != null) 'day': day,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (byAi != null) 'by_ai': byAi,
    });
  }

  DiariesCompanion copyWith({
    Value<int>? id,
    Value<String>? day,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<bool>? byAi,
  }) {
    return DiariesCompanion(
      id: id ?? this.id,
      day: day ?? this.day,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      byAi: byAi ?? this.byAi,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (byAi.present) {
      map['by_ai'] = Variable<bool>(byAi.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiariesCompanion(')
          ..write('id: $id, ')
          ..write('day: $day, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('byAi: $byAi')
          ..write(')'))
        .toString();
  }
}

class $FindsTable extends Finds with TableInfo<$FindsTable, Find> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FindsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _giftCountMeta = const VerificationMeta(
    'giftCount',
  );
  @override
  late final GeneratedColumn<int> giftCount = GeneratedColumn<int>(
    'gift_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, count, giftCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'finds';
  @override
  VerificationContext validateIntegrity(
    Insertable<Find> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    if (data.containsKey('gift_count')) {
      context.handle(
        _giftCountMeta,
        giftCount.isAcceptableOrUnknown(data['gift_count']!, _giftCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  Find map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Find(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      giftCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gift_count'],
      )!,
    );
  }

  @override
  $FindsTable createAlias(String alias) {
    return $FindsTable(attachedDatabase, alias);
  }
}

class Find extends DataClass implements Insertable<Find> {
  final String itemId;
  final int count;
  final int giftCount;
  const Find({
    required this.itemId,
    required this.count,
    required this.giftCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['count'] = Variable<int>(count);
    map['gift_count'] = Variable<int>(giftCount);
    return map;
  }

  FindsCompanion toCompanion(bool nullToAbsent) {
    return FindsCompanion(
      itemId: Value(itemId),
      count: Value(count),
      giftCount: Value(giftCount),
    );
  }

  factory Find.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Find(
      itemId: serializer.fromJson<String>(json['itemId']),
      count: serializer.fromJson<int>(json['count']),
      giftCount: serializer.fromJson<int>(json['giftCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'count': serializer.toJson<int>(count),
      'giftCount': serializer.toJson<int>(giftCount),
    };
  }

  Find copyWith({String? itemId, int? count, int? giftCount}) => Find(
    itemId: itemId ?? this.itemId,
    count: count ?? this.count,
    giftCount: giftCount ?? this.giftCount,
  );
  Find copyWithCompanion(FindsCompanion data) {
    return Find(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      count: data.count.present ? data.count.value : this.count,
      giftCount: data.giftCount.present ? data.giftCount.value : this.giftCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Find(')
          ..write('itemId: $itemId, ')
          ..write('count: $count, ')
          ..write('giftCount: $giftCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, count, giftCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Find &&
          other.itemId == this.itemId &&
          other.count == this.count &&
          other.giftCount == this.giftCount);
}

class FindsCompanion extends UpdateCompanion<Find> {
  final Value<String> itemId;
  final Value<int> count;
  final Value<int> giftCount;
  final Value<int> rowid;
  const FindsCompanion({
    this.itemId = const Value.absent(),
    this.count = const Value.absent(),
    this.giftCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FindsCompanion.insert({
    required String itemId,
    this.count = const Value.absent(),
    this.giftCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId);
  static Insertable<Find> custom({
    Expression<String>? itemId,
    Expression<int>? count,
    Expression<int>? giftCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (count != null) 'count': count,
      if (giftCount != null) 'gift_count': giftCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FindsCompanion copyWith({
    Value<String>? itemId,
    Value<int>? count,
    Value<int>? giftCount,
    Value<int>? rowid,
  }) {
    return FindsCompanion(
      itemId: itemId ?? this.itemId,
      count: count ?? this.count,
      giftCount: giftCount ?? this.giftCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (giftCount.present) {
      map['gift_count'] = Variable<int>(giftCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FindsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('count: $count, ')
          ..write('giftCount: $giftCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CarriedTable extends Carried with TableInfo<$CarriedTable, CarriedItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarriedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FindSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FindSource>($CarriedTable.$convertersource);
  static const VerificationMeta _giftMeta = const VerificationMeta('gift');
  @override
  late final GeneratedColumn<bool> gift = GeneratedColumn<bool>(
    'gift',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("gift" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, itemId, source, gift, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'carried';
  @override
  VerificationContext validateIntegrity(
    Insertable<CarriedItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('gift')) {
      context.handle(
        _giftMeta,
        gift.isAcceptableOrUnknown(data['gift']!, _giftMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CarriedItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarriedItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      source: $CarriedTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      gift: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}gift'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CarriedTable createAlias(String alias) {
    return $CarriedTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FindSource, String, String> $convertersource =
      const EnumNameConverter<FindSource>(FindSource.values);
}

class CarriedItem extends DataClass implements Insertable<CarriedItem> {
  final int id;
  final String itemId;
  final FindSource source;
  final bool gift;
  final DateTime createdAt;
  const CarriedItem({
    required this.id,
    required this.itemId,
    required this.source,
    required this.gift,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['item_id'] = Variable<String>(itemId);
    {
      map['source'] = Variable<String>(
        $CarriedTable.$convertersource.toSql(source),
      );
    }
    map['gift'] = Variable<bool>(gift);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CarriedCompanion toCompanion(bool nullToAbsent) {
    return CarriedCompanion(
      id: Value(id),
      itemId: Value(itemId),
      source: Value(source),
      gift: Value(gift),
      createdAt: Value(createdAt),
    );
  }

  factory CarriedItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarriedItem(
      id: serializer.fromJson<int>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      source: $CarriedTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      gift: serializer.fromJson<bool>(json['gift']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemId': serializer.toJson<String>(itemId),
      'source': serializer.toJson<String>(
        $CarriedTable.$convertersource.toJson(source),
      ),
      'gift': serializer.toJson<bool>(gift),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CarriedItem copyWith({
    int? id,
    String? itemId,
    FindSource? source,
    bool? gift,
    DateTime? createdAt,
  }) => CarriedItem(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    source: source ?? this.source,
    gift: gift ?? this.gift,
    createdAt: createdAt ?? this.createdAt,
  );
  CarriedItem copyWithCompanion(CarriedCompanion data) {
    return CarriedItem(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      source: data.source.present ? data.source.value : this.source,
      gift: data.gift.present ? data.gift.value : this.gift,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarriedItem(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('source: $source, ')
          ..write('gift: $gift, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, source, gift, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarriedItem &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.source == this.source &&
          other.gift == this.gift &&
          other.createdAt == this.createdAt);
}

class CarriedCompanion extends UpdateCompanion<CarriedItem> {
  final Value<int> id;
  final Value<String> itemId;
  final Value<FindSource> source;
  final Value<bool> gift;
  final Value<DateTime> createdAt;
  const CarriedCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.source = const Value.absent(),
    this.gift = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CarriedCompanion.insert({
    this.id = const Value.absent(),
    required String itemId,
    required FindSource source,
    this.gift = const Value.absent(),
    required DateTime createdAt,
  }) : itemId = Value(itemId),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<CarriedItem> custom({
    Expression<int>? id,
    Expression<String>? itemId,
    Expression<String>? source,
    Expression<bool>? gift,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (source != null) 'source': source,
      if (gift != null) 'gift': gift,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CarriedCompanion copyWith({
    Value<int>? id,
    Value<String>? itemId,
    Value<FindSource>? source,
    Value<bool>? gift,
    Value<DateTime>? createdAt,
  }) {
    return CarriedCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      source: source ?? this.source,
      gift: gift ?? this.gift,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $CarriedTable.$convertersource.toSql(source.value),
      );
    }
    if (gift.present) {
      map['gift'] = Variable<bool>(gift.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CarriedCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('source: $source, ')
          ..write('gift: $gift, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PlacementsTable extends Placements
    with TableInfo<$PlacementsTable, Placement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlacementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [slot, itemId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'placements';
  @override
  VerificationContext validateIntegrity(
    Insertable<Placement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slot};
  @override
  Placement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Placement(
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
    );
  }

  @override
  $PlacementsTable createAlias(String alias) {
    return $PlacementsTable(attachedDatabase, alias);
  }
}

class Placement extends DataClass implements Insertable<Placement> {
  final String slot;
  final String itemId;
  const Placement({required this.slot, required this.itemId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<String>(slot);
    map['item_id'] = Variable<String>(itemId);
    return map;
  }

  PlacementsCompanion toCompanion(bool nullToAbsent) {
    return PlacementsCompanion(slot: Value(slot), itemId: Value(itemId));
  }

  factory Placement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Placement(
      slot: serializer.fromJson<String>(json['slot']),
      itemId: serializer.fromJson<String>(json['itemId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<String>(slot),
      'itemId': serializer.toJson<String>(itemId),
    };
  }

  Placement copyWith({String? slot, String? itemId}) =>
      Placement(slot: slot ?? this.slot, itemId: itemId ?? this.itemId);
  Placement copyWithCompanion(PlacementsCompanion data) {
    return Placement(
      slot: data.slot.present ? data.slot.value : this.slot,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Placement(')
          ..write('slot: $slot, ')
          ..write('itemId: $itemId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, itemId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Placement &&
          other.slot == this.slot &&
          other.itemId == this.itemId);
}

class PlacementsCompanion extends UpdateCompanion<Placement> {
  final Value<String> slot;
  final Value<String> itemId;
  final Value<int> rowid;
  const PlacementsCompanion({
    this.slot = const Value.absent(),
    this.itemId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlacementsCompanion.insert({
    required String slot,
    required String itemId,
    this.rowid = const Value.absent(),
  }) : slot = Value(slot),
       itemId = Value(itemId);
  static Insertable<Placement> custom({
    Expression<String>? slot,
    Expression<String>? itemId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (itemId != null) 'item_id': itemId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlacementsCompanion copyWith({
    Value<String>? slot,
    Value<String>? itemId,
    Value<int>? rowid,
  }) {
    return PlacementsCompanion(
      slot: slot ?? this.slot,
      itemId: itemId ?? this.itemId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlacementsCompanion(')
          ..write('slot: $slot, ')
          ..write('itemId: $itemId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TricksTable extends Tricks with TableInfo<$TricksTable, TrickRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TricksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trickMeta = const VerificationMeta('trick');
  @override
  late final GeneratedColumn<String> trick = GeneratedColumn<String>(
    'trick',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _successesMeta = const VerificationMeta(
    'successes',
  );
  @override
  late final GeneratedColumn<int> successes = GeneratedColumn<int>(
    'successes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _daysMeta = const VerificationMeta('days');
  @override
  late final GeneratedColumn<int> days = GeneratedColumn<int>(
    'days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastDayMeta = const VerificationMeta(
    'lastDay',
  );
  @override
  late final GeneratedColumn<String> lastDay = GeneratedColumn<String>(
    'last_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _learnedDayMeta = const VerificationMeta(
    'learnedDay',
  );
  @override
  late final GeneratedColumn<String> learnedDay = GeneratedColumn<String>(
    'learned_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trick,
    attempts,
    successes,
    days,
    lastDay,
    learnedDay,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tricks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrickRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trick')) {
      context.handle(
        _trickMeta,
        trick.isAcceptableOrUnknown(data['trick']!, _trickMeta),
      );
    } else if (isInserting) {
      context.missing(_trickMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('successes')) {
      context.handle(
        _successesMeta,
        successes.isAcceptableOrUnknown(data['successes']!, _successesMeta),
      );
    }
    if (data.containsKey('days')) {
      context.handle(
        _daysMeta,
        days.isAcceptableOrUnknown(data['days']!, _daysMeta),
      );
    }
    if (data.containsKey('last_day')) {
      context.handle(
        _lastDayMeta,
        lastDay.isAcceptableOrUnknown(data['last_day']!, _lastDayMeta),
      );
    }
    if (data.containsKey('learned_day')) {
      context.handle(
        _learnedDayMeta,
        learnedDay.isAcceptableOrUnknown(data['learned_day']!, _learnedDayMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trick};
  @override
  TrickRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrickRow(
      trick: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trick'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      successes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}successes'],
      )!,
      days: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days'],
      )!,
      lastDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_day'],
      ),
      learnedDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learned_day'],
      ),
    );
  }

  @override
  $TricksTable createAlias(String alias) {
    return $TricksTable(attachedDatabase, alias);
  }
}

class TrickRow extends DataClass implements Insertable<TrickRow> {
  final String trick;
  final int attempts;
  final int successes;
  final int days;
  final String? lastDay;

  /// 세 번째로 해내 배운 날(dayKey). 이 칸이 생기기 전에 배운 개인기는 비어 있다.
  final String? learnedDay;
  const TrickRow({
    required this.trick,
    required this.attempts,
    required this.successes,
    required this.days,
    this.lastDay,
    this.learnedDay,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trick'] = Variable<String>(trick);
    map['attempts'] = Variable<int>(attempts);
    map['successes'] = Variable<int>(successes);
    map['days'] = Variable<int>(days);
    if (!nullToAbsent || lastDay != null) {
      map['last_day'] = Variable<String>(lastDay);
    }
    if (!nullToAbsent || learnedDay != null) {
      map['learned_day'] = Variable<String>(learnedDay);
    }
    return map;
  }

  TricksCompanion toCompanion(bool nullToAbsent) {
    return TricksCompanion(
      trick: Value(trick),
      attempts: Value(attempts),
      successes: Value(successes),
      days: Value(days),
      lastDay: lastDay == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDay),
      learnedDay: learnedDay == null && nullToAbsent
          ? const Value.absent()
          : Value(learnedDay),
    );
  }

  factory TrickRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrickRow(
      trick: serializer.fromJson<String>(json['trick']),
      attempts: serializer.fromJson<int>(json['attempts']),
      successes: serializer.fromJson<int>(json['successes']),
      days: serializer.fromJson<int>(json['days']),
      lastDay: serializer.fromJson<String?>(json['lastDay']),
      learnedDay: serializer.fromJson<String?>(json['learnedDay']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trick': serializer.toJson<String>(trick),
      'attempts': serializer.toJson<int>(attempts),
      'successes': serializer.toJson<int>(successes),
      'days': serializer.toJson<int>(days),
      'lastDay': serializer.toJson<String?>(lastDay),
      'learnedDay': serializer.toJson<String?>(learnedDay),
    };
  }

  TrickRow copyWith({
    String? trick,
    int? attempts,
    int? successes,
    int? days,
    Value<String?> lastDay = const Value.absent(),
    Value<String?> learnedDay = const Value.absent(),
  }) => TrickRow(
    trick: trick ?? this.trick,
    attempts: attempts ?? this.attempts,
    successes: successes ?? this.successes,
    days: days ?? this.days,
    lastDay: lastDay.present ? lastDay.value : this.lastDay,
    learnedDay: learnedDay.present ? learnedDay.value : this.learnedDay,
  );
  TrickRow copyWithCompanion(TricksCompanion data) {
    return TrickRow(
      trick: data.trick.present ? data.trick.value : this.trick,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      successes: data.successes.present ? data.successes.value : this.successes,
      days: data.days.present ? data.days.value : this.days,
      lastDay: data.lastDay.present ? data.lastDay.value : this.lastDay,
      learnedDay: data.learnedDay.present
          ? data.learnedDay.value
          : this.learnedDay,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrickRow(')
          ..write('trick: $trick, ')
          ..write('attempts: $attempts, ')
          ..write('successes: $successes, ')
          ..write('days: $days, ')
          ..write('lastDay: $lastDay, ')
          ..write('learnedDay: $learnedDay')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(trick, attempts, successes, days, lastDay, learnedDay);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrickRow &&
          other.trick == this.trick &&
          other.attempts == this.attempts &&
          other.successes == this.successes &&
          other.days == this.days &&
          other.lastDay == this.lastDay &&
          other.learnedDay == this.learnedDay);
}

class TricksCompanion extends UpdateCompanion<TrickRow> {
  final Value<String> trick;
  final Value<int> attempts;
  final Value<int> successes;
  final Value<int> days;
  final Value<String?> lastDay;
  final Value<String?> learnedDay;
  final Value<int> rowid;
  const TricksCompanion({
    this.trick = const Value.absent(),
    this.attempts = const Value.absent(),
    this.successes = const Value.absent(),
    this.days = const Value.absent(),
    this.lastDay = const Value.absent(),
    this.learnedDay = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TricksCompanion.insert({
    required String trick,
    this.attempts = const Value.absent(),
    this.successes = const Value.absent(),
    this.days = const Value.absent(),
    this.lastDay = const Value.absent(),
    this.learnedDay = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : trick = Value(trick);
  static Insertable<TrickRow> custom({
    Expression<String>? trick,
    Expression<int>? attempts,
    Expression<int>? successes,
    Expression<int>? days,
    Expression<String>? lastDay,
    Expression<String>? learnedDay,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trick != null) 'trick': trick,
      if (attempts != null) 'attempts': attempts,
      if (successes != null) 'successes': successes,
      if (days != null) 'days': days,
      if (lastDay != null) 'last_day': lastDay,
      if (learnedDay != null) 'learned_day': learnedDay,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TricksCompanion copyWith({
    Value<String>? trick,
    Value<int>? attempts,
    Value<int>? successes,
    Value<int>? days,
    Value<String?>? lastDay,
    Value<String?>? learnedDay,
    Value<int>? rowid,
  }) {
    return TricksCompanion(
      trick: trick ?? this.trick,
      attempts: attempts ?? this.attempts,
      successes: successes ?? this.successes,
      days: days ?? this.days,
      lastDay: lastDay ?? this.lastDay,
      learnedDay: learnedDay ?? this.learnedDay,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trick.present) {
      map['trick'] = Variable<String>(trick.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (successes.present) {
      map['successes'] = Variable<int>(successes.value);
    }
    if (days.present) {
      map['days'] = Variable<int>(days.value);
    }
    if (lastDay.present) {
      map['last_day'] = Variable<String>(lastDay.value);
    }
    if (learnedDay.present) {
      map['learned_day'] = Variable<String>(learnedDay.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TricksCompanion(')
          ..write('trick: $trick, ')
          ..write('attempts: $attempts, ')
          ..write('successes: $successes, ')
          ..write('days: $days, ')
          ..write('lastDay: $lastDay, ')
          ..write('learnedDay: $learnedDay, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FriendsTable extends Friends with TableInfo<$FriendsTable, FriendRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FriendsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _guestIdMeta = const VerificationMeta(
    'guestId',
  );
  @override
  late final GeneratedColumn<String> guestId = GeneratedColumn<String>(
    'guest_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bondMeta = const VerificationMeta('bond');
  @override
  late final GeneratedColumn<int> bond = GeneratedColumn<int>(
    'bond',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _daysMeta = const VerificationMeta('days');
  @override
  late final GeneratedColumn<int> days = GeneratedColumn<int>(
    'days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastDayMeta = const VerificationMeta(
    'lastDay',
  );
  @override
  late final GeneratedColumn<String> lastDay = GeneratedColumn<String>(
    'last_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streakMeta = const VerificationMeta('streak');
  @override
  late final GeneratedColumn<int> streak = GeneratedColumn<int>(
    'streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    guestId,
    bond,
    days,
    lastDay,
    name,
    streak,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'friends';
  @override
  VerificationContext validateIntegrity(
    Insertable<FriendRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('guest_id')) {
      context.handle(
        _guestIdMeta,
        guestId.isAcceptableOrUnknown(data['guest_id']!, _guestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_guestIdMeta);
    }
    if (data.containsKey('bond')) {
      context.handle(
        _bondMeta,
        bond.isAcceptableOrUnknown(data['bond']!, _bondMeta),
      );
    }
    if (data.containsKey('days')) {
      context.handle(
        _daysMeta,
        days.isAcceptableOrUnknown(data['days']!, _daysMeta),
      );
    }
    if (data.containsKey('last_day')) {
      context.handle(
        _lastDayMeta,
        lastDay.isAcceptableOrUnknown(data['last_day']!, _lastDayMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('streak')) {
      context.handle(
        _streakMeta,
        streak.isAcceptableOrUnknown(data['streak']!, _streakMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {guestId};
  @override
  FriendRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FriendRow(
      guestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guest_id'],
      )!,
      bond: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bond'],
      )!,
      days: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}days'],
      )!,
      lastDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_day'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      streak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak'],
      )!,
    );
  }

  @override
  $FriendsTable createAlias(String alias) {
    return $FriendsTable(attachedDatabase, alias);
  }
}

class FriendRow extends DataClass implements Insertable<FriendRow> {
  final String guestId;

  /// 0 아직 못 만남, 1 낯섦, 2 킁킁, 3 놀이, 4 단짝 (lib/pet/friends.dart의 Bond 순서).
  final int bond;
  final int days;
  final String? lastDay;

  /// 주인이 붙인 이름. 유저 입력이라 알림·사용 기록에는 쓰지 않는다.
  final String? name;

  /// 마지막으로 만난 날까지 며칠 내리 만났는지(lib/pet/friends.dart Friendship.streak).
  final int streak;
  const FriendRow({
    required this.guestId,
    required this.bond,
    required this.days,
    this.lastDay,
    this.name,
    required this.streak,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['guest_id'] = Variable<String>(guestId);
    map['bond'] = Variable<int>(bond);
    map['days'] = Variable<int>(days);
    if (!nullToAbsent || lastDay != null) {
      map['last_day'] = Variable<String>(lastDay);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['streak'] = Variable<int>(streak);
    return map;
  }

  FriendsCompanion toCompanion(bool nullToAbsent) {
    return FriendsCompanion(
      guestId: Value(guestId),
      bond: Value(bond),
      days: Value(days),
      lastDay: lastDay == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDay),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      streak: Value(streak),
    );
  }

  factory FriendRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FriendRow(
      guestId: serializer.fromJson<String>(json['guestId']),
      bond: serializer.fromJson<int>(json['bond']),
      days: serializer.fromJson<int>(json['days']),
      lastDay: serializer.fromJson<String?>(json['lastDay']),
      name: serializer.fromJson<String?>(json['name']),
      streak: serializer.fromJson<int>(json['streak']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'guestId': serializer.toJson<String>(guestId),
      'bond': serializer.toJson<int>(bond),
      'days': serializer.toJson<int>(days),
      'lastDay': serializer.toJson<String?>(lastDay),
      'name': serializer.toJson<String?>(name),
      'streak': serializer.toJson<int>(streak),
    };
  }

  FriendRow copyWith({
    String? guestId,
    int? bond,
    int? days,
    Value<String?> lastDay = const Value.absent(),
    Value<String?> name = const Value.absent(),
    int? streak,
  }) => FriendRow(
    guestId: guestId ?? this.guestId,
    bond: bond ?? this.bond,
    days: days ?? this.days,
    lastDay: lastDay.present ? lastDay.value : this.lastDay,
    name: name.present ? name.value : this.name,
    streak: streak ?? this.streak,
  );
  FriendRow copyWithCompanion(FriendsCompanion data) {
    return FriendRow(
      guestId: data.guestId.present ? data.guestId.value : this.guestId,
      bond: data.bond.present ? data.bond.value : this.bond,
      days: data.days.present ? data.days.value : this.days,
      lastDay: data.lastDay.present ? data.lastDay.value : this.lastDay,
      name: data.name.present ? data.name.value : this.name,
      streak: data.streak.present ? data.streak.value : this.streak,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FriendRow(')
          ..write('guestId: $guestId, ')
          ..write('bond: $bond, ')
          ..write('days: $days, ')
          ..write('lastDay: $lastDay, ')
          ..write('name: $name, ')
          ..write('streak: $streak')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(guestId, bond, days, lastDay, name, streak);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FriendRow &&
          other.guestId == this.guestId &&
          other.bond == this.bond &&
          other.days == this.days &&
          other.lastDay == this.lastDay &&
          other.name == this.name &&
          other.streak == this.streak);
}

class FriendsCompanion extends UpdateCompanion<FriendRow> {
  final Value<String> guestId;
  final Value<int> bond;
  final Value<int> days;
  final Value<String?> lastDay;
  final Value<String?> name;
  final Value<int> streak;
  final Value<int> rowid;
  const FriendsCompanion({
    this.guestId = const Value.absent(),
    this.bond = const Value.absent(),
    this.days = const Value.absent(),
    this.lastDay = const Value.absent(),
    this.name = const Value.absent(),
    this.streak = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FriendsCompanion.insert({
    required String guestId,
    this.bond = const Value.absent(),
    this.days = const Value.absent(),
    this.lastDay = const Value.absent(),
    this.name = const Value.absent(),
    this.streak = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : guestId = Value(guestId);
  static Insertable<FriendRow> custom({
    Expression<String>? guestId,
    Expression<int>? bond,
    Expression<int>? days,
    Expression<String>? lastDay,
    Expression<String>? name,
    Expression<int>? streak,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (guestId != null) 'guest_id': guestId,
      if (bond != null) 'bond': bond,
      if (days != null) 'days': days,
      if (lastDay != null) 'last_day': lastDay,
      if (name != null) 'name': name,
      if (streak != null) 'streak': streak,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FriendsCompanion copyWith({
    Value<String>? guestId,
    Value<int>? bond,
    Value<int>? days,
    Value<String?>? lastDay,
    Value<String?>? name,
    Value<int>? streak,
    Value<int>? rowid,
  }) {
    return FriendsCompanion(
      guestId: guestId ?? this.guestId,
      bond: bond ?? this.bond,
      days: days ?? this.days,
      lastDay: lastDay ?? this.lastDay,
      name: name ?? this.name,
      streak: streak ?? this.streak,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (guestId.present) {
      map['guest_id'] = Variable<String>(guestId.value);
    }
    if (bond.present) {
      map['bond'] = Variable<int>(bond.value);
    }
    if (days.present) {
      map['days'] = Variable<int>(days.value);
    }
    if (lastDay.present) {
      map['last_day'] = Variable<String>(lastDay.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (streak.present) {
      map['streak'] = Variable<int>(streak.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FriendsCompanion(')
          ..write('guestId: $guestId, ')
          ..write('bond: $bond, ')
          ..write('days: $days, ')
          ..write('lastDay: $lastDay, ')
          ..write('name: $name, ')
          ..write('streak: $streak, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnownDogsTable extends KnownDogs
    with TableInfo<$KnownDogsTable, KnownDogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnownDogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shapeMeta = const VerificationMeta('shape');
  @override
  late final GeneratedColumn<String> shape = GeneratedColumn<String>(
    'shape',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _furMainMeta = const VerificationMeta(
    'furMain',
  );
  @override
  late final GeneratedColumn<int> furMain = GeneratedColumn<int>(
    'fur_main',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _furSecondMeta = const VerificationMeta(
    'furSecond',
  );
  @override
  late final GeneratedColumn<int> furSecond = GeneratedColumn<int>(
    'fur_second',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markingMeta = const VerificationMeta(
    'marking',
  );
  @override
  late final GeneratedColumn<int> marking = GeneratedColumn<int>(
    'marking',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _puppyMeta = const VerificationMeta('puppy');
  @override
  late final GeneratedColumn<bool> puppy = GeneratedColumn<bool>(
    'puppy',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("puppy" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shape,
    furMain,
    furSecond,
    marking,
    puppy,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'known_dogs';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnownDogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shape')) {
      context.handle(
        _shapeMeta,
        shape.isAcceptableOrUnknown(data['shape']!, _shapeMeta),
      );
    } else if (isInserting) {
      context.missing(_shapeMeta);
    }
    if (data.containsKey('fur_main')) {
      context.handle(
        _furMainMeta,
        furMain.isAcceptableOrUnknown(data['fur_main']!, _furMainMeta),
      );
    } else if (isInserting) {
      context.missing(_furMainMeta);
    }
    if (data.containsKey('fur_second')) {
      context.handle(
        _furSecondMeta,
        furSecond.isAcceptableOrUnknown(data['fur_second']!, _furSecondMeta),
      );
    } else if (isInserting) {
      context.missing(_furSecondMeta);
    }
    if (data.containsKey('marking')) {
      context.handle(
        _markingMeta,
        marking.isAcceptableOrUnknown(data['marking']!, _markingMeta),
      );
    } else if (isInserting) {
      context.missing(_markingMeta);
    }
    if (data.containsKey('puppy')) {
      context.handle(
        _puppyMeta,
        puppy.isAcceptableOrUnknown(data['puppy']!, _puppyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KnownDogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnownDogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      shape: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shape'],
      )!,
      furMain: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fur_main'],
      )!,
      furSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fur_second'],
      )!,
      marking: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}marking'],
      )!,
      puppy: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}puppy'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $KnownDogsTable createAlias(String alias) {
    return $KnownDogsTable(attachedDatabase, alias);
  }
}

class KnownDogRow extends DataClass implements Insertable<KnownDogRow> {
  final String id;
  final String shape;
  final int furMain;
  final int furSecond;
  final int marking;
  final bool puppy;
  final DateTime createdAt;
  const KnownDogRow({
    required this.id,
    required this.shape,
    required this.furMain,
    required this.furSecond,
    required this.marking,
    required this.puppy,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['shape'] = Variable<String>(shape);
    map['fur_main'] = Variable<int>(furMain);
    map['fur_second'] = Variable<int>(furSecond);
    map['marking'] = Variable<int>(marking);
    map['puppy'] = Variable<bool>(puppy);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  KnownDogsCompanion toCompanion(bool nullToAbsent) {
    return KnownDogsCompanion(
      id: Value(id),
      shape: Value(shape),
      furMain: Value(furMain),
      furSecond: Value(furSecond),
      marking: Value(marking),
      puppy: Value(puppy),
      createdAt: Value(createdAt),
    );
  }

  factory KnownDogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnownDogRow(
      id: serializer.fromJson<String>(json['id']),
      shape: serializer.fromJson<String>(json['shape']),
      furMain: serializer.fromJson<int>(json['furMain']),
      furSecond: serializer.fromJson<int>(json['furSecond']),
      marking: serializer.fromJson<int>(json['marking']),
      puppy: serializer.fromJson<bool>(json['puppy']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shape': serializer.toJson<String>(shape),
      'furMain': serializer.toJson<int>(furMain),
      'furSecond': serializer.toJson<int>(furSecond),
      'marking': serializer.toJson<int>(marking),
      'puppy': serializer.toJson<bool>(puppy),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  KnownDogRow copyWith({
    String? id,
    String? shape,
    int? furMain,
    int? furSecond,
    int? marking,
    bool? puppy,
    DateTime? createdAt,
  }) => KnownDogRow(
    id: id ?? this.id,
    shape: shape ?? this.shape,
    furMain: furMain ?? this.furMain,
    furSecond: furSecond ?? this.furSecond,
    marking: marking ?? this.marking,
    puppy: puppy ?? this.puppy,
    createdAt: createdAt ?? this.createdAt,
  );
  KnownDogRow copyWithCompanion(KnownDogsCompanion data) {
    return KnownDogRow(
      id: data.id.present ? data.id.value : this.id,
      shape: data.shape.present ? data.shape.value : this.shape,
      furMain: data.furMain.present ? data.furMain.value : this.furMain,
      furSecond: data.furSecond.present ? data.furSecond.value : this.furSecond,
      marking: data.marking.present ? data.marking.value : this.marking,
      puppy: data.puppy.present ? data.puppy.value : this.puppy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnownDogRow(')
          ..write('id: $id, ')
          ..write('shape: $shape, ')
          ..write('furMain: $furMain, ')
          ..write('furSecond: $furSecond, ')
          ..write('marking: $marking, ')
          ..write('puppy: $puppy, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, shape, furMain, furSecond, marking, puppy, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnownDogRow &&
          other.id == this.id &&
          other.shape == this.shape &&
          other.furMain == this.furMain &&
          other.furSecond == this.furSecond &&
          other.marking == this.marking &&
          other.puppy == this.puppy &&
          other.createdAt == this.createdAt);
}

class KnownDogsCompanion extends UpdateCompanion<KnownDogRow> {
  final Value<String> id;
  final Value<String> shape;
  final Value<int> furMain;
  final Value<int> furSecond;
  final Value<int> marking;
  final Value<bool> puppy;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const KnownDogsCompanion({
    this.id = const Value.absent(),
    this.shape = const Value.absent(),
    this.furMain = const Value.absent(),
    this.furSecond = const Value.absent(),
    this.marking = const Value.absent(),
    this.puppy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnownDogsCompanion.insert({
    required String id,
    required String shape,
    required int furMain,
    required int furSecond,
    required int marking,
    this.puppy = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       shape = Value(shape),
       furMain = Value(furMain),
       furSecond = Value(furSecond),
       marking = Value(marking),
       createdAt = Value(createdAt);
  static Insertable<KnownDogRow> custom({
    Expression<String>? id,
    Expression<String>? shape,
    Expression<int>? furMain,
    Expression<int>? furSecond,
    Expression<int>? marking,
    Expression<bool>? puppy,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shape != null) 'shape': shape,
      if (furMain != null) 'fur_main': furMain,
      if (furSecond != null) 'fur_second': furSecond,
      if (marking != null) 'marking': marking,
      if (puppy != null) 'puppy': puppy,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnownDogsCompanion copyWith({
    Value<String>? id,
    Value<String>? shape,
    Value<int>? furMain,
    Value<int>? furSecond,
    Value<int>? marking,
    Value<bool>? puppy,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return KnownDogsCompanion(
      id: id ?? this.id,
      shape: shape ?? this.shape,
      furMain: furMain ?? this.furMain,
      furSecond: furSecond ?? this.furSecond,
      marking: marking ?? this.marking,
      puppy: puppy ?? this.puppy,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shape.present) {
      map['shape'] = Variable<String>(shape.value);
    }
    if (furMain.present) {
      map['fur_main'] = Variable<int>(furMain.value);
    }
    if (furSecond.present) {
      map['fur_second'] = Variable<int>(furSecond.value);
    }
    if (marking.present) {
      map['marking'] = Variable<int>(marking.value);
    }
    if (puppy.present) {
      map['puppy'] = Variable<bool>(puppy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnownDogsCompanion(')
          ..write('id: $id, ')
          ..write('shape: $shape, ')
          ..write('furMain: $furMain, ')
          ..write('furSecond: $furSecond, ')
          ..write('marking: $marking, ')
          ..write('puppy: $puppy, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KinderPhotosTable extends KinderPhotos
    with TableInfo<$KinderPhotosTable, KinderPhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KinderPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sceneMeta = const VerificationMeta('scene');
  @override
  late final GeneratedColumn<String> scene = GeneratedColumn<String>(
    'scene',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _friendsMeta = const VerificationMeta(
    'friends',
  );
  @override
  late final GeneratedColumn<String> friends = GeneratedColumn<String>(
    'friends',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PetStage, String> stage =
      GeneratedColumn<String>(
        'stage',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PetStage>($KinderPhotosTable.$converterstage);
  static const VerificationMeta _trickMeta = const VerificationMeta('trick');
  @override
  late final GeneratedColumn<String> trick = GeneratedColumn<String>(
    'trick',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [day, scene, friends, stage, trick];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kinder_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<KinderPhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('scene')) {
      context.handle(
        _sceneMeta,
        scene.isAcceptableOrUnknown(data['scene']!, _sceneMeta),
      );
    } else if (isInserting) {
      context.missing(_sceneMeta);
    }
    if (data.containsKey('friends')) {
      context.handle(
        _friendsMeta,
        friends.isAcceptableOrUnknown(data['friends']!, _friendsMeta),
      );
    } else if (isInserting) {
      context.missing(_friendsMeta);
    }
    if (data.containsKey('trick')) {
      context.handle(
        _trickMeta,
        trick.isAcceptableOrUnknown(data['trick']!, _trickMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  KinderPhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KinderPhotoRow(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      scene: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scene'],
      )!,
      friends: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}friends'],
      )!,
      stage: $KinderPhotosTable.$converterstage.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}stage'],
        )!,
      ),
      trick: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trick'],
      ),
    );
  }

  @override
  $KinderPhotosTable createAlias(String alias) {
    return $KinderPhotosTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PetStage, String, String> $converterstage =
      const EnumNameConverter<PetStage>(PetStage.values);
}

class KinderPhotoRow extends DataClass implements Insertable<KinderPhotoRow> {
  final String day;

  /// KinderScene 이름. 모르는 이름이면 그리지 않는다.
  final String scene;

  /// 같이 찍힌 그날 유치원 친구 id(쉼표).
  final String friends;
  final PetStage stage;

  /// 수업 장면이면 그날 수업한 개인기 이름.
  final String? trick;
  const KinderPhotoRow({
    required this.day,
    required this.scene,
    required this.friends,
    required this.stage,
    this.trick,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['scene'] = Variable<String>(scene);
    map['friends'] = Variable<String>(friends);
    {
      map['stage'] = Variable<String>(
        $KinderPhotosTable.$converterstage.toSql(stage),
      );
    }
    if (!nullToAbsent || trick != null) {
      map['trick'] = Variable<String>(trick);
    }
    return map;
  }

  KinderPhotosCompanion toCompanion(bool nullToAbsent) {
    return KinderPhotosCompanion(
      day: Value(day),
      scene: Value(scene),
      friends: Value(friends),
      stage: Value(stage),
      trick: trick == null && nullToAbsent
          ? const Value.absent()
          : Value(trick),
    );
  }

  factory KinderPhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KinderPhotoRow(
      day: serializer.fromJson<String>(json['day']),
      scene: serializer.fromJson<String>(json['scene']),
      friends: serializer.fromJson<String>(json['friends']),
      stage: $KinderPhotosTable.$converterstage.fromJson(
        serializer.fromJson<String>(json['stage']),
      ),
      trick: serializer.fromJson<String?>(json['trick']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'scene': serializer.toJson<String>(scene),
      'friends': serializer.toJson<String>(friends),
      'stage': serializer.toJson<String>(
        $KinderPhotosTable.$converterstage.toJson(stage),
      ),
      'trick': serializer.toJson<String?>(trick),
    };
  }

  KinderPhotoRow copyWith({
    String? day,
    String? scene,
    String? friends,
    PetStage? stage,
    Value<String?> trick = const Value.absent(),
  }) => KinderPhotoRow(
    day: day ?? this.day,
    scene: scene ?? this.scene,
    friends: friends ?? this.friends,
    stage: stage ?? this.stage,
    trick: trick.present ? trick.value : this.trick,
  );
  KinderPhotoRow copyWithCompanion(KinderPhotosCompanion data) {
    return KinderPhotoRow(
      day: data.day.present ? data.day.value : this.day,
      scene: data.scene.present ? data.scene.value : this.scene,
      friends: data.friends.present ? data.friends.value : this.friends,
      stage: data.stage.present ? data.stage.value : this.stage,
      trick: data.trick.present ? data.trick.value : this.trick,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KinderPhotoRow(')
          ..write('day: $day, ')
          ..write('scene: $scene, ')
          ..write('friends: $friends, ')
          ..write('stage: $stage, ')
          ..write('trick: $trick')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, scene, friends, stage, trick);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KinderPhotoRow &&
          other.day == this.day &&
          other.scene == this.scene &&
          other.friends == this.friends &&
          other.stage == this.stage &&
          other.trick == this.trick);
}

class KinderPhotosCompanion extends UpdateCompanion<KinderPhotoRow> {
  final Value<String> day;
  final Value<String> scene;
  final Value<String> friends;
  final Value<PetStage> stage;
  final Value<String?> trick;
  final Value<int> rowid;
  const KinderPhotosCompanion({
    this.day = const Value.absent(),
    this.scene = const Value.absent(),
    this.friends = const Value.absent(),
    this.stage = const Value.absent(),
    this.trick = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KinderPhotosCompanion.insert({
    required String day,
    required String scene,
    required String friends,
    required PetStage stage,
    this.trick = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : day = Value(day),
       scene = Value(scene),
       friends = Value(friends),
       stage = Value(stage);
  static Insertable<KinderPhotoRow> custom({
    Expression<String>? day,
    Expression<String>? scene,
    Expression<String>? friends,
    Expression<String>? stage,
    Expression<String>? trick,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (scene != null) 'scene': scene,
      if (friends != null) 'friends': friends,
      if (stage != null) 'stage': stage,
      if (trick != null) 'trick': trick,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KinderPhotosCompanion copyWith({
    Value<String>? day,
    Value<String>? scene,
    Value<String>? friends,
    Value<PetStage>? stage,
    Value<String?>? trick,
    Value<int>? rowid,
  }) {
    return KinderPhotosCompanion(
      day: day ?? this.day,
      scene: scene ?? this.scene,
      friends: friends ?? this.friends,
      stage: stage ?? this.stage,
      trick: trick ?? this.trick,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (scene.present) {
      map['scene'] = Variable<String>(scene.value);
    }
    if (friends.present) {
      map['friends'] = Variable<String>(friends.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(
        $KinderPhotosTable.$converterstage.toSql(stage.value),
      );
    }
    if (trick.present) {
      map['trick'] = Variable<String>(trick.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KinderPhotosCompanion(')
          ..write('day: $day, ')
          ..write('scene: $scene, ')
          ..write('friends: $friends, ')
          ..write('stage: $stage, ')
          ..write('trick: $trick, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PetsTable pets = $PetsTable(this);
  late final $MemoriesTable memories = $MemoriesTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $DiariesTable diaries = $DiariesTable(this);
  late final $FindsTable finds = $FindsTable(this);
  late final $CarriedTable carried = $CarriedTable(this);
  late final $PlacementsTable placements = $PlacementsTable(this);
  late final $TricksTable tricks = $TricksTable(this);
  late final $FriendsTable friends = $FriendsTable(this);
  late final $KnownDogsTable knownDogs = $KnownDogsTable(this);
  late final $KinderPhotosTable kinderPhotos = $KinderPhotosTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pets,
    memories,
    events,
    diaries,
    finds,
    carried,
    placements,
    tricks,
    friends,
    knownDogs,
    kinderPhotos,
  ];
}

typedef $$PetsTableCreateCompanionBuilder =
    PetsCompanion Function({
      Value<int> id,
      required String name,
      required PetStage stage,
      required int furMain,
      required int furSecond,
      required int accent,
      Value<int> marking,
      required DateTime bornAt,
      required DateTime lastSeenAt,
      required double mood,
      required double hunger,
      required double energy,
      required double affection,
      Value<double> careScore,
      Value<String?> regionName,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String?> portraitPath,
      Value<String> shape,
      Value<String?> countDay,
      Value<double> bondToday,
      Value<int> talksToday,
      Value<double?> activity,
      Value<double?> attachment,
      Value<String?> rhythm,
      Value<Taste?> likeTaste,
      Value<Taste?> dislikeTaste,
      Value<int?> lastStepTotal,
      Value<String?> pocketDay,
      Value<int> pocketCount,
      Value<String?> windowNight,
      Value<String?> giftDay,
      Value<String?> snowDay,
      Value<bool> comfortDue,
      Value<String?> comfortDay,
      Value<DateTime?> pottyAt,
      Value<DateTime?> lastCrisisAt,
      Value<DateTime?> daycareFrom,
      Value<String?> daycareLesson,
      Value<String?> daycareRecitalStats,
      Value<String?> recitalDays,
      Value<String?> wish,
      Value<String?> wishDay,
      Value<bool> wishDone,
      Value<int> paws,
      Value<int> pawsToday,
      Value<String?> pawsDay,
      Value<String?> pawMarks,
      Value<String?> eveningDay,
      Value<String?> rug,
      Value<String?> owned,
      Value<double?> touchX,
      Value<String?> quirk,
      Value<String?> doorNews,
      Value<String?> habit,
      Value<String?> treatsTried,
      Value<String?> treatShares,
      Value<String?> treatPouch,
      Value<String?> treatDay,
      Value<DateTime?> checkupAt,
      Value<int> checkups,
      Value<double?> lastWeight,
    });
typedef $$PetsTableUpdateCompanionBuilder =
    PetsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<PetStage> stage,
      Value<int> furMain,
      Value<int> furSecond,
      Value<int> accent,
      Value<int> marking,
      Value<DateTime> bornAt,
      Value<DateTime> lastSeenAt,
      Value<double> mood,
      Value<double> hunger,
      Value<double> energy,
      Value<double> affection,
      Value<double> careScore,
      Value<String?> regionName,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String?> portraitPath,
      Value<String> shape,
      Value<String?> countDay,
      Value<double> bondToday,
      Value<int> talksToday,
      Value<double?> activity,
      Value<double?> attachment,
      Value<String?> rhythm,
      Value<Taste?> likeTaste,
      Value<Taste?> dislikeTaste,
      Value<int?> lastStepTotal,
      Value<String?> pocketDay,
      Value<int> pocketCount,
      Value<String?> windowNight,
      Value<String?> giftDay,
      Value<String?> snowDay,
      Value<bool> comfortDue,
      Value<String?> comfortDay,
      Value<DateTime?> pottyAt,
      Value<DateTime?> lastCrisisAt,
      Value<DateTime?> daycareFrom,
      Value<String?> daycareLesson,
      Value<String?> daycareRecitalStats,
      Value<String?> recitalDays,
      Value<String?> wish,
      Value<String?> wishDay,
      Value<bool> wishDone,
      Value<int> paws,
      Value<int> pawsToday,
      Value<String?> pawsDay,
      Value<String?> pawMarks,
      Value<String?> eveningDay,
      Value<String?> rug,
      Value<String?> owned,
      Value<double?> touchX,
      Value<String?> quirk,
      Value<String?> doorNews,
      Value<String?> habit,
      Value<String?> treatsTried,
      Value<String?> treatShares,
      Value<String?> treatPouch,
      Value<String?> treatDay,
      Value<DateTime?> checkupAt,
      Value<int> checkups,
      Value<double?> lastWeight,
    });

class $$PetsTableFilterComposer extends Composer<_$AppDatabase, $PetsTable> {
  $$PetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PetStage, PetStage, String> get stage =>
      $composableBuilder(
        column: $table.stage,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get furMain => $composableBuilder(
    column: $table.furMain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get furSecond => $composableBuilder(
    column: $table.furSecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accent => $composableBuilder(
    column: $table.accent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get marking => $composableBuilder(
    column: $table.marking,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get bornAt => $composableBuilder(
    column: $table.bornAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hunger => $composableBuilder(
    column: $table.hunger,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get affection => $composableBuilder(
    column: $table.affection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get careScore => $composableBuilder(
    column: $table.careScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get regionName => $composableBuilder(
    column: $table.regionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get portraitPath => $composableBuilder(
    column: $table.portraitPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shape => $composableBuilder(
    column: $table.shape,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countDay => $composableBuilder(
    column: $table.countDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bondToday => $composableBuilder(
    column: $table.bondToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get talksToday => $composableBuilder(
    column: $table.talksToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get activity => $composableBuilder(
    column: $table.activity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get attachment => $composableBuilder(
    column: $table.attachment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rhythm => $composableBuilder(
    column: $table.rhythm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Taste?, Taste, String> get likeTaste =>
      $composableBuilder(
        column: $table.likeTaste,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Taste?, Taste, String> get dislikeTaste =>
      $composableBuilder(
        column: $table.dislikeTaste,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get lastStepTotal => $composableBuilder(
    column: $table.lastStepTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pocketDay => $composableBuilder(
    column: $table.pocketDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pocketCount => $composableBuilder(
    column: $table.pocketCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get windowNight => $composableBuilder(
    column: $table.windowNight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get giftDay => $composableBuilder(
    column: $table.giftDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snowDay => $composableBuilder(
    column: $table.snowDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get comfortDue => $composableBuilder(
    column: $table.comfortDue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comfortDay => $composableBuilder(
    column: $table.comfortDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pottyAt => $composableBuilder(
    column: $table.pottyAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCrisisAt => $composableBuilder(
    column: $table.lastCrisisAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get daycareFrom => $composableBuilder(
    column: $table.daycareFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get daycareLesson => $composableBuilder(
    column: $table.daycareLesson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get daycareRecitalStats => $composableBuilder(
    column: $table.daycareRecitalStats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recitalDays => $composableBuilder(
    column: $table.recitalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wish => $composableBuilder(
    column: $table.wish,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wishDay => $composableBuilder(
    column: $table.wishDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wishDone => $composableBuilder(
    column: $table.wishDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paws => $composableBuilder(
    column: $table.paws,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pawsToday => $composableBuilder(
    column: $table.pawsToday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pawsDay => $composableBuilder(
    column: $table.pawsDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pawMarks => $composableBuilder(
    column: $table.pawMarks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eveningDay => $composableBuilder(
    column: $table.eveningDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rug => $composableBuilder(
    column: $table.rug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owned => $composableBuilder(
    column: $table.owned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get touchX => $composableBuilder(
    column: $table.touchX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quirk => $composableBuilder(
    column: $table.quirk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doorNews => $composableBuilder(
    column: $table.doorNews,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habit => $composableBuilder(
    column: $table.habit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get treatsTried => $composableBuilder(
    column: $table.treatsTried,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get treatShares => $composableBuilder(
    column: $table.treatShares,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get treatPouch => $composableBuilder(
    column: $table.treatPouch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get treatDay => $composableBuilder(
    column: $table.treatDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkupAt => $composableBuilder(
    column: $table.checkupAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkups => $composableBuilder(
    column: $table.checkups,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastWeight => $composableBuilder(
    column: $table.lastWeight,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PetsTableOrderingComposer extends Composer<_$AppDatabase, $PetsTable> {
  $$PetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get furMain => $composableBuilder(
    column: $table.furMain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get furSecond => $composableBuilder(
    column: $table.furSecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accent => $composableBuilder(
    column: $table.accent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get marking => $composableBuilder(
    column: $table.marking,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get bornAt => $composableBuilder(
    column: $table.bornAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hunger => $composableBuilder(
    column: $table.hunger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get affection => $composableBuilder(
    column: $table.affection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get careScore => $composableBuilder(
    column: $table.careScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regionName => $composableBuilder(
    column: $table.regionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get portraitPath => $composableBuilder(
    column: $table.portraitPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shape => $composableBuilder(
    column: $table.shape,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countDay => $composableBuilder(
    column: $table.countDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bondToday => $composableBuilder(
    column: $table.bondToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get talksToday => $composableBuilder(
    column: $table.talksToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get activity => $composableBuilder(
    column: $table.activity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get attachment => $composableBuilder(
    column: $table.attachment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rhythm => $composableBuilder(
    column: $table.rhythm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get likeTaste => $composableBuilder(
    column: $table.likeTaste,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dislikeTaste => $composableBuilder(
    column: $table.dislikeTaste,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastStepTotal => $composableBuilder(
    column: $table.lastStepTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pocketDay => $composableBuilder(
    column: $table.pocketDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pocketCount => $composableBuilder(
    column: $table.pocketCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get windowNight => $composableBuilder(
    column: $table.windowNight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get giftDay => $composableBuilder(
    column: $table.giftDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snowDay => $composableBuilder(
    column: $table.snowDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get comfortDue => $composableBuilder(
    column: $table.comfortDue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comfortDay => $composableBuilder(
    column: $table.comfortDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pottyAt => $composableBuilder(
    column: $table.pottyAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCrisisAt => $composableBuilder(
    column: $table.lastCrisisAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get daycareFrom => $composableBuilder(
    column: $table.daycareFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get daycareLesson => $composableBuilder(
    column: $table.daycareLesson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get daycareRecitalStats => $composableBuilder(
    column: $table.daycareRecitalStats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recitalDays => $composableBuilder(
    column: $table.recitalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wish => $composableBuilder(
    column: $table.wish,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wishDay => $composableBuilder(
    column: $table.wishDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wishDone => $composableBuilder(
    column: $table.wishDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paws => $composableBuilder(
    column: $table.paws,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pawsToday => $composableBuilder(
    column: $table.pawsToday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pawsDay => $composableBuilder(
    column: $table.pawsDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pawMarks => $composableBuilder(
    column: $table.pawMarks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eveningDay => $composableBuilder(
    column: $table.eveningDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rug => $composableBuilder(
    column: $table.rug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owned => $composableBuilder(
    column: $table.owned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get touchX => $composableBuilder(
    column: $table.touchX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quirk => $composableBuilder(
    column: $table.quirk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doorNews => $composableBuilder(
    column: $table.doorNews,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habit => $composableBuilder(
    column: $table.habit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get treatsTried => $composableBuilder(
    column: $table.treatsTried,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get treatShares => $composableBuilder(
    column: $table.treatShares,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get treatPouch => $composableBuilder(
    column: $table.treatPouch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get treatDay => $composableBuilder(
    column: $table.treatDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkupAt => $composableBuilder(
    column: $table.checkupAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkups => $composableBuilder(
    column: $table.checkups,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastWeight => $composableBuilder(
    column: $table.lastWeight,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PetsTable> {
  $$PetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PetStage, String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<int> get furMain =>
      $composableBuilder(column: $table.furMain, builder: (column) => column);

  GeneratedColumn<int> get furSecond =>
      $composableBuilder(column: $table.furSecond, builder: (column) => column);

  GeneratedColumn<int> get accent =>
      $composableBuilder(column: $table.accent, builder: (column) => column);

  GeneratedColumn<int> get marking =>
      $composableBuilder(column: $table.marking, builder: (column) => column);

  GeneratedColumn<DateTime> get bornAt =>
      $composableBuilder(column: $table.bornAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<double> get hunger =>
      $composableBuilder(column: $table.hunger, builder: (column) => column);

  GeneratedColumn<double> get energy =>
      $composableBuilder(column: $table.energy, builder: (column) => column);

  GeneratedColumn<double> get affection =>
      $composableBuilder(column: $table.affection, builder: (column) => column);

  GeneratedColumn<double> get careScore =>
      $composableBuilder(column: $table.careScore, builder: (column) => column);

  GeneratedColumn<String> get regionName => $composableBuilder(
    column: $table.regionName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get portraitPath => $composableBuilder(
    column: $table.portraitPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shape =>
      $composableBuilder(column: $table.shape, builder: (column) => column);

  GeneratedColumn<String> get countDay =>
      $composableBuilder(column: $table.countDay, builder: (column) => column);

  GeneratedColumn<double> get bondToday =>
      $composableBuilder(column: $table.bondToday, builder: (column) => column);

  GeneratedColumn<int> get talksToday => $composableBuilder(
    column: $table.talksToday,
    builder: (column) => column,
  );

  GeneratedColumn<double> get activity =>
      $composableBuilder(column: $table.activity, builder: (column) => column);

  GeneratedColumn<double> get attachment => $composableBuilder(
    column: $table.attachment,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rhythm =>
      $composableBuilder(column: $table.rhythm, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Taste?, String> get likeTaste =>
      $composableBuilder(column: $table.likeTaste, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Taste?, String> get dislikeTaste =>
      $composableBuilder(
        column: $table.dislikeTaste,
        builder: (column) => column,
      );

  GeneratedColumn<int> get lastStepTotal => $composableBuilder(
    column: $table.lastStepTotal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pocketDay =>
      $composableBuilder(column: $table.pocketDay, builder: (column) => column);

  GeneratedColumn<int> get pocketCount => $composableBuilder(
    column: $table.pocketCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get windowNight => $composableBuilder(
    column: $table.windowNight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get giftDay =>
      $composableBuilder(column: $table.giftDay, builder: (column) => column);

  GeneratedColumn<String> get snowDay =>
      $composableBuilder(column: $table.snowDay, builder: (column) => column);

  GeneratedColumn<bool> get comfortDue => $composableBuilder(
    column: $table.comfortDue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comfortDay => $composableBuilder(
    column: $table.comfortDay,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get pottyAt =>
      $composableBuilder(column: $table.pottyAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCrisisAt => $composableBuilder(
    column: $table.lastCrisisAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get daycareFrom => $composableBuilder(
    column: $table.daycareFrom,
    builder: (column) => column,
  );

  GeneratedColumn<String> get daycareLesson => $composableBuilder(
    column: $table.daycareLesson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get daycareRecitalStats => $composableBuilder(
    column: $table.daycareRecitalStats,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recitalDays => $composableBuilder(
    column: $table.recitalDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wish =>
      $composableBuilder(column: $table.wish, builder: (column) => column);

  GeneratedColumn<String> get wishDay =>
      $composableBuilder(column: $table.wishDay, builder: (column) => column);

  GeneratedColumn<bool> get wishDone =>
      $composableBuilder(column: $table.wishDone, builder: (column) => column);

  GeneratedColumn<int> get paws =>
      $composableBuilder(column: $table.paws, builder: (column) => column);

  GeneratedColumn<int> get pawsToday =>
      $composableBuilder(column: $table.pawsToday, builder: (column) => column);

  GeneratedColumn<String> get pawsDay =>
      $composableBuilder(column: $table.pawsDay, builder: (column) => column);

  GeneratedColumn<String> get pawMarks =>
      $composableBuilder(column: $table.pawMarks, builder: (column) => column);

  GeneratedColumn<String> get eveningDay => $composableBuilder(
    column: $table.eveningDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rug =>
      $composableBuilder(column: $table.rug, builder: (column) => column);

  GeneratedColumn<String> get owned =>
      $composableBuilder(column: $table.owned, builder: (column) => column);

  GeneratedColumn<double> get touchX =>
      $composableBuilder(column: $table.touchX, builder: (column) => column);

  GeneratedColumn<String> get quirk =>
      $composableBuilder(column: $table.quirk, builder: (column) => column);

  GeneratedColumn<String> get doorNews =>
      $composableBuilder(column: $table.doorNews, builder: (column) => column);

  GeneratedColumn<String> get habit =>
      $composableBuilder(column: $table.habit, builder: (column) => column);

  GeneratedColumn<String> get treatsTried => $composableBuilder(
    column: $table.treatsTried,
    builder: (column) => column,
  );

  GeneratedColumn<String> get treatShares => $composableBuilder(
    column: $table.treatShares,
    builder: (column) => column,
  );

  GeneratedColumn<String> get treatPouch => $composableBuilder(
    column: $table.treatPouch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get treatDay =>
      $composableBuilder(column: $table.treatDay, builder: (column) => column);

  GeneratedColumn<DateTime> get checkupAt =>
      $composableBuilder(column: $table.checkupAt, builder: (column) => column);

  GeneratedColumn<int> get checkups =>
      $composableBuilder(column: $table.checkups, builder: (column) => column);

  GeneratedColumn<double> get lastWeight => $composableBuilder(
    column: $table.lastWeight,
    builder: (column) => column,
  );
}

class $$PetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PetsTable,
          Pet,
          $$PetsTableFilterComposer,
          $$PetsTableOrderingComposer,
          $$PetsTableAnnotationComposer,
          $$PetsTableCreateCompanionBuilder,
          $$PetsTableUpdateCompanionBuilder,
          (Pet, BaseReferences<_$AppDatabase, $PetsTable, Pet>),
          Pet,
          PrefetchHooks Function()
        > {
  $$PetsTableTableManager(_$AppDatabase db, $PetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<PetStage> stage = const Value.absent(),
                Value<int> furMain = const Value.absent(),
                Value<int> furSecond = const Value.absent(),
                Value<int> accent = const Value.absent(),
                Value<int> marking = const Value.absent(),
                Value<DateTime> bornAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<double> mood = const Value.absent(),
                Value<double> hunger = const Value.absent(),
                Value<double> energy = const Value.absent(),
                Value<double> affection = const Value.absent(),
                Value<double> careScore = const Value.absent(),
                Value<String?> regionName = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> portraitPath = const Value.absent(),
                Value<String> shape = const Value.absent(),
                Value<String?> countDay = const Value.absent(),
                Value<double> bondToday = const Value.absent(),
                Value<int> talksToday = const Value.absent(),
                Value<double?> activity = const Value.absent(),
                Value<double?> attachment = const Value.absent(),
                Value<String?> rhythm = const Value.absent(),
                Value<Taste?> likeTaste = const Value.absent(),
                Value<Taste?> dislikeTaste = const Value.absent(),
                Value<int?> lastStepTotal = const Value.absent(),
                Value<String?> pocketDay = const Value.absent(),
                Value<int> pocketCount = const Value.absent(),
                Value<String?> windowNight = const Value.absent(),
                Value<String?> giftDay = const Value.absent(),
                Value<String?> snowDay = const Value.absent(),
                Value<bool> comfortDue = const Value.absent(),
                Value<String?> comfortDay = const Value.absent(),
                Value<DateTime?> pottyAt = const Value.absent(),
                Value<DateTime?> lastCrisisAt = const Value.absent(),
                Value<DateTime?> daycareFrom = const Value.absent(),
                Value<String?> daycareLesson = const Value.absent(),
                Value<String?> daycareRecitalStats = const Value.absent(),
                Value<String?> recitalDays = const Value.absent(),
                Value<String?> wish = const Value.absent(),
                Value<String?> wishDay = const Value.absent(),
                Value<bool> wishDone = const Value.absent(),
                Value<int> paws = const Value.absent(),
                Value<int> pawsToday = const Value.absent(),
                Value<String?> pawsDay = const Value.absent(),
                Value<String?> pawMarks = const Value.absent(),
                Value<String?> eveningDay = const Value.absent(),
                Value<String?> rug = const Value.absent(),
                Value<String?> owned = const Value.absent(),
                Value<double?> touchX = const Value.absent(),
                Value<String?> quirk = const Value.absent(),
                Value<String?> doorNews = const Value.absent(),
                Value<String?> habit = const Value.absent(),
                Value<String?> treatsTried = const Value.absent(),
                Value<String?> treatShares = const Value.absent(),
                Value<String?> treatPouch = const Value.absent(),
                Value<String?> treatDay = const Value.absent(),
                Value<DateTime?> checkupAt = const Value.absent(),
                Value<int> checkups = const Value.absent(),
                Value<double?> lastWeight = const Value.absent(),
              }) => PetsCompanion(
                id: id,
                name: name,
                stage: stage,
                furMain: furMain,
                furSecond: furSecond,
                accent: accent,
                marking: marking,
                bornAt: bornAt,
                lastSeenAt: lastSeenAt,
                mood: mood,
                hunger: hunger,
                energy: energy,
                affection: affection,
                careScore: careScore,
                regionName: regionName,
                latitude: latitude,
                longitude: longitude,
                portraitPath: portraitPath,
                shape: shape,
                countDay: countDay,
                bondToday: bondToday,
                talksToday: talksToday,
                activity: activity,
                attachment: attachment,
                rhythm: rhythm,
                likeTaste: likeTaste,
                dislikeTaste: dislikeTaste,
                lastStepTotal: lastStepTotal,
                pocketDay: pocketDay,
                pocketCount: pocketCount,
                windowNight: windowNight,
                giftDay: giftDay,
                snowDay: snowDay,
                comfortDue: comfortDue,
                comfortDay: comfortDay,
                pottyAt: pottyAt,
                lastCrisisAt: lastCrisisAt,
                daycareFrom: daycareFrom,
                daycareLesson: daycareLesson,
                daycareRecitalStats: daycareRecitalStats,
                recitalDays: recitalDays,
                wish: wish,
                wishDay: wishDay,
                wishDone: wishDone,
                paws: paws,
                pawsToday: pawsToday,
                pawsDay: pawsDay,
                pawMarks: pawMarks,
                eveningDay: eveningDay,
                rug: rug,
                owned: owned,
                touchX: touchX,
                quirk: quirk,
                doorNews: doorNews,
                habit: habit,
                treatsTried: treatsTried,
                treatShares: treatShares,
                treatPouch: treatPouch,
                treatDay: treatDay,
                checkupAt: checkupAt,
                checkups: checkups,
                lastWeight: lastWeight,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required PetStage stage,
                required int furMain,
                required int furSecond,
                required int accent,
                Value<int> marking = const Value.absent(),
                required DateTime bornAt,
                required DateTime lastSeenAt,
                required double mood,
                required double hunger,
                required double energy,
                required double affection,
                Value<double> careScore = const Value.absent(),
                Value<String?> regionName = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> portraitPath = const Value.absent(),
                Value<String> shape = const Value.absent(),
                Value<String?> countDay = const Value.absent(),
                Value<double> bondToday = const Value.absent(),
                Value<int> talksToday = const Value.absent(),
                Value<double?> activity = const Value.absent(),
                Value<double?> attachment = const Value.absent(),
                Value<String?> rhythm = const Value.absent(),
                Value<Taste?> likeTaste = const Value.absent(),
                Value<Taste?> dislikeTaste = const Value.absent(),
                Value<int?> lastStepTotal = const Value.absent(),
                Value<String?> pocketDay = const Value.absent(),
                Value<int> pocketCount = const Value.absent(),
                Value<String?> windowNight = const Value.absent(),
                Value<String?> giftDay = const Value.absent(),
                Value<String?> snowDay = const Value.absent(),
                Value<bool> comfortDue = const Value.absent(),
                Value<String?> comfortDay = const Value.absent(),
                Value<DateTime?> pottyAt = const Value.absent(),
                Value<DateTime?> lastCrisisAt = const Value.absent(),
                Value<DateTime?> daycareFrom = const Value.absent(),
                Value<String?> daycareLesson = const Value.absent(),
                Value<String?> daycareRecitalStats = const Value.absent(),
                Value<String?> recitalDays = const Value.absent(),
                Value<String?> wish = const Value.absent(),
                Value<String?> wishDay = const Value.absent(),
                Value<bool> wishDone = const Value.absent(),
                Value<int> paws = const Value.absent(),
                Value<int> pawsToday = const Value.absent(),
                Value<String?> pawsDay = const Value.absent(),
                Value<String?> pawMarks = const Value.absent(),
                Value<String?> eveningDay = const Value.absent(),
                Value<String?> rug = const Value.absent(),
                Value<String?> owned = const Value.absent(),
                Value<double?> touchX = const Value.absent(),
                Value<String?> quirk = const Value.absent(),
                Value<String?> doorNews = const Value.absent(),
                Value<String?> habit = const Value.absent(),
                Value<String?> treatsTried = const Value.absent(),
                Value<String?> treatShares = const Value.absent(),
                Value<String?> treatPouch = const Value.absent(),
                Value<String?> treatDay = const Value.absent(),
                Value<DateTime?> checkupAt = const Value.absent(),
                Value<int> checkups = const Value.absent(),
                Value<double?> lastWeight = const Value.absent(),
              }) => PetsCompanion.insert(
                id: id,
                name: name,
                stage: stage,
                furMain: furMain,
                furSecond: furSecond,
                accent: accent,
                marking: marking,
                bornAt: bornAt,
                lastSeenAt: lastSeenAt,
                mood: mood,
                hunger: hunger,
                energy: energy,
                affection: affection,
                careScore: careScore,
                regionName: regionName,
                latitude: latitude,
                longitude: longitude,
                portraitPath: portraitPath,
                shape: shape,
                countDay: countDay,
                bondToday: bondToday,
                talksToday: talksToday,
                activity: activity,
                attachment: attachment,
                rhythm: rhythm,
                likeTaste: likeTaste,
                dislikeTaste: dislikeTaste,
                lastStepTotal: lastStepTotal,
                pocketDay: pocketDay,
                pocketCount: pocketCount,
                windowNight: windowNight,
                giftDay: giftDay,
                snowDay: snowDay,
                comfortDue: comfortDue,
                comfortDay: comfortDay,
                pottyAt: pottyAt,
                lastCrisisAt: lastCrisisAt,
                daycareFrom: daycareFrom,
                daycareLesson: daycareLesson,
                daycareRecitalStats: daycareRecitalStats,
                recitalDays: recitalDays,
                wish: wish,
                wishDay: wishDay,
                wishDone: wishDone,
                paws: paws,
                pawsToday: pawsToday,
                pawsDay: pawsDay,
                pawMarks: pawMarks,
                eveningDay: eveningDay,
                rug: rug,
                owned: owned,
                touchX: touchX,
                quirk: quirk,
                doorNews: doorNews,
                habit: habit,
                treatsTried: treatsTried,
                treatShares: treatShares,
                treatPouch: treatPouch,
                treatDay: treatDay,
                checkupAt: checkupAt,
                checkups: checkups,
                lastWeight: lastWeight,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PetsTable,
      Pet,
      $$PetsTableFilterComposer,
      $$PetsTableOrderingComposer,
      $$PetsTableAnnotationComposer,
      $$PetsTableCreateCompanionBuilder,
      $$PetsTableUpdateCompanionBuilder,
      (Pet, BaseReferences<_$AppDatabase, $PetsTable, Pet>),
      Pet,
      PrefetchHooks Function()
    >;
typedef $$MemoriesTableCreateCompanionBuilder =
    MemoriesCompanion Function({
      Value<int> id,
      required String content,
      required DateTime createdAt,
      Value<bool> pinned,
    });
typedef $$MemoriesTableUpdateCompanionBuilder =
    MemoriesCompanion Function({
      Value<int> id,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<bool> pinned,
    });

class $$MemoriesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoriesTable> {
  $$MemoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoriesTable> {
  $$MemoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoriesTable> {
  $$MemoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);
}

class $$MemoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoriesTable,
          Memory,
          $$MemoriesTableFilterComposer,
          $$MemoriesTableOrderingComposer,
          $$MemoriesTableAnnotationComposer,
          $$MemoriesTableCreateCompanionBuilder,
          $$MemoriesTableUpdateCompanionBuilder,
          (Memory, BaseReferences<_$AppDatabase, $MemoriesTable, Memory>),
          Memory,
          PrefetchHooks Function()
        > {
  $$MemoriesTableTableManager(_$AppDatabase db, $MemoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
              }) => MemoriesCompanion(
                id: id,
                content: content,
                createdAt: createdAt,
                pinned: pinned,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String content,
                required DateTime createdAt,
                Value<bool> pinned = const Value.absent(),
              }) => MemoriesCompanion.insert(
                id: id,
                content: content,
                createdAt: createdAt,
                pinned: pinned,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoriesTable,
      Memory,
      $$MemoriesTableFilterComposer,
      $$MemoriesTableOrderingComposer,
      $$MemoriesTableAnnotationComposer,
      $$MemoriesTableCreateCompanionBuilder,
      $$MemoriesTableUpdateCompanionBuilder,
      (Memory, BaseReferences<_$AppDatabase, $MemoriesTable, Memory>),
      Memory,
      PrefetchHooks Function()
    >;
typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      Value<int> id,
      required String kind,
      required String detail,
      required DateTime at,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<int> id,
      Value<String> kind,
      Value<String> detail,
      Value<DateTime> at,
    });

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          Event,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
          Event,
          PrefetchHooks Function()
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> detail = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
              }) => EventsCompanion(id: id, kind: kind, detail: detail, at: at),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String detail,
                required DateTime at,
              }) => EventsCompanion.insert(
                id: id,
                kind: kind,
                detail: detail,
                at: at,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      Event,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (Event, BaseReferences<_$AppDatabase, $EventsTable, Event>),
      Event,
      PrefetchHooks Function()
    >;
typedef $$DiariesTableCreateCompanionBuilder =
    DiariesCompanion Function({
      Value<int> id,
      required String day,
      required String content,
      required DateTime createdAt,
      Value<bool> byAi,
    });
typedef $$DiariesTableUpdateCompanionBuilder =
    DiariesCompanion Function({
      Value<int> id,
      Value<String> day,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<bool> byAi,
    });

class $$DiariesTableFilterComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get byAi => $composableBuilder(
    column: $table.byAi,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiariesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get byAi => $composableBuilder(
    column: $table.byAi,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiariesTable> {
  $$DiariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get byAi =>
      $composableBuilder(column: $table.byAi, builder: (column) => column);
}

class $$DiariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiariesTable,
          Diary,
          $$DiariesTableFilterComposer,
          $$DiariesTableOrderingComposer,
          $$DiariesTableAnnotationComposer,
          $$DiariesTableCreateCompanionBuilder,
          $$DiariesTableUpdateCompanionBuilder,
          (Diary, BaseReferences<_$AppDatabase, $DiariesTable, Diary>),
          Diary,
          PrefetchHooks Function()
        > {
  $$DiariesTableTableManager(_$AppDatabase db, $DiariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> byAi = const Value.absent(),
              }) => DiariesCompanion(
                id: id,
                day: day,
                content: content,
                createdAt: createdAt,
                byAi: byAi,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String day,
                required String content,
                required DateTime createdAt,
                Value<bool> byAi = const Value.absent(),
              }) => DiariesCompanion.insert(
                id: id,
                day: day,
                content: content,
                createdAt: createdAt,
                byAi: byAi,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiariesTable,
      Diary,
      $$DiariesTableFilterComposer,
      $$DiariesTableOrderingComposer,
      $$DiariesTableAnnotationComposer,
      $$DiariesTableCreateCompanionBuilder,
      $$DiariesTableUpdateCompanionBuilder,
      (Diary, BaseReferences<_$AppDatabase, $DiariesTable, Diary>),
      Diary,
      PrefetchHooks Function()
    >;
typedef $$FindsTableCreateCompanionBuilder =
    FindsCompanion Function({
      required String itemId,
      Value<int> count,
      Value<int> giftCount,
      Value<int> rowid,
    });
typedef $$FindsTableUpdateCompanionBuilder =
    FindsCompanion Function({
      Value<String> itemId,
      Value<int> count,
      Value<int> giftCount,
      Value<int> rowid,
    });

class $$FindsTableFilterComposer extends Composer<_$AppDatabase, $FindsTable> {
  $$FindsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get giftCount => $composableBuilder(
    column: $table.giftCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FindsTableOrderingComposer
    extends Composer<_$AppDatabase, $FindsTable> {
  $$FindsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get giftCount => $composableBuilder(
    column: $table.giftCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FindsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FindsTable> {
  $$FindsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<int> get giftCount =>
      $composableBuilder(column: $table.giftCount, builder: (column) => column);
}

class $$FindsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FindsTable,
          Find,
          $$FindsTableFilterComposer,
          $$FindsTableOrderingComposer,
          $$FindsTableAnnotationComposer,
          $$FindsTableCreateCompanionBuilder,
          $$FindsTableUpdateCompanionBuilder,
          (Find, BaseReferences<_$AppDatabase, $FindsTable, Find>),
          Find,
          PrefetchHooks Function()
        > {
  $$FindsTableTableManager(_$AppDatabase db, $FindsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FindsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FindsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FindsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> giftCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FindsCompanion(
                itemId: itemId,
                count: count,
                giftCount: giftCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                Value<int> count = const Value.absent(),
                Value<int> giftCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FindsCompanion.insert(
                itemId: itemId,
                count: count,
                giftCount: giftCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FindsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FindsTable,
      Find,
      $$FindsTableFilterComposer,
      $$FindsTableOrderingComposer,
      $$FindsTableAnnotationComposer,
      $$FindsTableCreateCompanionBuilder,
      $$FindsTableUpdateCompanionBuilder,
      (Find, BaseReferences<_$AppDatabase, $FindsTable, Find>),
      Find,
      PrefetchHooks Function()
    >;
typedef $$CarriedTableCreateCompanionBuilder =
    CarriedCompanion Function({
      Value<int> id,
      required String itemId,
      required FindSource source,
      Value<bool> gift,
      required DateTime createdAt,
    });
typedef $$CarriedTableUpdateCompanionBuilder =
    CarriedCompanion Function({
      Value<int> id,
      Value<String> itemId,
      Value<FindSource> source,
      Value<bool> gift,
      Value<DateTime> createdAt,
    });

class $$CarriedTableFilterComposer
    extends Composer<_$AppDatabase, $CarriedTable> {
  $$CarriedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FindSource, FindSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get gift => $composableBuilder(
    column: $table.gift,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CarriedTableOrderingComposer
    extends Composer<_$AppDatabase, $CarriedTable> {
  $$CarriedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get gift => $composableBuilder(
    column: $table.gift,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CarriedTableAnnotationComposer
    extends Composer<_$AppDatabase, $CarriedTable> {
  $$CarriedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FindSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get gift =>
      $composableBuilder(column: $table.gift, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CarriedTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CarriedTable,
          CarriedItem,
          $$CarriedTableFilterComposer,
          $$CarriedTableOrderingComposer,
          $$CarriedTableAnnotationComposer,
          $$CarriedTableCreateCompanionBuilder,
          $$CarriedTableUpdateCompanionBuilder,
          (
            CarriedItem,
            BaseReferences<_$AppDatabase, $CarriedTable, CarriedItem>,
          ),
          CarriedItem,
          PrefetchHooks Function()
        > {
  $$CarriedTableTableManager(_$AppDatabase db, $CarriedTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CarriedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CarriedTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CarriedTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<FindSource> source = const Value.absent(),
                Value<bool> gift = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CarriedCompanion(
                id: id,
                itemId: itemId,
                source: source,
                gift: gift,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String itemId,
                required FindSource source,
                Value<bool> gift = const Value.absent(),
                required DateTime createdAt,
              }) => CarriedCompanion.insert(
                id: id,
                itemId: itemId,
                source: source,
                gift: gift,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CarriedTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CarriedTable,
      CarriedItem,
      $$CarriedTableFilterComposer,
      $$CarriedTableOrderingComposer,
      $$CarriedTableAnnotationComposer,
      $$CarriedTableCreateCompanionBuilder,
      $$CarriedTableUpdateCompanionBuilder,
      (CarriedItem, BaseReferences<_$AppDatabase, $CarriedTable, CarriedItem>),
      CarriedItem,
      PrefetchHooks Function()
    >;
typedef $$PlacementsTableCreateCompanionBuilder =
    PlacementsCompanion Function({
      required String slot,
      required String itemId,
      Value<int> rowid,
    });
typedef $$PlacementsTableUpdateCompanionBuilder =
    PlacementsCompanion Function({
      Value<String> slot,
      Value<String> itemId,
      Value<int> rowid,
    });

class $$PlacementsTableFilterComposer
    extends Composer<_$AppDatabase, $PlacementsTable> {
  $$PlacementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlacementsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlacementsTable> {
  $$PlacementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlacementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlacementsTable> {
  $$PlacementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);
}

class $$PlacementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlacementsTable,
          Placement,
          $$PlacementsTableFilterComposer,
          $$PlacementsTableOrderingComposer,
          $$PlacementsTableAnnotationComposer,
          $$PlacementsTableCreateCompanionBuilder,
          $$PlacementsTableUpdateCompanionBuilder,
          (
            Placement,
            BaseReferences<_$AppDatabase, $PlacementsTable, Placement>,
          ),
          Placement,
          PrefetchHooks Function()
        > {
  $$PlacementsTableTableManager(_$AppDatabase db, $PlacementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlacementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlacementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlacementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> slot = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  PlacementsCompanion(slot: slot, itemId: itemId, rowid: rowid),
          createCompanionCallback:
              ({
                required String slot,
                required String itemId,
                Value<int> rowid = const Value.absent(),
              }) => PlacementsCompanion.insert(
                slot: slot,
                itemId: itemId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlacementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlacementsTable,
      Placement,
      $$PlacementsTableFilterComposer,
      $$PlacementsTableOrderingComposer,
      $$PlacementsTableAnnotationComposer,
      $$PlacementsTableCreateCompanionBuilder,
      $$PlacementsTableUpdateCompanionBuilder,
      (Placement, BaseReferences<_$AppDatabase, $PlacementsTable, Placement>),
      Placement,
      PrefetchHooks Function()
    >;
typedef $$TricksTableCreateCompanionBuilder =
    TricksCompanion Function({
      required String trick,
      Value<int> attempts,
      Value<int> successes,
      Value<int> days,
      Value<String?> lastDay,
      Value<String?> learnedDay,
      Value<int> rowid,
    });
typedef $$TricksTableUpdateCompanionBuilder =
    TricksCompanion Function({
      Value<String> trick,
      Value<int> attempts,
      Value<int> successes,
      Value<int> days,
      Value<String?> lastDay,
      Value<String?> learnedDay,
      Value<int> rowid,
    });

class $$TricksTableFilterComposer
    extends Composer<_$AppDatabase, $TricksTable> {
  $$TricksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trick => $composableBuilder(
    column: $table.trick,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get successes => $composableBuilder(
    column: $table.successes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastDay => $composableBuilder(
    column: $table.lastDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learnedDay => $composableBuilder(
    column: $table.learnedDay,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TricksTableOrderingComposer
    extends Composer<_$AppDatabase, $TricksTable> {
  $$TricksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trick => $composableBuilder(
    column: $table.trick,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get successes => $composableBuilder(
    column: $table.successes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastDay => $composableBuilder(
    column: $table.lastDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learnedDay => $composableBuilder(
    column: $table.learnedDay,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TricksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TricksTable> {
  $$TricksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trick =>
      $composableBuilder(column: $table.trick, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get successes =>
      $composableBuilder(column: $table.successes, builder: (column) => column);

  GeneratedColumn<int> get days =>
      $composableBuilder(column: $table.days, builder: (column) => column);

  GeneratedColumn<String> get lastDay =>
      $composableBuilder(column: $table.lastDay, builder: (column) => column);

  GeneratedColumn<String> get learnedDay => $composableBuilder(
    column: $table.learnedDay,
    builder: (column) => column,
  );
}

class $$TricksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TricksTable,
          TrickRow,
          $$TricksTableFilterComposer,
          $$TricksTableOrderingComposer,
          $$TricksTableAnnotationComposer,
          $$TricksTableCreateCompanionBuilder,
          $$TricksTableUpdateCompanionBuilder,
          (TrickRow, BaseReferences<_$AppDatabase, $TricksTable, TrickRow>),
          TrickRow,
          PrefetchHooks Function()
        > {
  $$TricksTableTableManager(_$AppDatabase db, $TricksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TricksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TricksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TricksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trick = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> successes = const Value.absent(),
                Value<int> days = const Value.absent(),
                Value<String?> lastDay = const Value.absent(),
                Value<String?> learnedDay = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TricksCompanion(
                trick: trick,
                attempts: attempts,
                successes: successes,
                days: days,
                lastDay: lastDay,
                learnedDay: learnedDay,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trick,
                Value<int> attempts = const Value.absent(),
                Value<int> successes = const Value.absent(),
                Value<int> days = const Value.absent(),
                Value<String?> lastDay = const Value.absent(),
                Value<String?> learnedDay = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TricksCompanion.insert(
                trick: trick,
                attempts: attempts,
                successes: successes,
                days: days,
                lastDay: lastDay,
                learnedDay: learnedDay,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TricksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TricksTable,
      TrickRow,
      $$TricksTableFilterComposer,
      $$TricksTableOrderingComposer,
      $$TricksTableAnnotationComposer,
      $$TricksTableCreateCompanionBuilder,
      $$TricksTableUpdateCompanionBuilder,
      (TrickRow, BaseReferences<_$AppDatabase, $TricksTable, TrickRow>),
      TrickRow,
      PrefetchHooks Function()
    >;
typedef $$FriendsTableCreateCompanionBuilder =
    FriendsCompanion Function({
      required String guestId,
      Value<int> bond,
      Value<int> days,
      Value<String?> lastDay,
      Value<String?> name,
      Value<int> streak,
      Value<int> rowid,
    });
typedef $$FriendsTableUpdateCompanionBuilder =
    FriendsCompanion Function({
      Value<String> guestId,
      Value<int> bond,
      Value<int> days,
      Value<String?> lastDay,
      Value<String?> name,
      Value<int> streak,
      Value<int> rowid,
    });

class $$FriendsTableFilterComposer
    extends Composer<_$AppDatabase, $FriendsTable> {
  $$FriendsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get guestId => $composableBuilder(
    column: $table.guestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bond => $composableBuilder(
    column: $table.bond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastDay => $composableBuilder(
    column: $table.lastDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FriendsTableOrderingComposer
    extends Composer<_$AppDatabase, $FriendsTable> {
  $$FriendsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get guestId => $composableBuilder(
    column: $table.guestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bond => $composableBuilder(
    column: $table.bond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastDay => $composableBuilder(
    column: $table.lastDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FriendsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FriendsTable> {
  $$FriendsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get guestId =>
      $composableBuilder(column: $table.guestId, builder: (column) => column);

  GeneratedColumn<int> get bond =>
      $composableBuilder(column: $table.bond, builder: (column) => column);

  GeneratedColumn<int> get days =>
      $composableBuilder(column: $table.days, builder: (column) => column);

  GeneratedColumn<String> get lastDay =>
      $composableBuilder(column: $table.lastDay, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get streak =>
      $composableBuilder(column: $table.streak, builder: (column) => column);
}

class $$FriendsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FriendsTable,
          FriendRow,
          $$FriendsTableFilterComposer,
          $$FriendsTableOrderingComposer,
          $$FriendsTableAnnotationComposer,
          $$FriendsTableCreateCompanionBuilder,
          $$FriendsTableUpdateCompanionBuilder,
          (FriendRow, BaseReferences<_$AppDatabase, $FriendsTable, FriendRow>),
          FriendRow,
          PrefetchHooks Function()
        > {
  $$FriendsTableTableManager(_$AppDatabase db, $FriendsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FriendsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FriendsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FriendsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> guestId = const Value.absent(),
                Value<int> bond = const Value.absent(),
                Value<int> days = const Value.absent(),
                Value<String?> lastDay = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FriendsCompanion(
                guestId: guestId,
                bond: bond,
                days: days,
                lastDay: lastDay,
                name: name,
                streak: streak,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String guestId,
                Value<int> bond = const Value.absent(),
                Value<int> days = const Value.absent(),
                Value<String?> lastDay = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FriendsCompanion.insert(
                guestId: guestId,
                bond: bond,
                days: days,
                lastDay: lastDay,
                name: name,
                streak: streak,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FriendsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FriendsTable,
      FriendRow,
      $$FriendsTableFilterComposer,
      $$FriendsTableOrderingComposer,
      $$FriendsTableAnnotationComposer,
      $$FriendsTableCreateCompanionBuilder,
      $$FriendsTableUpdateCompanionBuilder,
      (FriendRow, BaseReferences<_$AppDatabase, $FriendsTable, FriendRow>),
      FriendRow,
      PrefetchHooks Function()
    >;
typedef $$KnownDogsTableCreateCompanionBuilder =
    KnownDogsCompanion Function({
      required String id,
      required String shape,
      required int furMain,
      required int furSecond,
      required int marking,
      Value<bool> puppy,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$KnownDogsTableUpdateCompanionBuilder =
    KnownDogsCompanion Function({
      Value<String> id,
      Value<String> shape,
      Value<int> furMain,
      Value<int> furSecond,
      Value<int> marking,
      Value<bool> puppy,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$KnownDogsTableFilterComposer
    extends Composer<_$AppDatabase, $KnownDogsTable> {
  $$KnownDogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shape => $composableBuilder(
    column: $table.shape,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get furMain => $composableBuilder(
    column: $table.furMain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get furSecond => $composableBuilder(
    column: $table.furSecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get marking => $composableBuilder(
    column: $table.marking,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get puppy => $composableBuilder(
    column: $table.puppy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KnownDogsTableOrderingComposer
    extends Composer<_$AppDatabase, $KnownDogsTable> {
  $$KnownDogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shape => $composableBuilder(
    column: $table.shape,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get furMain => $composableBuilder(
    column: $table.furMain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get furSecond => $composableBuilder(
    column: $table.furSecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get marking => $composableBuilder(
    column: $table.marking,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get puppy => $composableBuilder(
    column: $table.puppy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KnownDogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KnownDogsTable> {
  $$KnownDogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shape =>
      $composableBuilder(column: $table.shape, builder: (column) => column);

  GeneratedColumn<int> get furMain =>
      $composableBuilder(column: $table.furMain, builder: (column) => column);

  GeneratedColumn<int> get furSecond =>
      $composableBuilder(column: $table.furSecond, builder: (column) => column);

  GeneratedColumn<int> get marking =>
      $composableBuilder(column: $table.marking, builder: (column) => column);

  GeneratedColumn<bool> get puppy =>
      $composableBuilder(column: $table.puppy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$KnownDogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KnownDogsTable,
          KnownDogRow,
          $$KnownDogsTableFilterComposer,
          $$KnownDogsTableOrderingComposer,
          $$KnownDogsTableAnnotationComposer,
          $$KnownDogsTableCreateCompanionBuilder,
          $$KnownDogsTableUpdateCompanionBuilder,
          (
            KnownDogRow,
            BaseReferences<_$AppDatabase, $KnownDogsTable, KnownDogRow>,
          ),
          KnownDogRow,
          PrefetchHooks Function()
        > {
  $$KnownDogsTableTableManager(_$AppDatabase db, $KnownDogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnownDogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KnownDogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KnownDogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> shape = const Value.absent(),
                Value<int> furMain = const Value.absent(),
                Value<int> furSecond = const Value.absent(),
                Value<int> marking = const Value.absent(),
                Value<bool> puppy = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KnownDogsCompanion(
                id: id,
                shape: shape,
                furMain: furMain,
                furSecond: furSecond,
                marking: marking,
                puppy: puppy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String shape,
                required int furMain,
                required int furSecond,
                required int marking,
                Value<bool> puppy = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => KnownDogsCompanion.insert(
                id: id,
                shape: shape,
                furMain: furMain,
                furSecond: furSecond,
                marking: marking,
                puppy: puppy,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KnownDogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KnownDogsTable,
      KnownDogRow,
      $$KnownDogsTableFilterComposer,
      $$KnownDogsTableOrderingComposer,
      $$KnownDogsTableAnnotationComposer,
      $$KnownDogsTableCreateCompanionBuilder,
      $$KnownDogsTableUpdateCompanionBuilder,
      (
        KnownDogRow,
        BaseReferences<_$AppDatabase, $KnownDogsTable, KnownDogRow>,
      ),
      KnownDogRow,
      PrefetchHooks Function()
    >;
typedef $$KinderPhotosTableCreateCompanionBuilder =
    KinderPhotosCompanion Function({
      required String day,
      required String scene,
      required String friends,
      required PetStage stage,
      Value<String?> trick,
      Value<int> rowid,
    });
typedef $$KinderPhotosTableUpdateCompanionBuilder =
    KinderPhotosCompanion Function({
      Value<String> day,
      Value<String> scene,
      Value<String> friends,
      Value<PetStage> stage,
      Value<String?> trick,
      Value<int> rowid,
    });

class $$KinderPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $KinderPhotosTable> {
  $$KinderPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scene => $composableBuilder(
    column: $table.scene,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get friends => $composableBuilder(
    column: $table.friends,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PetStage, PetStage, String> get stage =>
      $composableBuilder(
        column: $table.stage,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get trick => $composableBuilder(
    column: $table.trick,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KinderPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $KinderPhotosTable> {
  $$KinderPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scene => $composableBuilder(
    column: $table.scene,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get friends => $composableBuilder(
    column: $table.friends,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trick => $composableBuilder(
    column: $table.trick,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KinderPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $KinderPhotosTable> {
  $$KinderPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get scene =>
      $composableBuilder(column: $table.scene, builder: (column) => column);

  GeneratedColumn<String> get friends =>
      $composableBuilder(column: $table.friends, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PetStage, String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<String> get trick =>
      $composableBuilder(column: $table.trick, builder: (column) => column);
}

class $$KinderPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KinderPhotosTable,
          KinderPhotoRow,
          $$KinderPhotosTableFilterComposer,
          $$KinderPhotosTableOrderingComposer,
          $$KinderPhotosTableAnnotationComposer,
          $$KinderPhotosTableCreateCompanionBuilder,
          $$KinderPhotosTableUpdateCompanionBuilder,
          (
            KinderPhotoRow,
            BaseReferences<_$AppDatabase, $KinderPhotosTable, KinderPhotoRow>,
          ),
          KinderPhotoRow,
          PrefetchHooks Function()
        > {
  $$KinderPhotosTableTableManager(_$AppDatabase db, $KinderPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KinderPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KinderPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KinderPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<String> scene = const Value.absent(),
                Value<String> friends = const Value.absent(),
                Value<PetStage> stage = const Value.absent(),
                Value<String?> trick = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KinderPhotosCompanion(
                day: day,
                scene: scene,
                friends: friends,
                stage: stage,
                trick: trick,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                required String scene,
                required String friends,
                required PetStage stage,
                Value<String?> trick = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KinderPhotosCompanion.insert(
                day: day,
                scene: scene,
                friends: friends,
                stage: stage,
                trick: trick,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KinderPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KinderPhotosTable,
      KinderPhotoRow,
      $$KinderPhotosTableFilterComposer,
      $$KinderPhotosTableOrderingComposer,
      $$KinderPhotosTableAnnotationComposer,
      $$KinderPhotosTableCreateCompanionBuilder,
      $$KinderPhotosTableUpdateCompanionBuilder,
      (
        KinderPhotoRow,
        BaseReferences<_$AppDatabase, $KinderPhotosTable, KinderPhotoRow>,
      ),
      KinderPhotoRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PetsTableTableManager get pets => $$PetsTableTableManager(_db, _db.pets);
  $$MemoriesTableTableManager get memories =>
      $$MemoriesTableTableManager(_db, _db.memories);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$DiariesTableTableManager get diaries =>
      $$DiariesTableTableManager(_db, _db.diaries);
  $$FindsTableTableManager get finds =>
      $$FindsTableTableManager(_db, _db.finds);
  $$CarriedTableTableManager get carried =>
      $$CarriedTableTableManager(_db, _db.carried);
  $$PlacementsTableTableManager get placements =>
      $$PlacementsTableTableManager(_db, _db.placements);
  $$TricksTableTableManager get tricks =>
      $$TricksTableTableManager(_db, _db.tricks);
  $$FriendsTableTableManager get friends =>
      $$FriendsTableTableManager(_db, _db.friends);
  $$KnownDogsTableTableManager get knownDogs =>
      $$KnownDogsTableTableManager(_db, _db.knownDogs);
  $$KinderPhotosTableTableManager get kinderPhotos =>
      $$KinderPhotosTableTableManager(_db, _db.kinderPhotos);
}
