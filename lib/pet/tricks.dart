import 'dart:math';

import 'cues.dart';
import 'pet_rules.dart';

/// 말로 가르치는 개인기. 순서가 놀이 칸 칩 순서다.
enum Trick {
  sit('앉아', 0),
  come('이리 와', 0),
  down('엎드려', 1),
  wait('기다려', 1),
  spin('돌아', 2),
  jump('점프', 1),
  fetch('물어와', 2),

  /// 자기 이름 알아듣기. 칩은 없고 이름을 부를 때마다 연습이 된다. 처음엔 반쯤만 돌아본다.
  name('이름', 0, chip: false),

  /// 배변훈련. 쉬가 마려워 킁킁댈 때 패드로 데려가면 한 번 성공. 세 번이면 혼자 패드로 간다. 실수해도 벌은 없다.
  potty('배변', 2, chip: false);

  const Trick(this.label, this.difficulty, {this.chip = true});

  final String label;
  final int difficulty;

  /// 놀이 칸에 칩으로 보이는지.
  final bool chip;
}

const learnAfter = 3;

/// '간식 냄새' 킁킁이 시작된 뒤 이만큼 안에 간식을 주면 칭찬이 된다.
const praiseWithin = Duration(seconds: 12);

class TrickProgress {
  const TrickProgress({
    this.attempts = 0,
    this.successes = 0,
    this.days = 0,
    this.lastDay,
    this.learnedDay,
  });

  final int attempts;
  final int successes;

  /// 연습한 서로 다른 날 수. 배운 뒤에는 이만큼 별이 붙는다(최대 3).
  final int days;

  /// 마지막으로 연습한 날(dayKey).
  final String? lastDay;

  /// 배운 날(dayKey). 이 기록이 생기기 전에 배운 개인기는 null.
  final String? learnedDay;

  bool get learned => successes >= learnAfter;

  int get stars => learned ? min(days, 3) : 0;

  /// 해낸 직후 간식으로 칭찬받았다. 배우는 중이면 한 번 더 해낸 것으로 친다(연습 날은 그대로).
  /// 시도도 하나 올린다. 안 올리면 해낸 수가 시도보다 많아져 다음 확률이 오히려 내려갔다.
  TrickProgress praised(String today) {
    if (learned) return this;
    final s = successes + 1;
    return TrickProgress(
      attempts: attempts + 1,
      successes: s,
      days: days,
      lastDay: lastDay,
      learnedDay: learnedDay ?? (s >= learnAfter ? today : null),
    );
  }

  TrickProgress practiced({required bool success, required String today}) {
    final s = successes + (success ? 1 : 0);
    return TrickProgress(
      attempts: attempts + 1,
      successes: s,
      days: lastDay == today ? days : days + 1,
      lastDay: today,
      // 문턱을 넘는 날만 적는다. 기록이 생기기 전에 배운 개인기에 오늘 날짜가 붙지 않게.
      learnedDay: learnedDay ?? (!learned && s >= learnAfter ? today : null),
    );
  }
}

/// 연습할수록, 자고 일어날수록 잘한다. 배고프거나 기분이 나쁘면 잠깐 덜 한다.
double trickChance(
  Trick t,
  TrickProgress p,
  PetStats s, {
  required String today,
}) {
  final earlierDays = p.lastDay == today ? p.days - 1 : p.days;
  var c =
      0.35 -
      0.1 * t.difficulty +
      0.15 * p.successes +
      0.06 * (p.attempts - p.successes) +
      0.1 * earlierDays;
  if (p.learned) c = max(c, 0.85);
  if (p.stars >= 3) c = 0.97;
  c += switch (intimacyOf(s.affection)) {
    Intimacy.stranger => -0.1,
    Intimacy.friend => 0.0,
    Intimacy.family => 0.05,
  };
  if (s.hunger > 75) c -= 0.15;
  if (s.mood < 30) c -= 0.1;
  return c.clamp(0.1, 0.97);
}

