import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../pet/friends.dart';
import '../pet/guest.dart';
import '../pet/pet_rules.dart';
import '../pet/shapes.dart';
import '../pet/treasure.dart';
import '../pet/tricks.dart';

part 'database.g.dart';

class Pets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get stage => textEnum<PetStage>()();
  IntColumn get furMain => integer()();
  IntColumn get furSecond => integer()();
  IntColumn get accent => integer()();
  IntColumn get marking => integer().withDefault(const Constant(0xFF914F28))();
  DateTimeColumn get bornAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();
  RealColumn get mood => real()();
  RealColumn get hunger => real()();
  RealColumn get energy => real()();
  RealColumn get affection => real()();
  RealColumn get careScore => real().withDefault(const Constant(0))();
  TextColumn get regionName => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get portraitPath => text().nullable()();

  /// 강아지 모양 틀 id(lib/pet/shapes.dart). 모양을 고르기 전의 펫은 모두 파피용 그림이었다.
  TextColumn get shape => text().withDefault(const Constant('papillon'))();

  /// 하루 한도(대화 횟수, 친밀도 몫)를 센 날. 앱을 다시 켜도 한도가 이어지게 여기 둔다.
  TextColumn get countDay => text().nullable()();
  RealColumn get bondToday => real().withDefault(const Constant(0))();
  IntColumn get talksToday => integer().withDefault(const Constant(0))();

  /// 타고난 성격(0~1). 비어 있으면 컨트롤러가 펫 번호로 정해 저장한다.
  RealColumn get activity => real().nullable()();
  RealColumn get attachment => real().nullable()();

  /// 주인 생활 리듬(JSON, lib/pet/rhythm.dart).
  TextColumn get rhythm => text().nullable()();
  TextColumn get likeTaste => textEnum<Taste>().nullable()();
  TextColumn get dislikeTaste => textEnum<Taste>().nullable()();

  /// 폰 누적 걸음을 마지막으로 읽은 값. 다음에 열 때 이 값과의 차이만 쓴다.
  IntColumn get lastStepTotal => integer().nullable()();

  /// 마지막으로 읽은 기기 계수까지 걸었지만 아직 주머니 발견물로 바꾸지 않은 걸음.
  IntColumn get pocketStepCredit => integer().withDefault(const Constant(0))();

  /// 산책에서 먼저 기기 계수를 읽었고, 첫 주머니 수집 선물은 아직 받지 않았다.
  BoolColumn get pocketWelcomePending =>
      boolean().withDefault(const Constant(false))();
  TextColumn get pocketDay => text().nullable()();
  IntColumn get pocketCount => integer().withDefault(const Constant(0))();
  TextColumn get windowNight => text().nullable()();
  TextColumn get giftDay => text().nullable()();

  /// 올겨울 첫눈을 본 날. 그날 하루 창문에 코 자국이 남는다.
  TextColumn get snowDay => text().nullable()();

  /// 주인이 지친 말을 했다. 다음에 열 때 좋아하는 걸 하나 챙겨 온다.
  BoolColumn get comfortDue => boolean().withDefault(const Constant(false))();
  TextColumn get comfortDay => text().nullable()();

  /// 마지막으로 쉬한 때(패드든 바닥이든). 앱을 열어 둔 동안 세 시간 지나면 다시 마렵다.
  DateTimeColumn get pottyAt => dateTime().nullable()();

  /// 위기 안내를 띄운 때. 그 뒤 하루는 위로 선물로 안내를 가볍게 만들지 않는다.
  DateTimeColumn get lastCrisisAt => dateTime().nullable()();

  /// 유치원에 맡긴 때. 하원(데리러 가거나 저녁 7시 버스)하면 비운다.
  DateTimeColumn get daycareFrom => dateTime().nullable()();

  /// 맡길 때 고른 오늘 수업(개인기 이름, 자유 놀이면 'free'). 하원하면 비운다.
  TextColumn get daycareLesson => text().nullable()();

  /// 15시 발표회 상태. 그 뒤 앱 프로세스가 끝나도 다음 날 배고픔으로 판정하지 않게 보관한다.
  TextColumn get daycareRecitalStats => text().nullable()();

  /// 유치원 발표회에서 도장을 받은 날들(dayKey를 쉼표로). 방 벽 도장판과 훈련 수첩에 쓴다.
  TextColumn get recitalDays => text().nullable()();

  /// 오늘의 소원(lib/pet/wish.dart Wish.encode), 그 펫의 하루(dayKey), 들어줬는지.
  TextColumn get wish => text().nullable()();
  TextColumn get wishDay => text().nullable()();
  BoolColumn get wishDone => boolean().withDefault(const Constant(false))();

  /// 발도장(lib/pet/paws.dart). 가진 수, 오늘(펫의 하루) 번 수와 그날, 받은 이정표와 한 번 해 본 것(쉼표, 'hand'는 손 베개),
  /// 저녁 이야기를 센 날, 깐 방석과 바꾼 꾸미기(쉼표). 목걸이 색은 accent 칸을 쓴다.
  IntColumn get paws => integer().withDefault(const Constant(0))();
  IntColumn get pawsToday => integer().withDefault(const Constant(0))();
  TextColumn get pawsDay => text().nullable()();
  TextColumn get pawMarks => text().nullable()();
  TextColumn get eveningDay => text().nullable()();
  TextColumn get rug => text().nullable()();
  TextColumn get owned => text().nullable()();

  /// 주인이 마지막으로 쓰다듬거나 손을 내민 바닥 자리(0~1). 가족이 되면 밤에 거기서 잔다.
  RealColumn get touchX => real().nullable()();

  /// 우리 애만의 버릇(lib/pet/quirks.dart의 이름). 처음 열 때 정해 남긴다.
  TextColumn get quirk => text().nullable()();

  /// 아침 현관 소식('펫의 날짜:물건 이름', 안 뒀거나 주인이 챙겼으면 '날짜:-'). 하루에 한 번.
  TextColumn get doorNews => text().nullable()();

  /// 카페 친구한테 옮은 버릇('버릇 이름|손님 id'). 그 친구를 오래 못 보면 사라진다.
  TextColumn get habit => text().nullable()();

  /// 먹여 본 간식과 반응('간식 id:love', 쉼표). 도감의 입맛 칸.
  TextColumn get treatsTried => text().nullable()();

  /// 오늘 간식을 나눠 준 카페 친구('dayKey|손님 id,손님 id'). 친구마다 하루 한 번.
  TextColumn get treatShares => text().nullable()();

  /// 간식 주머니(간식 id를 쉼표로)와 마지막으로 간식을 산 날(dayKey). 하루 한 번만 산다.
  TextColumn get treatPouch => text().nullable()();
  TextColumn get treatDay => text().nullable()();

  /// 마지막 검진 때·검진 횟수·그때 몸무게. 건강 수첩에 지난번과 비교해 보인다.
  DateTimeColumn get checkupAt => dateTime().nullable()();
  IntColumn get checkups => integer().withDefault(const Constant(0))();
  RealColumn get lastWeight => real().nullable()();
}

