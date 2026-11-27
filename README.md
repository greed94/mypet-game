# 마이펫

마이펫은 강아지에게 말을 걸고 밥을 주고 함께 놀면서, 강아지가 그 시간을 어떻게 기억하는지 지켜보는 Android 게임입니다.

지금은 반려동물을 키우기 어려운 사람도 일상에서 강아지와 시간을 보내고, 입양을 고민하는 사람은 돌봄을 미리 경험할 수 있으면 좋겠다고 생각했습니다. 내가 아는 강아지를 닮은 아이가 내 말을 듣고 몸짓으로 대답하는 느낌을 담고 싶었습니다.

## 플레이 영상

<table align="center"><tr><td align="center">

https://github.com/user-attachments/assets/44847907-64d9-4ce9-b2c4-0489c881a79d

[Google Drive에서 보기](https://drive.google.com/file/d/1ZUt-sSeWEIlKBoXjA6eMk6CvCuqy8UZ1/view) · [MP4 파일 받기](https://raw.githubusercontent.com/greed94/mypet-game/main/docs/portfolio/mypet-first-day.mp4)

</td></tr></table>

첫날 밤 보리에게 밥을 줍니다. 이튿날 아침 처음 쓰다듬자 보리는 어제 밥 주던 손 냄새를 알아보고, 일기장에는 처음 만난 시각과 첫 끼를 준 시각이 남습니다. [재회 장면](docs/portfolio/mypet-first-return.png) · [첫날 일기](docs/portfolio/mypet-diary-trail.png)

<sub>PC의 Flutter 테스트에서 앱 화면을 스크립트로 조작해 녹화했습니다. 연습 시계로 다음 날 아침까지 시간을 옮겼고, 보리는 기기에 저장된 돌봄 기록에 반응합니다.</sub>

## 주요 기획

### 늦게 퇴근하는 보호자는 언제 강아지와 놀 수 있을까?

강아지가 매일 같은 시각에 잠들면, 늦게 퇴근하는 사람은 집에 돌아와 앱을 열어도 잠든 강아지만 만나기 쉽습니다. 저는 강아지가 보호자의 생활 시간에 맞춰 자고 일어나도록 제안했습니다. 앱을 여닫는 시간대를 바탕으로 강아지의 수면 시간을 조금씩 조정하고, 저녁에 “잘 자”라고 인사하면 그날은 바로 잠들게 했습니다. [생활 리듬 규칙](lib/pet/rhythm.dart)

9월에 수면과 반김 규칙을 바꾼 뒤, 가상의 교대근무자와 차분한 강아지가 함께 보내는 2주를 같은 조건으로 수정 전후 각각 20번씩 실행했습니다. **앱을 열었을 때 강아지가 자고 있던 비율은 26.3%(840회 중 221회)에서 18.1%(840회 중 152회)로 줄었습니다.** [2주 생활 모의실험](tools/persona_sim/persona_sim_test.dart)

## AI와의 작업 분담

저는 어떤 돌봄 경험을 만들지 정하고, 직접 플레이하면서 다음에 고칠 일의 우선순위를 정했습니다. 조사와 강아지 그림 시트 제작에는 ChatGPT를 썼고, 앱 코드와 테스트 구현은 Claude Code와 Codex에 맡겼습니다. [작업 분담과 반복 작업에 쓴 스킬](docs/ai-workflow.md)

### 재회 대사가 사라진 이유

Claude Code에는 별도 복제본에서 플레이 흐름을 점검하고 문제를 보고하도록 했습니다. 그 과정에서 보리가 어제 일을 기억해 내도 약 2초 만에 ‘오늘의 소원’이 그 대사를 덮는 문제를 찾았습니다. Codex에는 이를 재현하고 소원 안내를 늦추도록 맡겼습니다. 첫날 밥을 준 경우와 공놀이를 한 경우 모두, 이튿날의 재회 대사가 6초 동안 유지되는지 테스트했습니다. [수정 코드와 회귀 테스트](https://github.com/greed94/mypet-game/commit/76e782b)

### 같은 자리를 눌러도 다른 개인기가 나온 이유

S22에서 제가 ‘물어와’를 여러 번 누른 뒤 ‘그만 놀기’를 눌러도 놀이판이 남았습니다. Codex에 손가락으로 누른 위치와 앱이 받아들인 명령을 대조해 달라고 했습니다. 공을 물거나 내려놓을 때 버튼이 움직여, 같은 자리를 아홉 번 눌러도 ‘물어와’ 다섯 번과 ‘점프’ 네 번으로 나뉘었습니다. 버튼 위치를 고친 뒤에는 아홉 번 모두 ‘물어와’로 접수됐고, ‘그만 놀기’를 누르자 밥 주기와 놀아주기 버튼이 다시 나타났습니다. [기기 검증 기록](docs/play-verification.md)

## 개발 환경과 테스트

Flutter 3.38.7과 Dart 3.10.7로 만든 Android 개인 프로젝트입니다. Flutter로 대화·일기·설정 화면을 만들고, 홈에서 강아지가 움직이고 공을 쫓는 장면은 Flame으로 구현했습니다.

기본 돌봄과 일기는 기기 안에서 작동합니다. 기본 Gemini 대화를 사용하려면 본인의 Firebase 환경을 설정합니다. 앱 설정에서 OpenAI 호환 API의 주소·모델·키를 입력해 연결할 수도 있습니다.

아래 명령으로 정적 분석, 첫 재회와 대화 순서 검사, 전체 테스트를 실행할 수 있습니다.

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub test/first_day_recognition_test.dart test/talk_order_test.dart
flutter test --no-pub
```

사진 테스트에는 합성 견본을 사용합니다. 개인 사진을 바탕으로 만든 이전 실험 모양은 이 공개 버전에서 기본 강아지 그림으로 표시합니다. [데이터와 자산 출처](docs/asset-sources.md) · [GitHub Actions 검사](https://github.com/greed94/mypet-game/actions/workflows/pet-care.yml)