List<PetStep> trickSteps(Trick t, {String? thought}) => switch (t) {
  Trick.sit => [PetStep(Behavior.sit, 3, thought: thought)],
  Trick.come => [
    PetStep(Behavior.run, 4, targetX: 0.5, cue: Cue.yip, thought: thought),
    const PetStep(Behavior.sit, 2),
  ],
  Trick.down => [PetStep(Behavior.lieBeside, 3.5, thought: thought)],
  Trick.wait => [PetStep(Behavior.sit, 6, thought: thought)],
  Trick.spin => [PetStep(Behavior.spin, 2.4, thought: thought)],
  Trick.jump => [PetStep(Behavior.jump, 1.3, cue: Cue.yip, thought: thought)],
  // 공을 물어 오는 흐름은 컨트롤러가 공 상태에 맞춰 끼운다. 여기 것은 공을 찾는 시늉이다.
  Trick.fetch => [
    PetStep(Behavior.sniff, 1.5, cue: Cue.sniff, thought: thought),
  ],
  Trick.name => [
    PetStep(Behavior.run, 4, targetX: 0.5, cue: Cue.yip, thought: thought),
    const PetStep(Behavior.sit, 2),
  ],
  // 배변은 시켜서 하는 게 아니라 컨트롤러가 마려울 때 흐름을 만든다.
  Trick.potty => [PetStep(Behavior.sit, 2, thought: thought)],
};

class TrickTry {
  const TrickTry(
    this.steps, {
    required this.success,
    this.counted = true,
    this.learnedNow = false,
  });

  final List<PetStep> steps;
  final bool success;

  /// 지쳐서 안 한 건 연습으로 치지 않는다.
  final bool counted;
  final bool learnedNow;
}

const _unsure = ['이렇게?', '맞지? 맞지?', '됐다!'];
const _proud = ['쉽지!', '나 잘하지?', '또 시켜 줘!'];
const _nameUnsure = ['응? 나 불렀어?', '…나?'];
const _nameProud = ['왔어! 왔어!', '불렀지? 나 왔어!'];

/// 개인기를 시켰을 때 할 일. [misses]는 이 개인기를 연달아 못 한 횟수,
/// [known]은 한 번이라도 해낸 개인기다. 헷갈리면 아는 걸 대신 해 본다.
TrickTry tryTrick(
  Trick t,
  TrickProgress p,
  PetStats s, {
  required String today,
  required int misses,
  required Random random,
  Iterable<Trick> known = const [],
  bool sure = false,
}) {
  if (s.energy < tiredEnergy) {
    return const TrickTry(
      [PetStep(Behavior.lieBeside, 4, cue: Cue.sigh, thought: '졸려… 나중에 할래.')],
      success: false,
      counted: false,
    );
  }
  // 세 번째에는 꼭 해낸다. 처음 가르칠 때 내리 실패하면 그만두게 된다.
  // [sure]: 이미 하고 있는 걸 시켰다(공을 물고 오는 중의 '물어와').
  final success =
      sure ||
      misses >= 2 ||
      random.nextDouble() < trickChance(t, p, s, today: today);
  if (success) {
    final learnedNow = p.successes + 1 == learnAfter;
    final named = t == Trick.name;
    final String? praise;
    if (learnedNow) {
      praise = named ? '내 이름이다! 나 알아!' : '해냈다! 나 이거 할 줄 알아!';
    } else if (p.learned) {
      final proud = named ? _nameProud : _proud;
      praise = proud[random.nextInt(proud.length)];
    } else {
      praise = null;
    }
    final unsure = named ? _nameUnsure : _unsure;
    return TrickTry(
      [
        ...trickSteps(
          t,
          thought: p.learned || learnedNow
              ? null
              : unsure[random.nextInt(unsure.length)],
        ),
        PetStep(
          Behavior.happy,
          1.5,
          cue: learnedNow ? Cue.chime : Cue.bark,
          thought: praise,
        ),
      ],
      success: true,
      learnedNow: learnedNow,
    );
  }
  // 이름을 못 알아들으면 귀만 쫑긋하고 만다.
  if (t == Trick.name) {
    return const TrickTry([
      PetStep(Behavior.idle, 1.8, cue: Cue.whine, thought: '…응? 뭐?'),
    ], success: false);
  }
  // 시킨 개인기와 같은 자세가 들어간 개인기는 빼야 해낸 것처럼 보이지 않는다(앉아 ↔ 기다려).
  final pose = {for (final s in trickSteps(t)) s.behavior};
  final others = [
    for (final k in known)
      if (k != t &&
          k.chip &&
          trickSteps(k).every((s) => !pose.contains(s.behavior)))
        k,
  ];
  return TrickTry(switch (random.nextInt(others.isEmpty ? 2 : 3)) {
    0 => const [
      PetStep(Behavior.sniff, 1.8, cue: Cue.sniff, thought: '킁킁… 응? 뭐라고?'),
    ],
    1 => const [
      PetStep(Behavior.idle, 1.8, cue: Cue.whine, thought: '무슨 말이야?'),
    ],
    _ => trickSteps(others[random.nextInt(others.length)], thought: '이거지?'),
  }, success: false);
}

