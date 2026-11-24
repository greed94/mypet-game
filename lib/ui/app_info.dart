import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool _fontLicensesRegistered = false;

void _registerFontLicenses() {
  if (_fontLicensesRegistered) return;
  _fontLicensesRegistered = true;
  LicenseRegistry.addLicense(() async* {
    for (final (name, asset) in const [
      ('Jua', 'assets/fonts/OFL-jua.txt'),
      ('Gowun Dodum', 'assets/fonts/OFL-gowundodum.txt'),
      ('Gaegu', 'assets/fonts/OFL-gaegu.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString(asset));
    }
  });
}

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  @override
  void initState() {
    super.initState();
    _registerFontLicenses();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('앱 정보와 출처')),
    body: ListView(
      padding:
          MediaQuery.paddingOf(context).copyWith(top: 0) +
          const EdgeInsets.all(20),
      children: [
        Text('마이펫', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text(
          '펫과 기억, 일기는 이 폰에 저장돼요. AI를 사용할 때는 말 건 내용과 기억, '
          '일기 재료가 연결된 AI 서비스로 전송돼요.',
        ),
        const SizedBox(height: 24),
        Text('날씨와 대기질', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('Open-Meteo · CC BY 4.0'),
        const SelectableText('https://open-meteo.com/'),
        const SelectableText('https://creativecommons.org/licenses/by/4.0/'),
        const SizedBox(height: 8),
        const Text('대기질 원자료: Copernicus Atmosphere Monitoring Service (CAMS)'),
        const SelectableText('https://atmosphere.copernicus.eu/'),
        const SizedBox(height: 24),
        Text('전국 시·군·구 목록', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('© OpenStreetMap 기여자 · Open Database License (ODbL)'),
        const SelectableText('https://www.openstreetmap.org/copyright'),
        const SizedBox(height: 24),
        Text('글꼴과 오픈소스', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('주아 · 고운돋움 · 개구 (SIL Open Font License 1.1)'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () =>
              showLicensePage(context: context, applicationName: '마이펫'),
          icon: const Icon(Icons.description_outlined),
          label: const Text('오픈소스 라이선스 보기'),
        ),
      ],
    ),
  );
}
