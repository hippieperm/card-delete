import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import '../widgets/photo_card.dart';
import 'dart:typed_data';
import 'trash_screen.dart';

class PhotoSwipeScreen extends HookWidget {
  const PhotoSwipeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final photoService = useMemoized(() => PhotoService(), []);
    final photos = useState<List<PhotoModel>>([]);
    final isLoading = useState(true);
    final hasPermission = useState(false);
    final deletedCount = useState(0);
    final isUsingDummyData = useState(false);
    final CardSwiperController controller = useMemoized(
      () => CardSwiperController(),
      [],
    );

    // 테스트 모드로 전환
    void switchToTestMode() {
      isUsingDummyData.value = true;
      photos.value = photoService.getDummyPhotos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('테스트 이미지를 표시합니다.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // 사진 로드 함수
    Future<void> loadPhotos() async {
      isLoading.value = true;
      try {
        final permissionGranted = await photoService.requestPermission();
        hasPermission.value = permissionGranted;

        if (permissionGranted) {
          final loadedPhotos = await photoService.loadPhotos();

          if (loadedPhotos.isEmpty) {
            // 실제 사진이 없으면 테스트 데이터 사용
            isUsingDummyData.value = true;
            photos.value = photoService.getDummyPhotos();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('실제 사진이 없어 테스트 이미지를 표시합니다.'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 3),
              ),
            );
          } else {
            isUsingDummyData.value = false;
            photos.value = loadedPhotos;
          }

          if (photos.value.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('표시할 사진이 없습니다.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사진 접근 권한이 필요합니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print('사진 로드 중 오류: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진을 불러오는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );

        // 오류 발생 시 테스트 데이터 사용
        isUsingDummyData.value = true;
        photos.value = photoService.getDummyPhotos();
      } finally {
        isLoading.value = false;
      }
    }

    // 사진 삭제 함수 (휴지통으로 이동)
    Future<void> deletePhoto(int index) async {
      final photo = photos.value[index];

      // 휴지통으로 이동
      photoService.moveToTrash(photo);

      // 삭제된 사진을 목록에서 제거
      final updatedPhotos = List<PhotoModel>.from(photos.value);
      updatedPhotos.removeAt(index);
      photos.value = updatedPhotos;

      deletedCount.value++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('사진이 휴지통으로 이동되었습니다 (${deletedCount.value}개)'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1),
          action: SnackBarAction(
            label: '실행취소',
            textColor: Colors.white,
            onPressed: () {
              // 휴지통에서 복원
              photoService.restoreFromTrash(photo);

              // 목록에 다시 추가
              final restoredPhotos = List<PhotoModel>.from(photos.value);
              if (index < restoredPhotos.length) {
                restoredPhotos.insert(index, photo);
              } else {
                restoredPhotos.add(photo);
              }
              photos.value = restoredPhotos;
              deletedCount.value--;
            },
          ),
        ),
      );
    }

    // 휴지통 화면으로 이동
    void navigateToTrash() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrashScreen(photoService: photoService),
        ),
      ).then((_) {
        // 휴지통에서 돌아오면 목록 새로고침
        loadPhotos();
      });
    }

    // 초기 데이터 로드
    useEffect(() {
      loadPhotos().then((_) {
        // 사진이 없으면 자동으로 테스트 모드로 전환
        if (photos.value.isEmpty) {
          switchToTestMode();
        }
      });
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 정리하기'),
        centerTitle: true,
        actions: [
          // 휴지통 버튼
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: navigateToTrash,
            tooltip: '휴지통',
          ),
          // 테스트 모드 버튼
          IconButton(
            icon: Icon(
              isUsingDummyData.value ? Icons.image : Icons.image_outlined,
              color: isUsingDummyData.value ? Colors.blue : null,
            ),
            onPressed: switchToTestMode,
            tooltip: '테스트 이미지 표시',
          ),
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadPhotos,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : !hasPermission.value
          ? _buildPermissionDenied(context)
          : photos.value.isEmpty
          ? _buildNoPhotos(context)
          : Column(
              children: [
                Expanded(
                  child: CardSwiper(
                    controller: controller,
                    cardsCount: photos.value.length,
                    cardBuilder: (context, index, _, __) {
                      return PhotoCard(photo: photos.value[index]);
                    },
                    onSwipe: (previousIndex, currentIndex, direction) {
                      if (direction == CardSwiperDirection.left) {
                        // 왼쪽으로 스와이프: 사진 삭제 (휴지통으로 이동)
                        deletePhoto(previousIndex);
                      }
                      // 오른쪽으로 스와이프: 다음 사진으로 넘어감
                      return true;
                    },
                    numberOfCardsDisplayed: 1,
                    backCardOffset: const Offset(0, 0),
                    padding: const EdgeInsets.all(24.0),
                  ),
                ),
                _buildBottomControls(context, controller),
              ],
            ),
    );
  }

  Widget _buildPermissionDenied(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '사진 접근 권한이 필요합니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '설정에서 사진 접근 권한을 허용해주세요',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // 앱 설정 화면으로 이동
              openAppSettings();
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPhotos(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '사진이 없습니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    CardSwiperController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => controller.swipeLeft(),
            icon: const Icon(Icons.delete),
            label: const Text('삭제'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => controller.swipeRight(),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('다음'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