/// '2026-10-01' → '10월 1일'.
String monthDay(String dayKey) {
  final p = dayKey.split('-');
  return '${int.parse(p[1])}월 ${int.parse(p[2])}일';
}

/// 배운 날 칸(DB v20)이 생기기 전에 배운 개인기의 배운 날. 그 개인기를 배운 일기 재료 줄 중 가장 이른 날.
String? learnedDayFromLines(
  Trick t,
  Iterable<({DateTime at, String detail})> lines,
) {
  bool learnedLine(String d) => switch (t) {
    Trick.name => d.startsWith('내 이름이') && d.endsWith('인 걸 알았다'),
    Trick.potty => d == '패드에서 쉬하는 걸 배웠다',
    _ =>
      d.contains("'${t.label}'") &&
          (d.contains('처음으로 해냈다') ||
              d.contains('처음으로 익혔다') ||
              d.contains('배워 왔다')),
  };
  DateTime? first;
  for (final l in lines) {
    if (learnedLine(l.detail) && (first == null || l.at.isBefore(first))) {
      first = l.at;
    }
  }
  return first == null ? null : dayKey(petDate(first));
}

/// 훈련 수첩 한 줄. 지금 어디까지 왔고, 다음 별을 받으려면 뭘 하면 되는지.
String notebookLine(Trick t, TrickProgress p, {required String today}) {
  if (p.attempts == 0) {
    return switch (t) {
      Trick.name => '이름을 불러 주면 연습이 돼요',
      Trick.potty => '쉬 마려워할 때 패드로 데려가면 연습이 돼요',
      _ => '놀이 칸에서 시켜 보세요',
    };
  }
  if (!p.learned) return '해낸 ${p.successes}번 · $learnAfter번 해내면 배워요';
  final learned = p.learnedDay == null
      ? '배웠어요'
      : '${monthDay(p.learnedDay!)}에 배웠어요';
  final next = p.stars >= 3
      ? '별 셋, 거의 안 틀려요'
      : p.lastDay == today
      ? '내일 또 하면 별 하나 더'
      : '오늘 하면 별 하나 더';
  return '$learned · $next';
}

/// 아직 그림이 없어 못 배우는 개인기를 시키면 갸웃하기만 한다.
List<PetStep> unknownTrickSteps(String word) => [
  PetStep(
    Behavior.sit,
    2,
    cue: Cue.whine,
    thought: word == '빵' ? '빵? 맛있는 거야?' : '$word? 그게 뭐야?',
  ),
];

/// 어제 연습해서 한 번이라도 해낸 개인기 중 가장 많이 해낸 것. 오늘 처음 볼 때 자랑한다.
Trick? showOffTrick(Map<Trick, TrickProgress> tricks, String yesterday) {
  Trick? best;
  for (final MapEntry(key: t, value: p) in tricks.entries) {
    if (!t.chip || p.lastDay != yesterday || p.successes == 0) continue;
    if (best == null || p.successes > tricks[best]!.successes) best = t;
  }
  return best;
}