// 한 대화에 넘겨 온 기억 수. 고정한 기억부터 이 자리를 채운다.
const conversationMemoryLimit = 5;

enum MemoryPinResult { saved, full, missing }

class Memories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  // 같은 초의 두 대화는 응답 도착 순서 대신 주인이 말한 순서로 나눈다.
  IntColumn get heardEventId => integer().nullable()();
}

/// 그날 있었던 일. 일기의 재료다.
@TableIndex(name: 'events_kind_at', columns: {#kind, #at, #id})
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()();
  TextColumn get detail => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get walkMap => text().nullable()();
}

class Diaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get day => text().unique()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// AI가 쓴 일기에만 AI 표시를 붙인다(AI 기본법 고지). AI가 없을 때는 폰이 쓴다.
  BoolColumn get byAi => boolean().withDefault(const Constant(true))();
}

/// 도감. 날짜를 보여 주지 않으려고 개수만 센다.
class Finds extends Table {
  TextColumn get itemId => text()();
  IntColumn get count => integer().withDefault(const Constant(0))();
  IntColumn get giftCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {itemId};
}

/// 카페 친구 사이. 손님마다 한 줄.
@DataClassName('FriendRow')
class Friends extends Table {
  TextColumn get guestId => text()();

  /// 0 아직 못 만남, 1 낯섦, 2 킁킁, 3 놀이, 4 단짝 (lib/pet/friends.dart의 Bond 순서).
  IntColumn get bond => integer().withDefault(const Constant(0))();
  IntColumn get days => integer().withDefault(const Constant(0))();
  TextColumn get lastDay => text().nullable()();

