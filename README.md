# 마이펫

반려동물을 키우기 어려운 사람도 일상에서 강아지와 시간을 보내고, 입양을 고민하는 사람은 돌봄을 미리 경험해 보면 좋겠다고 생각했습니다. 내가 아는 강아지를 닮은 아이가 말을 듣고 몸짓으로 답할 때, 서로 통하는 듯한 느낌이 들기를 바랐습니다. Flutter와 Flame으로 만든 Android 개인 프로젝트입니다.

## 첫날 밥 주던 손을 기억하는 강아지 · 21초

https://github.com/user-attachments/assets/44847907-64d9-4ce9-b2c4-0489c881a79d

[Google Drive에서 보기](https://drive.google.com/file/d/1ZUt-sSeWEIlKBoXjA6eMk6CvCuqy8UZ1/view) · [MP4 파일 받기](https://raw.githubusercontent.com/greed94/mypet-game/main/docs/portfolio/mypet-first-day.mp4)

첫날 밤 보리에게 밥을 주고, 다음 날 아침에 돌아와 쓰다듬습니다. 보리는 밥 주던 손 냄새를 알아보고, 일기에는 전날 처음 만난 시각과 밥을 준 시각이 남습니다. 이 재회는 입양한 다음 생활일의 첫 손길에 일어납니다. 영상은 PC의 Flutter 테스트에서 앱 화면을 스크립트로 조작해 캡처했습니다. 다음 날 아침은 연습 시계로 앞당겼고 강아지는 로컬 기록에 반응했습니다. [재회 장면](docs/portfolio/mypet-first-return.png) · [첫날 일기](docs/portfolio/mypet-diary-trail.png)

## 생활 시간이 다른 사람도 돌보려면

저는 보호자의 퇴근 시간이 달라도 강아지와 놀 수 있도록, 보호자가 앱을 여는 시간과 잘 자라고 인사하는 시간을 배우는 방향을 제안했습니다. AI와 함께 수면과 반김 규칙을 구현했고, 9월 수정 전후를 같은 조건으로 비교했습니다. 교대근무자와 차분한 강아지를 가정한 2주 모의실험을 20번씩 실행했을 때 앱을 열자 강아지가 자고 있던 비율은 26.3%(221/840회)에서 18.1%(152/840회)로 줄었습니다. [생활 리듬 규칙](lib/pet/rhythm.dart) · [2주 생활 모의실험](tools/persona_sim/persona_sim_test.dart)

## 제작과 검증

저는 돌봄의 목표와 우선순위를 정하고 직접 플레이했습니다. 조사와 강아지 그림 시트 제작에는 ChatGPT를 썼고, 앱 코드와 테스트는 Claude Code와 Codex에 맡겼습니다. S22에서 개인기를 연속으로 누른 뒤 놀이를 끝낼 수 없었을 때는 손가락으로 누른 위치와 실제로 접수된 명령을 비교하도록 요청했습니다. 수정 후 같은 자리를 누른 아홉 번 모두 의도한 개인기로 접수됐습니다. [기기 검증 기록](docs/play-verification.md) · [작업 분담과 검토 방법](docs/ai-workflow.md)

## 테스트 실행

Flutter 3.38.7과 Dart 3.10.7을 사용합니다. 아래 검사는 합성 입력으로 실행할 수 있습니다.

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub test/first_day_recognition_test.dart test/talk_order_test.dart
flutter test --no-pub
```

Android의 기본 돌봄과 일기는 로컬에서 작동합니다. 기본 Gemini 대화를 사용하려면 본인의 Firebase 환경을 설정합니다. 앱 설정에서 OpenAI 호환 API의 주소와 모델, 키를 직접 입력해 연결할 수도 있습니다. 사진 검사는 합성 견본을 사용하며, 개인 사진을 바탕으로 만든 이전 실험 모양은 기본 강아지 그림으로 표시합니다. [데이터와 자산 출처](docs/asset-sources.md)