const _commands = {
  Trick.sit: ['앉아', '앉자', '앉어', '앉기', '앉으렴', '앉으세요', '싯', 'sit'],
  Trick.come: [
    '이리와',
    '일로와',
    '일루와',
    '여기와',
    '이리로와',
    '이리오',
    '이리온',
    '빨리와',
    '얼른와',
    '컴온',
    '컴',
    'come',
  ],
  Trick.down: ['엎드려', '업드려', '엎드', '업드', '엎드리', '다운', 'down'],
  Trick.wait: [
    '기다려',
    '기달려',
    '기다리',
    '멈춰',
    '스톱',
    '가만히',
    '가만있어',
    '가만히있어',
    '스테이',
    'stay',
  ],
  Trick.spin: [
    '돌아',
    '돌아봐',
    '빙글',
    '빙글빙글',
    '빙글돌아',
    '빙글빙글돌아',
    '뱅글',
    '뱅글뱅글',
    '한바퀴',
    '한바퀴돌아',
    '턴',
    'spin',
  ],
  Trick.jump: ['점프', '점프해', '뛰어', '뛰어봐', '뛰어올라', '폴짝', '폴짝폴짝', 'jump'],
  Trick.fetch: [
    '물어와',
    '물어와봐',
    '물어오',
    '물고와',
    '가져와',
    '가져와봐',
    '가져오',
    '가지고와',
    '갖고와',
    '패치',
    'fetch',
  ],
};

/// 강아지들이 흔히 배우지만 여기서는 안 하는 개인기. 시키면 갸웃하기만 한다.
/// '빵'(죽은 척)은 앞으로도 넣지 않는다.
const _unknownCommands = {
  '손': '손',
  '손줘': '손',
  '하이파이브': '하이파이브',
  '빵': '빵',
  '배': '배',
  '발라당': '발라당',
  '굴러': '굴러',
};

/// 폰 안에서 알아듣는 생활 말. AI가 없을 때만 쓴다.
/// [wish]는 오늘 소원을 묻는 말("뭐 하고 싶어?").
enum Everyday { called, sleep, love, play, walk, wish }

const _everyday = {
  Everyday.sleep: ['잘자', '잘자라', '굿나잇', '굿밤', '자자', '코자', '이제자'],
  Everyday.love: [
    '사랑해',
    '좋아해',
    '예뻐',
    '이뻐',
    '귀여워',
    '착하다',
    '착해',
    '잘했어',
    '잘했다',
    '기특해',
    '최고',
    '뽀뽀',
  ],
  Everyday.play: ['놀자', '놀아', '놀아줘', '심심해', '공놀이', '공놀이하자', '공'],
  Everyday.walk: [
    '산책',
    '산책가',
    '산책가자',
    '산책갈까',
    '산책갈래',
    '산책할까',
    '산책할래',
    '산책하자',
    '나가자',
  ],
  Everyday.wish: [
    '뭐하고싶어',
    '뭐하고싶니',
    '뭐하고싶은데',
    '뭐가하고싶어',
    '오늘뭐하고싶어',
    '오늘은뭐하고싶어',
    '하고싶은거있어',
    '뭐해줄까',
    '뭐원해',
    '뭐갖고싶어',
    '소원이뭐야',
    '소원뭐야',
    '오늘소원',
    '오늘소원은',
    '오늘소원이뭐야',
  ],
};

const _before = ['어서', '빨리', '얼른', '자', '한번', '다시', '옳지'];
const _after = [
  '봐봐',
  '볼래',
  '봐',
  '해볼래',
  '해봐',
  '해요',
  '할래',
  '하자',
  '해',
  '요',
  '라',
  '야',
];

/// 말에서 개인기 명령을 찾는다. 명령이 아니면 null, 아직 못 배우는 개인기면 trick이 null.
/// 이름만 부른 말은 명령이 아니다('돌이'를 부르는 '돌아'). '기다려 줘', '돌아와'처럼
/// 부탁하는 말은 마음이 담긴 말일 수 있어 명령으로 받지 않는다.
({Trick? trick, String word})? parseCommand(String text, String petName) {
  if (parseEveryday(text, petName) == Everyday.called) return null;
  for (final core in _cores(text, petName)) {
    for (final MapEntry(key: t, value: words) in _commands.entries) {
      if (words.any((w) => _repeats(core, w))) return (trick: t, word: t.label);
    }
    for (final MapEntry(key: w, value: word) in _unknownCommands.entries) {
      if (_repeats(core, w)) return (trick: null, word: word);
    }
  }
  return null;
}

