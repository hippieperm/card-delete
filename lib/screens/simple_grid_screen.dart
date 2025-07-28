import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import 'dart:typed_data';
import 'photo_swipe_screen.dart';
import 'trash_screen.dart';
import 'package:photo_manager/photo_manager.dart';

class SimpleGridScreen extends HookWidget {
  final PhotoService photoService;

  const SimpleGridScreen({Key? key, required this.photoService})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final photos = useState<List<PhotoModel>>([]);
    final isLoading = useState(true);
    final hasPermission = useState(false);
    final thumbnails = useState<Map<String, Uint8List>>({});

    // 초기 썸네일 로드
    Future<void> _loadInitialThumbnails(List<PhotoModel> initialPhotos) async {
      final newThumbnails = Map<String, Uint8List>.from(thumbnails.value);

      for (final photo in initialPhotos) {
        try {
          final data = await photo.asset.thumbnailDataWithSize(
            const ThumbnailSize(200, 200),
            quality: 80,
          );

          if (data != null) {
            newThumbnails[photo.asset.id] = data;
          }
        } catch (e) {
          debugPrint('썸네일 로드 오류: $e');
        }
      }

      thumbnails.value = newThumbnails;
    }

    // 특정 사진의 썸네일 로드
    Future<void> loadThumbnail(PhotoModel photo) async {
      if (thumbnails.value.containsKey(photo.asset.id)) {
        return;
      }

      try {
        final data = await photo.asset.thumbnailDataWithSize(
          const ThumbnailSize(200, 200),
          quality: 80,
        );

        if (data != null) {
          final newThumbnails = Map<String, Uint8List>.from(thumbnails.value);
          newThumbnails[photo.asset.id] = data;
          thumbnails.value = newThumbnails;
        }
      } catch (e) {
        debugPrint('썸네일 로드 오류: $e');
      }
    }

    // 사진 로드 함수
    Future<void> loadPhotos() async {
      debugPrint('간단한 그리드 - 사진 로드 시작');
      isLoading.value = true;

      try {
        // 권한 확인
        final permitted = await photoService.requestPermission();
        hasPermission.value = permitted;

        if (permitted) {
          // 사진 로드
          final loadedPhotos = await photoService.loadPhotos();

          // 휴지통에 없는 사진만 필터링
          final filteredPhotos = loadedPhotos
              .where((photo) => !photo.isInTrash)
              .toList();

          photos.value = filteredPhotos;
          debugPrint('간단한 그리드 - 로드된 사진 수: ${filteredPhotos.length}');

          // 첫 20개 사진의 썸네일 로드
          _loadInitialThumbnails(filteredPhotos.take(20).toList());
        }
      } catch (e) {
        debugPrint('간단한 그리드 - 사진 로드 오류: $e');
      } finally {
        isLoading.value = false;
      }
    }

    // 스와이프 화면으로 이동
    void navigateToSwipeScreen(int index) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoSwipeScreen(initialIndex: index),
        ),
      ).then((_) {
        // 스와이프 화면에서 돌아오면 목록 새로고침
        loadPhotos();
      });
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
      loadPhotos();
      return null;
    }, []);

    // 권한 거부 UI
    Widget _buildPermissionDenied() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '사진 접근 권한이 필요합니다',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: const Text('설정으로 이동'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: loadPhotos, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    // 사진 없음 UI
    Widget _buildNoPhotos() {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('사진이 없습니다'),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 그리드'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: navigateToTrash,
            tooltip: '휴지통',
          ),
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
          ? _buildPermissionDenied()
          : photos.value.isEmpty
          ? _buildNoPhotos()
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: photos.value.length,
              itemBuilder: (context, index) {
                final photo = photos.value[index];

                // 보이는 사진의 썸네일 로드
                if (!thumbnails.value.containsKey(photo.asset.id)) {
                  loadThumbnail(photo);
                }

                return GestureDetector(
                  onTap: () => navigateToSwipeScreen(index),
                  child: thumbnails.value.containsKey(photo.asset.id)
                      ? Image.memory(
                          thumbnails.value[photo.asset.id]!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                );
              },
            ),
    );
  }
}
