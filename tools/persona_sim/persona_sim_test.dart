// 가상 테스터: 사람 유형별로 며칠을 실제 앱 규칙에 흘려 보고, 앱을 열 때마다 강아지가
// 무엇을 하고 있었는지 적는다. 재미를 판정하지는 못한다(그건 사람 몫). "열 때마다 자고 있다",
// "반김이 매번 같다" 같은 문제를 숫자로 잡는 용도다.
//
// 실행: flutter test tools/persona_sim/persona_sim_test.dart
// 결과: build/persona_sim/<유형>.md 와 build/persona_sim/summary.md
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mypet/data/database.dart';
import 'package:mypet/pet/pet_controller.dart';
import 'package:mypet/pet/pet_rules.dart';
import 'package:mypet/pet/tricks.dart';

/// 한 번 열어서 하는 일.
enum Act { look, pet, feed, play, trick, goodnight, talk }

class Session {
  const Session(this.at, this.seconds, this.acts);

  final DateTime at;
  final int seconds;
  final List<Act> acts;
}

class Persona {
  const Persona(this.id, this.label, this.sessions);

  final String id;
  final String label;
  final List<Session> Function(DateTime start, Random r) sessions;
}

/// 2026-10-05은 월요일이다. 2주를 돌린다.
final start = DateTime(2026, 10, 5);
const days = 14;

DateTime at(DateTime day, int h, int m) =>
    DateTime(day.year, day.month, day.day, h, m);

bool weekend(DateTime d) => d.weekday >= 6;

List<Session> everyDay(
  DateTime s,
  Random r,
  List<Session> Function(DateTime day, Random r) plan,
) => [for (var i = 0; i < days; i++) ...plan(s.add(Duration(days: i)), r)];

/// 분 단위로 조금씩 흔든다. 사람은 매일 같은 분에 열지 않는다.
DateTime jitter(DateTime t, Random r, [int minutes = 20]) =>
    t.add(Duration(minutes: r.nextInt(minutes * 2 + 1) - minutes));

