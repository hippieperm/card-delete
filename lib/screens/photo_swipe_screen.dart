import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import '../widgets/photo_card.dart';

class PhotoSwipeScreen extends HookWidget {
  const PhotoSwipeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final photoService = useMemoized(() => PhotoService(), []);
    final photos = useState<List<PhotoModel>>([]);
    final isLoading = useState(true);
    final hasPermission = useState(false);
    final deletedCount = useState(0);
    final CardSwiperController controller = useMemoized(
      () => CardSwiperController(),
      [],
    );

    // 사진 로드 함수
    Future<void> loadPhotos() async {
      isLoading.value = true;
      final permissionGranted = await photoService.requestPermission();
      hasPermission.value = permissionGranted;

      if (permissionGranted) {
        final loadedPhotos = await photoService.loadPhotos();
        photos.value = loadedPhotos;
      }

      isLoading.value = false;
    }

    // 사진 삭제 함수
    Future<void> deletePhoto(int index) async {
      final photo = photos.value[index];
      final success = await photoService.deletePhoto(photo.asset);

      if (success) {
        deletedCount.value++;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진이 삭제되었습니다 (${deletedCount.value}개)'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진 삭제에 실패했습니다'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // 초기 데이터 로드
    useEffect(() {
      loadPhotos();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 정리하기'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadPhotos),
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
                        // 왼쪽으로 스와이프: 사진 삭제
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
