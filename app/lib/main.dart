import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';
import 'services/asr_service.dart';
import 'ui/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 只允许竖屏：转一下也不跟着横过去
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );
  // 图片缓存收紧：大图按目标尺寸解码后，缓存不必留太多
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 120;
  await AppSettings.load();
  // 后台清掉重复导入的旧语音模型，别堵住启动
  AsrService.cleanupOldModels();
  runApp(const WhaleDiaryApp());
}

class WhaleDiaryApp extends StatelessWidget {
  const WhaleDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4FA3D1);
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppSettings.fontScale,
        AppSettings.bgImage,
        AppSettings.bgOverlay,
      ]),
      builder: (context, _) {
        final scale = AppSettings.fontScale.value;
        final bg = AppSettings.bgImage.value;
        final overlay = AppSettings.bgOverlay.value;

        return MaterialApp(
          title: '鲸鱼日记',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor:
                bg == null ? Colors.black : Colors.transparent,
            colorScheme: const ColorScheme.dark(
              primary: accent,
              secondary: accent,
              surface: Color(0xFF111111),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              elevation: 0,
              centerTitle: false,
            ),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: Color(0xFF1E1E1E),
              contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
              behavior: SnackBarBehavior.floating,
            ),
            useMaterial3: true,
          ),
          builder: (context, child) {
            final scaled = MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
            if (bg == null) return scaled;
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    File(bg),
                    key: ValueKey(bg),
                    fit: BoxFit.cover,
                    cacheWidth: 1080, // 背景图别按原图解码
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Colors.black),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: overlay),
                  ),
                ),
                scaled,
              ],
            );
          },
          home: const HomePage(),
        );
      },
    );
  }
}