  /// 주인이 붙인 이름. 유저 입력이라 알림·사용 기록에는 쓰지 않는다.
  TextColumn get name => text().nullable()();

  /// 마지막으로 만난 날까지 며칠 내리 만났는지(lib/pet/friends.dart Friendship.streak).
  IntColumn get streak => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {guestId};
}

/// 주인이 데려온 아는 강아지(친구·가족네)의 생김새. 이름은 카페 친구 이름과 같은 friends 표에 둔다.
/// 사진은 털색만 뽑고 저장하지 않는다.
@DataClassName('KnownDogRow')
class KnownDogs extends Table {
  TextColumn get id => text()();
  TextColumn get shape => text()();
  IntColumn get furMain => integer()();
  IntColumn get furSecond => integer()();
  IntColumn get marking => integer()();
  BoolColumn get puppy => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 강아지가 주워 와서 아직 주인에게 건네지 않은 물건. 앱을 닫아도 다음에 다시 내민다.
@DataClassName('CarriedItem')
class Carried extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemId => text()();
  TextColumn get source => textEnum<FindSource>()();
  BoolColumn get gift => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class Placements extends Table {
  TextColumn get slot => text()();
  TextColumn get itemId => text()();

  @override
  Set<Column> get primaryKey => {slot};
}

/// 개인기 연습 기록. 개인기마다 한 줄.
@DataClassName('TrickRow')
class Tricks extends Table {
  TextColumn get trick => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get successes => integer().withDefault(const Constant(0))();
  IntColumn get days => integer().withDefault(const Constant(0))();
  TextColumn get lastDay => text().nullable()();

  /// 세 번째로 해내 배운 날(dayKey). 이 칸이 생기기 전에 배운 개인기는 비어 있다.
  TextColumn get learnedDay => text().nullable()();

  @override
  Set<Column> get primaryKey => {trick};
}

/// 유치원 오늘의 한 장(lib/pet/kinder_photo.dart). 하루 한 장, 그날 일기 아래에 붙는다.
/// 성장 단계만 그날 것을 두고 모습·털색은 지금 것으로 그린다.
@DataClassName('KinderPhotoRow')
class KinderPhotos extends Table {
  TextColumn get day => text()();

  /// KinderScene 이름. 모르는 이름이면 그리지 않는다.
  TextColumn get scene => text()();

  /// 같이 찍힌 그날 유치원 친구 id(쉼표).
  TextColumn get friends => text()();
  TextColumn get stage => textEnum<PetStage>()();

  /// 수업 장면이면 그날 수업한 개인기 이름.
  TextColumn get trick => text().nullable()();

  @override
  Set<Column> get primaryKey => {day};
}

@DriftDatabase(
  tables: [
    Pets,
    Memories,
    Events,
    Diaries,
    Finds,
    Carried,
    Placements,
    Tricks,
    Friends,
    KnownDogs,
    KinderPhotos,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'mypet'));