final personas = [
  Persona(
    'midnight_worker',
    '자정형 직장인 (07:50 엘리베이터 10초, 12:40 점심 1분, 20:30 지하철 3분, 00:30 침대 10분)',
    (s, r) => everyDay(s, r, (d, r) {
      if (weekend(d)) {
        return [
          Session(jitter(at(d, 10, 40), r), 120, [Act.look, Act.pet]),
          Session(jitter(at(d, 15, 0), r), 300, [
            Act.play,
            Act.trick,
            Act.feed,
          ]),
          Session(jitter(at(d, 23, 50), r), 480, [
            Act.pet,
            Act.talk,
            Act.goodnight,
          ]),
        ];
      }
      final next = d.add(const Duration(days: 1));
      return [
        Session(jitter(at(d, 7, 50), r, 5), 10, [Act.look]),
        Session(jitter(at(d, 12, 40), r, 10), 60, [Act.pet, Act.feed]),
        Session(jitter(at(d, 20, 30), r), 180, [Act.play]),
        Session(jitter(at(next, 0, 30), r), 600, [
          Act.pet,
          Act.talk,
          Act.trick,
          Act.goodnight,
        ]),
      ];
    }),
  ),
  Persona(
    'early_bird',
    '아침형 (06:30 기상, 12:00 점심, 21:00 저녁, 22:30 취침)',
    (s, r) => everyDay(
      s,
      r,
      (d, r) => [
        Session(jitter(at(d, 6, 30), r, 10), 120, [Act.pet, Act.feed]),
        Session(jitter(at(d, 12, 0), r, 15), 60, [Act.look]),
        Session(jitter(at(d, 21, 0), r), 300, [Act.play, Act.trick]),
        Session(jitter(at(d, 22, 30), r, 10), 120, [Act.goodnight]),
      ],
    ),
  ),
  Persona(
    'shift_worker',
    '교대 근무 (정해진 시간 없이 하루 세 번)',
    (s, r) => everyDay(
      s,
      r,
      (d, r) => [
        for (var i = 0; i < 3; i++)
          Session(at(d, r.nextInt(24), r.nextInt(60)), 60 + r.nextInt(240), [
            Act.pet,
            if (r.nextBool()) Act.play,
            if (r.nextBool()) Act.feed,
          ]),
      ]..sort((a, b) => a.at.compareTo(b.at)),
    ),
  ),
  Persona(
    'weekend_only',
    '주말만 (토·일 하루 두 번)',
    (s, r) => everyDay(
      s,
      r,
      (d, r) => weekend(d)
          ? [
              Session(jitter(at(d, 11, 0), r), 300, [
                Act.pet,
                Act.feed,
                Act.play,
              ]),
              Session(jitter(at(d, 22, 0), r), 300, [Act.trick, Act.goodnight]),
            ]
          : const <Session>[],
    ),
  ),
  Persona(
    'away_three_days',
    '사흘 비움 (평소 하루 두 번, 둘째 주 화~목 안 열기)',
    (s, r) => everyDay(s, r, (d, r) {
      final i = d.difference(s).inDays;
      if (i >= 8 && i <= 10) return const <Session>[];
      return [
        Session(jitter(at(d, 8, 30), r), 60, [Act.pet]),
        Session(jitter(at(d, 22, 0), r), 240, [Act.play, Act.feed]),
      ];
    }),
  ),
  Persona(
    'short_sleeper',
    '밤이 짧은 사람 (07:00 기상, 20:30 공놀이, 00:50 침대에서 10분, 밤 6시간)',
    (s, r) => everyDay(s, r, (d, r) {
      final next = d.add(const Duration(days: 1));
      return [
        Session(jitter(at(d, 7, 0), r, 5), 30, [Act.look]),
        Session(jitter(at(d, 12, 40), r, 10), 60, [Act.pet, Act.feed]),
        Session(jitter(at(d, 20, 30), r), 240, [Act.play, Act.trick]),
        Session(jitter(at(next, 0, 50), r, 5), 600, [Act.pet, Act.goodnight]),
      ];
    }),
  ),
  Persona(
    'irregular_sleeper',
    '들쭉날쭉 (평균 23:30에 자고 06:30에 일어나지만 날마다 ±1시간)',
    (s, r) => everyDay(s, r, (d, r) {
      return [
        Session(jitter(at(d, 6, 30), r, 60), 60, [Act.pet, Act.feed]),
        Session(jitter(at(d, 19, 30), r), 300, [Act.play, Act.trick]),
        Session(jitter(at(d, 23, 30), r, 60), 300, [Act.pet, Act.goodnight]),
      ];
    }),
  ),
  Persona(
    'just_looking',
    '보기만 (하루 세 번 20초, 아무것도 안 누름)',
    (s, r) => everyDay(
      s,
      r,
      (d, r) => [
        Session(jitter(at(d, 9, 0), r), 20, [Act.look]),
        Session(jitter(at(d, 14, 0), r), 20, [Act.look]),
        Session(jitter(at(d, 23, 30), r), 20, [Act.look]),
      ],
    ),
  ),
];

/// 성격마다 결과가 크게 다르다. 한 마리로만 보면 드문 성격의 숫자를 모두의 숫자로 착각한다.
const profiles = [
  (name: '차분', activity: 0.2, attachment: 0.25),
  (name: '보통', activity: 0.5, attachment: 0.5),
  (name: '활발', activity: 0.85, attachment: 0.8),
];

typedef Profile = ({String name, double activity, double attachment});

class OpenLog {
  OpenLog(
    this.at,
    this.away,
    this.greeting,
    this.first,
    this.bubble,
    this.tired,
  );

  final DateTime at;
  final Duration away;
  final Greeting greeting;
  final List<Behavior> first;
  final String? bubble;
  final bool tired;
  final seen = <Behavior>{};
  final bubbles = <String>[];
}

