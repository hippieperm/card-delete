import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'screens/splash_screen.dart';
import 'screens/photo_swipe_screen.dart';
import 'screens/grid_view_screen.dart';
import 'widgets/adaptive_background.dart';
import 'models/photo_model.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'services/photo_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 모드만 지원
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // 다이나믹 컬러를 사용할 수 없는 경우 기본 색상 사용
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          // 다이나믹 컬러 사용 가능한 경우
          lightColorScheme = lightDynamic;
          darkColorScheme = darkDynamic;
        } else {
          // 다이나믹 컬러 사용 불가능한 경우 기본 색상 사용
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: '사진 정리',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            appBarTheme: AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: lightColorScheme.surface,
              foregroundColor: lightColorScheme.onSurface,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 1,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              labelTextStyle: MaterialStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              iconTheme: MaterialStateProperty.all(
                const IconThemeData(size: 24),
              ),
              elevation: 3,
              indicatorColor: lightColorScheme.primaryContainer,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            appBarTheme: AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: darkColorScheme.surface,
              foregroundColor: darkColorScheme.onSurface,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 1,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              labelTextStyle: MaterialStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              iconTheme: MaterialStateProperty.all(
                const IconThemeData(size: 24),
              ),
              elevation: 3,
              indicatorColor: darkColorScheme.primaryContainer,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
            ),
          ),
          themeMode: ThemeMode.dark, // 다크모드를 기본으로 설정
          home: const SplashScreen(),
        );
      },
    );
  }
}

class HomeScreen extends HookWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final selectedIndex = useState(0);
    final currentPhoto = useState<PhotoModel?>(null);

    // 사진 서비스 인스턴스 생성 (공유)
    final photoService = useMemoized(() => PhotoService(), []);

    // 현재 화면 위젯을 생성하는 함수
    Widget getScreen(int index) {
      switch (index) {
        case 0:
          // PhotoSwipeScreen에서 현재 사진 정보를 받아오기 위한 콜백 함수
          return PhotoSwipeScreen(
            onPhotoChanged: (photo) {
              currentPhoto.value = photo;
            },
          );
        case 1:
          // 그리드 화면에 동일한 photoService 인스턴스 전달
          return GridViewScreen(photoService: photoService);
        default:
          return PhotoSwipeScreen(
            onPhotoChanged: (photo) {
              currentPhoto.value = photo;
            },
          );
      }
    }

    return AdaptiveBackground(
      photo: currentPhoto.value,
      enabled:
          currentPhoto.value != null &&
          selectedIndex.value == 0, // 스와이프 화면에서만 배경 활성화
      child: Scaffold(
        backgroundColor: Colors.transparent, // 배경을 투명하게 설정
        extendBodyBehindAppBar: true, // AppBar 뒤로 body 확장
        body: getScreen(selectedIndex.value),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withOpacity(0.9), // 반투명 배경
          selectedIndex: selectedIndex.value,
          onDestinationSelected: (index) {
            selectedIndex.value = index;
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.swipe), label: '스와이프'),
            NavigationDestination(icon: Icon(Icons.grid_view), label: '그리드'),
          ],
        ),
      ),
    );
  }
}