  @override
  int get schemaVersion => 35;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) => transaction(() async {
      if (from < 2) await m.addColumn(pets, pets.marking);
      if (from < 3) await m.createTable(memories);
      if (from < 4) {
        await m.addColumn(pets, pets.careScore);
        await m.addColumn(pets, pets.regionName);
        await m.addColumn(pets, pets.latitude);
        await m.addColumn(pets, pets.longitude);
        await m.addColumn(pets, pets.portraitPath);
        await m.createTable(events);
        await m.createTable(diaries);
      }
      if (from < 5) {
        await m.addColumn(pets, pets.likeTaste);
        await m.addColumn(pets, pets.dislikeTaste);
        await m.addColumn(pets, pets.lastStepTotal);
        await m.addColumn(pets, pets.pocketDay);
        await m.addColumn(pets, pets.pocketCount);
        await m.addColumn(pets, pets.windowNight);
        await m.addColumn(pets, pets.giftDay);
        await m.createTable(finds);
        await m.createTable(carried);
        await m.createTable(placements);
      }
      if (from < 6) {
        await m.addColumn(pets, pets.snowDay);
        await m.addColumn(pets, pets.comfortDue);
      }
      if (from < 7) {
        await m.addColumn(pets, pets.comfortDay);
        await m.addColumn(pets, pets.lastCrisisAt);
      }
      if (from < 8) await m.addColumn(pets, pets.shape);
      if (from < 9) await m.createTable(tricks);
      if (from < 10) {
        await m.addColumn(pets, pets.countDay);
        await m.addColumn(pets, pets.bondToday);
        await m.addColumn(pets, pets.talksToday);
      }
      if (from < 11) {
        await m.addColumn(pets, pets.activity);
        await m.addColumn(pets, pets.attachment);
        await m.addColumn(pets, pets.rhythm);
      }
      // v4 전에서 올라오면 위에서 새 모양으로 만든 표라 칸이 이미 있다.
      if (from >= 4 && from < 12) await m.addColumn(diaries, diaries.byAi);
      // v11~v12에 쓰지 않는 종(species) 칸을 넣었었다.
      if (from >= 11 && from < 13) await m.dropColumn(pets, 'species');
      if (from < 14) await m.addColumn(pets, pets.pottyAt);
      if (from < 15) await m.addColumn(pets, pets.daycareFrom);
      if (from < 16) {
        await m.addColumn(pets, pets.treatPouch);
        await m.addColumn(pets, pets.treatDay);
        await m.addColumn(pets, pets.checkupAt);
        await m.addColumn(pets, pets.checkups);
        await m.addColumn(pets, pets.lastWeight);
      }
      if (from < 17) await m.addColumn(pets, pets.daycareLesson);
      if (from < 18) await m.createTable(friends);
      if (from < 19) await m.createTable(knownDogs);
      // tricks 표는 v9에 생겼다. 그 전에서 올라오면 위에서 새 모양으로 만들어 칸이 이미 있다.
      if (from >= 9 && from < 20) await m.addColumn(tricks, tricks.learnedDay);
      if (from < 20) await m.addColumn(pets, pets.recitalDays);
      if (from < 21) {
        await m.addColumn(pets, pets.wish);
        await m.addColumn(pets, pets.wishDay);
        await m.addColumn(pets, pets.wishDone);
      }
      if (from < 22) {
        await m.addColumn(pets, pets.paws);
        await m.addColumn(pets, pets.pawsToday);
        await m.addColumn(pets, pets.pawsDay);
        await m.addColumn(pets, pets.pawMarks);
        await m.addColumn(pets, pets.eveningDay);
        await m.addColumn(pets, pets.rug);
        await m.addColumn(pets, pets.owned);
      }
      if (from < 23) await m.addColumn(pets, pets.touchX);
      if (from < 24) await m.addColumn(pets, pets.quirk);
      if (from < 25) await m.addColumn(pets, pets.doorNews);
      if (from < 26) {
        await m.addColumn(pets, pets.habit);
        // friends 표는 v18에 생겼다. 그 전에서 올라오면 위에서 새 모양으로 만들어 칸이 이미 있다.
        if (from >= 18) await m.addColumn(friends, friends.streak);
      }
      if (from < 27) await m.addColumn(pets, pets.treatsTried);
      if (from < 28) await m.createTable(kinderPhotos);
      if (from < 29) await m.addColumn(pets, pets.treatShares);
      if (from < 30) await m.addColumn(pets, pets.daycareRecitalStats);
      // v3 전이면 위에서 현재 형태로 기억 표를 처음 만든다.
      if (from >= 3 && from < 31) await m.addColumn(memories, memories.pinned);
      if (from >= 3 && from < 32) {
        await m.addColumn(memories, memories.heardEventId);
      }
      // v4 전에서 올라오면 이미 현재 버전의 하루 기록 표를 만들었다.
      if (from >= 4 && from < 33) await m.addColumn(events, events.walkMap);
      if (from < 33) await m.createIndex(eventsKindAt);
      if (from < 34) await m.addColumn(pets, pets.pocketStepCredit);
      if (from < 35) await m.addColumn(pets, pets.pocketWelcomePending);
      // Drift의 바깥 버전 저장 전에 종료돼도 칸과 버전이 함께 남아야 한다.
      await customStatement('PRAGMA user_version = $to');
    }),
  );

  Future<Pet?> loadPet() => select(pets).getSingleOrNull();

  Future<Pet> createPet({
    required String name,
    required PetStage stage,
    required int furMain,
    required int furSecond,
    required int marking,
    required DateTime now,
    String shape = 'papillon',
    String? regionName,
    double? latitude,
    double? longitude,
    String? portraitPath,
  }) async {
    final id = await into(pets).insert(
      PetsCompanion.insert(
        name: name,
        stage: stage,
        furMain: furMain,
        furSecond: furSecond,
        accent: defaultAccent,
        marking: Value(marking),
        shape: Value(shape),
        bornAt: now,
        lastSeenAt: now,
        mood: 65,
        hunger: 30,
        energy: 80,
        affection: 10,
        regionName: Value(regionName),
        latitude: Value(latitude),
        longitude: Value(longitude),
        portraitPath: Value(portraitPath),
      ),
    );
    return (select(pets)..where((p) => p.id.equals(id))).getSingle();
  }

  Future<void> savePet(Pet pet) => update(pets).replace(pet);

  Future<int> addMemory(String content, DateTime at, {int? heardEventId}) =>
      into(memories).insert(
        MemoriesCompanion.insert(
          content: content,
          createdAt: at,
          heardEventId: Value(heardEventId),
        ),
      );

  Future<List<Memory>> recentMemories(int limit) =>
      (select(memories)
            ..orderBy([
              (m) => OrderingTerm.desc(m.createdAt),
              (m) => OrderingTerm.desc(m.heardEventId),
              (m) => OrderingTerm.desc(m.id),
            ])
            ..limit(limit))
          .get();

  SimpleSelectStatement<$MemoriesTable, Memory> _notebook() =>
      select(memories)..orderBy([
        (m) => OrderingTerm.desc(m.pinned),
        (m) => OrderingTerm.desc(m.createdAt),
        (m) => OrderingTerm.desc(m.heardEventId),
        (m) => OrderingTerm.desc(m.id),
      ]);

  Stream<List<Memory>> watchMemoryNotebook(int limit) =>
      (_notebook()..limit(limit)).watch();

  Future<List<Memory>> conversationMemories() =>
      (_notebook()..limit(conversationMemoryLimit)).get();

  Future<MemoryPinResult> setMemoryPinned(int id, bool pinned) =>
      transaction(() async {
        final entry = await (select(
          memories,
        )..where((m) => m.id.equals(id))).getSingleOrNull();
        if (entry == null) return MemoryPinResult.missing;
        if (entry.pinned == pinned) return MemoryPinResult.saved;
        if (pinned) {
          final total = memories.id.count();
          final query = selectOnly(memories)
            ..addColumns([total])
            ..where(memories.pinned.equals(true));
          final count = (await query.getSingle()).read(total) ?? 0;
          if (count >= conversationMemoryLimit) return MemoryPinResult.full;
        }
        await (update(memories)..where((m) => m.id.equals(id))).write(
          MemoriesCompanion(pinned: Value(pinned)),
        );
        return MemoryPinResult.saved;
      });

  Future<bool> forgetMemory(int id) async =>
      await (delete(memories)..where((m) => m.id.equals(id))).go() == 1;

  // 펫 저장과 함께 남겨, 권한 창에서 프로세스가 끝나도 다음 시작에서 인사를 이어 간다.
  static const _pendingMeeting = 'first_meeting_pending';

  Future<void> queueFirstMeeting(DateTime now) =>
      addEvent(_pendingMeeting, '', now);

  Future<bool> beginFirstMeeting(DateTime now) async {
    final updated =
        await (update(
          events,
        )..where((e) => e.kind.equals(_pendingMeeting))).write(
          EventsCompanion(
            kind: const Value('first_meeting'),
            detail: const Value('처음으로 주인 냄새를 맡았다'),
            at: Value(now),
          ),
        );
    return updated > 0;
  }

  Future<int> describeTalk(int id, String detail) =>
      (update(events)..where((e) => e.id.equals(id) & e.kind.equals('talk')))
          .write(EventsCompanion(detail: Value(detail)));

  Future<int> addEvent(
    String kind,
    String detail,
    DateTime at, {
    String? walkMap,
  }) => into(events).insert(
    EventsCompanion.insert(
      kind: kind,
      detail: detail,
      at: at,
      walkMap: Value(walkMap),
    ),
  );

  /// 산책 문장과 첫 킁킁 자리를 함께 남긴다. 같은 저장 요청을 다시 보내도 한 번만 쓴다.
  Future<bool> storeFinishedWalk(
    DateTime at,
    String detail,
    String map,
    String? spot,
    List<(String, FindSource)> items,
  ) => transaction(() async {
    final existing =
        await (selectOnly(events)
              ..addColumns([events.id])
              ..where(
                events.kind.equals('walk') &
                    events.at.equals(at) &
                    events.walkMap.equals(map),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return false;
    await addEvent('walk', detail, at, walkMap: map);
    for (final (id, source) in items) {
      await addCarried(id, source, at, gift: source == FindSource.gift);
    }
    if (spot == null) return false;
    final date = petDate(at);
    final found =
        await (selectOnly(events)
              ..addColumns([events.id])
              ..where(
                events.kind.equals('walk_spot') &
                    events.detail.equals(spot) &
                    events.at.isBiggerOrEqualValue(petDayStart(date)) &
                    events.at.isSmallerThanValue(
                      petDayStart(date, offsetDays: 1),
                    ),
              )
              ..limit(1))
            .getSingleOrNull();
    if (found != null) return false;
    await addEvent('walk_spot', spot, at);
    return true;
  });

  Stream<List<Event>> watchWalks(int limit) =>
      (select(events)
            ..where((e) => e.kind.equals('walk'))
            ..orderBy([
              (e) => OrderingTerm.desc(e.at),
              (e) => OrderingTerm.desc(e.id),
            ])
            ..limit(limit))
          .watch();

  /// 일기 날짜 [day]의 돌봄 시각과 종류만 읽는다. 자정 뒤 05시 전 기록도 같은 일기에 들어간다.
  Stream<List<({DateTime at, String kind})>> watchDiaryActions(
    DateTime day,
    Iterable<String> kinds,
    int limit,
  ) {
    final start = petDayStart(day);
    final end = petDayStart(day, offsetDays: 1);
    final query = selectOnly(events)
      ..addColumns([events.at, events.kind])
      ..where(
        events.at.isBiggerOrEqualValue(start) &
            events.at.isSmallerThanValue(end) &
            events.kind.isIn(kinds),
      )
      ..orderBy([OrderingTerm.asc(events.at), OrderingTerm.asc(events.id)])
      ..limit(limit);
    return query
        .map((row) => (at: row.read(events.at)!, kind: row.read(events.kind)!))
        .watch();
  }

  /// 입양 생활일에 실제로 있었던 돌봄별 마지막 시각과 첫 재회 표식만 읽는다.
  Future<Map<String, DateTime>> firstDayCareTimes(DateTime previousDay) async {
    final lastAt = events.at.max();
    final kinds = selectOnly(events)
      ..addColumns([events.kind, lastAt])
      ..where(
        events.kind.isIn(const ['first_meeting', 'first_recognition']) |
            (events.kind.isIn(const ['feed', 'play', 'pet', 'walk']) &
                events.at.isBiggerOrEqualValue(petDayStart(previousDay)) &
                events.at.isSmallerThanValue(
                  petDayStart(previousDay, offsetDays: 1),
                )),
      )
      ..groupBy([events.kind]);
    final rows = await kinds.get();
    return {for (final row in rows) row.read(events.kind)!: row.read(lastAt)!};
  }

  /// 호출자가 트랜잭션 안에서 손길이 아직 유효한지 확인하고, 아니면 전체를 되돌린다.
  Future<bool> insertFirstRecognition(DateTime at, String detail) async {
    final prior =
        await (selectOnly(events)
              ..addColumns([events.id])
              ..where(events.kind.equals('first_recognition'))
              ..limit(1))
            .getSingleOrNull();
    if (prior != null) return false;
    await addEvent('first_recognition', detail, at);
    return true;
  }

  Future<List<Event>> eventsOfKind(String kind) =>
      (select(events)..where((e) => e.kind.equals(kind))).get();

  /// [t]가 속한 하루(새벽 5시부터 다음 날 새벽 5시 전까지)에 있었던 일.
  Future<List<Event>> eventsOn(DateTime t) {
    final day = petDate(t);
    final start = petDayStart(day);
    final end = petDayStart(day, offsetDays: 1);
    return (select(events)
          ..where(
            (e) =>
                e.at.isBiggerOrEqualValue(start) &
                e.at.isSmallerThanValue(end) &
                e.kind.equals(_pendingMeeting).not(),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.at)]))
        .get();
  }

  Future<bool> hasDiary(String day) async =>
      await (select(
        diaries,
      )..where((d) => d.day.equals(day))).getSingleOrNull() !=
      null;

  Future<void> addDiary(
    String day,
    String content,
    DateTime now, {
    bool byAi = true,
  }) => into(diaries).insert(
    DiariesCompanion.insert(
      day: day,
      content: content,
      createdAt: now,
      byAi: Value(byAi),
    ),
    mode: InsertMode.insertOrReplace,
  );

  Future<List<Diary>> allDiaries() =>
      (select(diaries)..orderBy([(d) => OrderingTerm.desc(d.day)])).get();

  /// 같은 날 또 맡겨도 오늘의 한 장은 처음 것 하나다.
  Future<void> addKinderPhoto(KinderPhotosCompanion photo) =>
      into(kinderPhotos).insert(photo, mode: InsertMode.insertOrIgnore);

  Future<List<KinderPhotoRow>> allKinderPhotos() => select(kinderPhotos).get();

  Future<KinderPhotoRow?> kinderPhotoOn(String day) =>
      (select(kinderPhotos)..where((p) => p.day.equals(day))).getSingleOrNull();

  Future<List<Find>> allFinds() => select(finds).get();

  Future<void> addFind(String itemId, {required bool gift}) =>
      transaction(() async {
        final old = await (select(
          finds,
        )..where((f) => f.itemId.equals(itemId))).getSingleOrNull();
        await into(finds).insertOnConflictUpdate(
          FindsCompanion.insert(
            itemId: itemId,
            count: Value((old?.count ?? 0) + 1),
            giftCount: Value((old?.giftCount ?? 0) + (gift ? 1 : 0)),
          ),
        );
      });

  Future<List<CarriedItem>> allCarried() =>
      (select(carried)..orderBy([(c) => OrderingTerm.asc(c.id)])).get();

  Future<void> addCarried(
    String itemId,
    FindSource source,
    DateTime at, {
    bool gift = false,
  }) => into(carried).insert(
    CarriedCompanion.insert(
      itemId: itemId,
      source: source,
      gift: Value(gift),
      createdAt: at,
    ),
  );

  Future<void> removeCarried(int id) =>
      (delete(carried)..where((c) => c.id.equals(id))).go();

  Future<Map<String, String>> loadPlacements() async => {
    for (final p in await select(placements).get()) p.slot: p.itemId,
  };

  Future<void> savePlacements(Map<String, String> placed) =>
      transaction(() async {
        await delete(placements).go();
        for (final e in placed.entries) {
          await into(
            placements,
          ).insert(PlacementsCompanion.insert(slot: e.key, itemId: e.value));
        }
      });

  Future<Map<String, Friendship>> loadFriends() async => {
    for (final r in await select(friends).get())
      r.guestId: Friendship(
        bond: Bond.values[r.bond.clamp(0, Bond.values.length - 1)],
        days: r.days,
        lastDay: r.lastDay,
        name: r.name,
        streak: r.streak,
      ),
  };

  Future<void> saveFriend(String guestId, Friendship f) =>
      into(friends).insertOnConflictUpdate(
        FriendsCompanion.insert(
          guestId: guestId,
          bond: Value(f.bond.index),
          days: Value(f.days),
          lastDay: Value(f.lastDay),
          name: Value(f.name),
          streak: Value(f.streak),
        ),
      );

  /// 데려온 순서. 같은 시각이면 id 순(앱을 다시 켜도 같은 순서라 같은 애가 먼저 앉는다).
  Future<List<KnownDogRow>> loadKnownDogs() =>
      (select(knownDogs)..orderBy([
            (d) => OrderingTerm.asc(d.createdAt),
            (d) => OrderingTerm.asc(d.id),
          ]))
          .get();

  /// 생김새와 이름(friends)을 한 번에 쓴다. 중간에 멈춰 이름 없는 아는 강아지가 남지 않게.
  Future<void> addKnownDog(Guest g, Friendship f, DateTime at) =>
      transaction(() async {
        await into(knownDogs).insert(
          KnownDogsCompanion.insert(
            id: g.id,
            shape: g.shape,
            furMain: g.main,
            furSecond: g.second,
            marking: g.marking,
            puppy: Value(g.puppy),
            createdAt: at,
          ),
        );
        await saveFriend(g.id, f);
      });

  Future<void> updateKnownDog(Guest g, Friendship f) => transaction(() async {
    final changed = await (update(knownDogs)..where((d) => d.id.equals(g.id)))
        .write(
          KnownDogsCompanion(
            shape: Value(g.shape),
            furMain: Value(g.main),
            furSecond: Value(g.second),
            marking: Value(g.marking),
            puppy: Value(g.puppy),
          ),
        );
    if (changed > 0) await saveFriend(g.id, f);
  });

  /// 아는 강아지를 지운다. 사이와 이름도 같이 지운다.
  Future<void> deleteKnownDog(String id) => transaction(() async {
    await (delete(knownDogs)..where((d) => d.id.equals(id))).go();
    await (delete(friends)..where((f) => f.guestId.equals(id))).go();
  });

  Future<Map<Trick, TrickProgress>> loadTricks() async {
    final byName = Trick.values.asNameMap();
    return {
      for (final r in await select(tricks).get())
        ?byName[r.trick]: TrickProgress(
          attempts: r.attempts,
          successes: r.successes,
          days: r.days,
          lastDay: r.lastDay,
          learnedDay: r.learnedDay,
        ),
    };
  }

  Future<void> saveTrick(Trick t, TrickProgress p) =>
      into(tricks).insertOnConflictUpdate(
        TricksCompanion.insert(
          trick: t.name,
          attempts: Value(p.attempts),
          successes: Value(p.successes),
          days: Value(p.days),
          lastDay: Value(p.lastDay),
          learnedDay: Value(p.learnedDay),
        ),
      );

  /// 온보딩부터 다시 하기. 펫과 기억, 일기, 모은 물건, 개인기, 친구를 모두 지운다.
  /// 아는 강아지도 지운다. 이름은 friends 표에 있어서 남겨 두면 이름 없는 애로 남았다.
  Future<void> resetAll() => transaction(() async {
    await delete(knownDogs).go();
    await delete(kinderPhotos).go();
    await delete(tricks).go();
    await delete(friends).go();
    await delete(placements).go();
    await delete(carried).go();
    await delete(finds).go();
    await delete(diaries).go();
    await delete(events).go();
    await delete(memories).go();
    await delete(pets).go();
  });
}