Future<({List<(String, String)> rows, String log})> run(
  Persona p,
  Profile profile,
) async {
  final db = AppDatabase(NativeDatabase.memory());
  var now = start.subtract(const Duration(hours: 2));
  final random = Random(7);
  final born = await db.createPet(
    name: '콩이',
    stage: PetStage.puppy,
    furMain: 1,
    furSecond: 2,
    marking: 3,
    now: now,
  );
  await db.savePet(
    born.copyWith(
      activity: Value(profile.activity),
      attachment: Value(profile.attachment),
    ),
  );
  final logs = <OpenLog>[];
  // AI를 켰다면 불렀을 횟수: 크게 반길 때 속마음, 명령이 아닌 말 걸기, 하루 한 번 일기.
  var aiGreet = 0, aiTalk = 0, playRefused = 0;
  final activeDays = <String>{};
  final sessions = p.sessions(start, Random(11));
  for (final s in sessions) {
    now = s.at;
    // 폰이 앱을 자주 내려서 열 때마다 새로 켜진다고 본다(실제 기록 17번 중 17번이 새로 켜기였다).
    final pet = (await db.loadPet())!;
    final c = PetController(db, pet, random: random, clock: () => now);
    final away = now.difference(pet.lastSeenAt);
    final greeting = c.wake();
    await c.collected;
    if (greeting == Greeting.big || greeting == Greeting.huge) aiGreet++;
    activeDays.add(dayKey(petDate(now)));
    final log = OpenLog(
      now,
      away,
      greeting,
      [c.step.behavior],
      c.bubble,
      c.stats.energy < tiredEnergy,
    );
    void second() {
      c.tick(1);
      now = now.add(const Duration(seconds: 1));
      log.seen.add(c.step.behavior);
      final b = c.bubble;
      if (b != null && (log.bubbles.isEmpty || log.bubbles.last != b)) {
        log.bubbles.add(b);
      }
      if (log.first.length < 3 && log.first.last != c.step.behavior) {
        log.first.add(c.step.behavior);
      }
    }

    var left = s.seconds;
    for (final a in s.acts) {
      if (left <= 0) break;
      switch (a) {
        case Act.look:
          break;
        case Act.pet:
          c.interact(Interaction.pet);
        case Act.feed when c.stats.hunger > 40:
          c.interact(Interaction.feed);
        case Act.feed:
          break;
        case Act.play:
          c.takeOutBall();
          if (c.ball == Ball.none) playRefused++;
          for (var i = 0; i < 4 && c.ball != Ball.none; i++) {
            if (c.ball == Ball.carried) c.arrived();
            if (!c.throwBall()) break;
            c.ballLanded();
            c.arrived();
            second();
            c.arrived();
          }
          c.putBallAway();
        case Act.trick:
          for (var i = 0; i < 3; i++) {
            c.command(Trick.values[random.nextInt(2)]);
            second();
            second();
          }
        case Act.goodnight:
          if (await c.talk('잘 자') == TalkOutcome.noBrain) aiTalk++;
        case Act.talk:
          if (await c.talk('오늘 좀 힘들었어') == TalkOutcome.noBrain) aiTalk++;
      }
      for (var i = 0; i < 15 && left > 0; i++, left--) {
        second();
      }
    }
    while (left-- > 0) {
      second();
    }
    logs.add(log);
    c.sleepApp();
    await pumpEventQueue();
    c.dispose();
  }
  final pet = (await db.loadPet())!;
  final tricks = await db.loadTricks();
  final diaries = await db.allDiaries();
  final finds = await db.allFinds();
  await db.close();
  return report(
    logs,
    pet,
    tricks,
    diaries.length,
    finds.length,
    diaries.isEmpty ? '' : diaries.first.content,
    (greet: aiGreet, talk: aiTalk, diary: activeDays.length),
    playRefused,
  );
}

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String dayLabel(DateTime t) =>
    '${t.month}/${t.day}(${const ['월', '화', '수', '목', '금', '토', '일'][t.weekday - 1]})';

String awayLabel(Duration d) => d.inMinutes < 60
    ? '${d.inMinutes}분'
    : d.inHours < 48
    ? '${d.inHours}시간'
    : '${d.inDays}일';