/// 한 말에 든 개인기들을 순서대로(앉아 엎드려 돌아). 같은 개인기가 잇따르면 하나로 본다.
/// 개인기·이름·군말 말고 다른 말이 섞이면 이어 하기가 아니다('앉아 엎드려 너무 힘들어'의 지친 말,
/// '기다려 줘' 같은 부탁이 개인기에 묻히지 않게).
List<Trick> parseChain(String text, String petName) {
  final words = [
    for (final w in text.split(RegExp(r'[\s,.!~]+')))
      if (w.isNotEmpty) w,
  ];
  final out = <Trick>[];
  var i = 0;
  while (i < words.length) {
    // 띄어 쓴 명령('이리 와', '콩이 앉아')은 두 낱말을 붙여서 본다.
    var used = 0;
    Trick? t;
    for (var n = 1; n <= 2 && i + n <= words.length; n++) {
      if (parseCommand(words.sublist(i, i + n).join(), petName) case final c?) {
        t = c.trick;
        used = n;
        break;
      }
    }
    if (used == 0) {
      if (!_filler(words[i], petName)) return const [];
      i++;
      continue;
    }
    if (t == null) return const [];
    if (out.isEmpty || out.last != t) out.add(t);
    i += used;
  }
  return out;
}

/// 이름 부르기('콩이야')나 군말('해봐', '자').
bool _filler(String word, String petName) {
  final w = _normalize(word);
  return parseEveryday(word, petName) == Everyday.called ||
      [..._before, ..._after].any((f) => _repeats(w, f));
}

/// 이어서 시킬 수 있는 개인기: 별 셋(배운 뒤 사흘 넘게 연습한 것). 물어와는 공이 있어야 해서 뺀다.
bool chainable(Trick t, TrickProgress? p) =>
    t.chip && t != Trick.fetch && (p?.stars ?? 0) >= 3;

/// 이름만 부르거나 잘 자·사랑해·놀자·산책 같은 말인지 본다.
Everyday? parseEveryday(String text, String petName) {
  final names = _vocatives(_normalize(petName));
  for (final core in _cores(text, petName)) {
    if (names.any((n) => _repeats(core, n))) return Everyday.called;
    for (final MapEntry(key: e, value: words) in _everyday.entries) {
      if (words.any((w) => _repeats(core, w))) return e;
    }
  }
  return null;
}

String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// 초코 → 초코야·초코아, 별이 → 별아·별이야.
List<String> _vocatives(String name) {
  if (name.isEmpty) return const [];
  final stems = {
    name,
    if (name.length > 1 && name.endsWith('이'))
      name.substring(0, name.length - 1),
  };
  return {
    for (final s in stems) ...['$s야', '$s아', '$s이야', '$s이', s],
  }.toList()..sort((a, b) => b.length - a.length);
}

bool _repeats(String s, String word) {
  if (word.isEmpty || s.length % word.length != 0) return false;
  for (var i = 0; i < s.length; i += word.length) {
    if (!s.startsWith(word, i)) return false;
  }
  return true;
}

/// 이름·군말을 앞뒤에서 하나씩 떼어 본 후보들. 덜 뗀 것부터 나온다.
/// 다 떼어 빈 말이 되면 떼지 않는다('돌이'를 부르는 '돌아'도 '돌아'로 남게).
Iterable<String> _cores(String text, String petName) sync* {
  final names = _vocatives(_normalize(petName));
  final front = [...names, ..._before];
  final back = [...names, ..._after];
  final seen = <String>{};
  var frontier = [_normalize(text)];
  while (frontier.isNotEmpty) {
    final next = <String>[];
    for (final s in frontier) {
      if (s.isEmpty || !seen.add(s)) continue;
      yield s;
      for (final p in front) {
        if (s.length > p.length && s.startsWith(p)) {
          next.add(s.substring(p.length));
        }
      }
      for (final p in back) {
        if (s.length > p.length && s.endsWith(p)) {
          next.add(s.substring(0, s.length - p.length));
        }
      }
    }
    frontier = next;
  }
}