({List<(String, String)> rows, String log}) report(
  List<OpenLog> logs,
  Pet pet,
  Map<Trick, TrickProgress> tricks,
  int diaries,
  int finds,
  String sampleDiary,
  ({int greet, int talk, int diary}) ai,
  int playRefused,
) {
  final asleep = logs.where((l) => l.first.first == Behavior.sleep).length;
  final asleepWhole = logs
      .where((l) => l.seen.length == 1 && l.seen.first == Behavior.sleep)
      .length;
  final greet = <Greeting, int>{};
  for (final l in logs) {
    greet[l.greeting] = (greet[l.greeting] ?? 0) + 1;
  }
  final scenes = <String>{for (final l in logs) l.first.join('>')};
  final bubbles = <String>{for (final l in logs) ...l.bubbles};
  final learned = tricks.values.where((t) => t.learned).length;
  String pct(int n) =>
      logs.isEmpty ? '-' : '${(n * 100 / logs.length).round()}%';
  final tired = logs.where((l) => l.tired).length;
  final rows = [
    ('연 횟수', '${logs.length}'),
    ('열었을 때 자고 있음', '${pct(asleep)} ($asleep)'),
    ('보는 내내 잠만 잠', '${pct(asleepWhole)} ($asleepWhole)'),
    ('열었을 때 지쳐 있음(기운 20 밑)', '${pct(tired)} ($tired)'),
    ('놀자 했는데 지쳐서 못 놂', '$playRefused번'),
    (
      '반김',
      Greeting.values
          .where((g) => (greet[g] ?? 0) > 0)
          .map((g) => '${g.name} ${greet[g]}')
          .join(', '),
    ),
    ('서로 다른 첫 장면(처음 3동작)', '${scenes.length}가지'),
    ('서로 다른 속마음', '${bubbles.length}개'),
    (
      '2주 뒤 친밀도',
      '${pet.affection.round()} (${intimacyLabel(intimacyOf(pet.affection))})',
    ),
    ('배운 개인기', '$learned개'),
    // 산책은 흉내 내지 않으니 산책 몫(5분에 하나)은 빠진 수다.
    ('2주 발도장(산책 빼고)', '${pet.paws}개'),
    ('일기(AI 없음, 폰이 씀)', '$diaries편'),
    ('도감', '$finds종'),
    (
      'AI를 켰다면 하루 호출',
      '${((ai.greet + ai.talk + ai.diary) / days).toStringAsFixed(1)}번',
    ),
  ];
  final b = StringBuffer()
    ..writeln('일기 예시: $sampleDiary')
    ..writeln()
    ..writeln('| 날짜 | 시각 | 비운 시간 | 반김 | 처음 동작 | 첫 속마음 |')
    ..writeln('|---|---|---|---|---|---|');
  for (final l in logs) {
    b.writeln(
      '| ${dayLabel(l.at)} | ${hhmm(l.at)} | ${awayLabel(l.away)} | '
      '${l.greeting.name} | ${l.first.map((x) => x.name).join(' > ')} | '
      '${l.bubble ?? (l.bubbles.isEmpty ? '' : l.bubbles.first)} |',
    );
  }
  return (rows: rows, log: b.toString());
}

void main() {
  test('가상 테스터: 유형별 2주', () async {
    final dir = Directory('build/persona_sim')..createSync(recursive: true);
    final summary = StringBuffer('# 가상 테스터 요약\n\n');
    for (final p in personas) {
      final results = [for (final t in profiles) await run(p, t)];
      final table = StringBuffer()
        ..writeln('# ${p.label}')
        ..writeln()
        ..writeln(
          '| 항목 | ${profiles.map((t) => '${t.name}(활발 ${t.activity}, 애착 ${t.attachment})').join(' | ')} |',
        )
        ..writeln('|---|${profiles.map((_) => '---').join('|')}|');
      for (var i = 0; i < results.first.rows.length; i++) {
        table.writeln(
          '| ${results.first.rows[i].$1} | ${results.map((r) => r.rows[i].$2).join(' | ')} |',
        );
      }
      File(
        '${dir.path}/${p.id}.md',
      ).writeAsStringSync('$table\n## 보통 성격이 연 순간들\n\n${results[1].log}');
      summary
        ..writeln(table)
        ..writeln();
    }
    File('${dir.path}/summary.md').writeAsStringSync(summary.toString());
    // ignore: avoid_print
    print(summary);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
