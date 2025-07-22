import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import 'dart:typed_data';
import 'photo_swipe_screen.dart';
import 'trash_screen.dart';
import 'package:photo_manager/photo_manager.dart';

class GridViewScreen extends HookWidget {
  const GridViewScreen({Key? key}) : super(key: key);

  // 썸네일 캐시
  static final Map<String, Uint8List> _thumbnailCache = {};

  @override
  Widget build(BuildContext context) {
    final photoService = useMemoized(() => PhotoService(), []);
    final photos = useState<List<PhotoModel>>([]);
    final isLoading = useState(true);
    final isLoadingMore = useState(false);
    final hasPermission = useState(false);
    final deletedCount = useState(0);
    final scrollController = useScrollController();
    final selectedPhotos = useState<Set<String>>({});

    // 추가 사진 로드
    Future<void> loadMorePhotos() async {
      if (isLoadingMore.value) return;

      isLoadingMore.value = true;
      try {
        final morePhotos = await photoService.loadMorePhotos();
        if (morePhotos.isNotEmpty) {
          photos.value = [...photos.value, ...morePhotos];
        }
      } finally {
        isLoadingMore.value = false;
      }
    }

    // 스크롤 이벤트 리스너
    useEffect(() {
      void onScroll() {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 500) {
          loadMorePhotos();
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController]);

    // 썸네일 로드 함수
    Future<Uint8List?> loadThumbnail(PhotoModel photo, {int size = 200}) async {
      final cacheKey = '${photo.asset.id}_$size';

      // 캐시에 있으면 캐시에서 반환
      if (_thumbnailCache.containsKey(cacheKey)) {
        return _thumbnailCache[cacheKey];
      }

      try {
        final data = await photo.asset.thumbnailDataWithSize(
          ThumbnailSize(size, size),
          quality: 80,
        );

        if (data != null) {
          // 캐시에 저장
          _thumbnailCache[cacheKey] = data;
          return data;
        }
      } catch (e) {
        debugPrint('썸네일 로드 오류: $e');
      }

      return null;
    }

    // 사진 로드 함수
    Future<void> loadPhotos() async {
      isLoading.value = true;
      try {
        final permissionGranted = await photoService.requestPermission();
        hasPermission.value = permissionGranted;

        if (permissionGranted) {
          final loadedPhotos = await photoService.loadPhotos();
          photos.value = loadedPhotos;

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
        debugPrint('사진 로드 중 오류: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진을 불러오는 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        isLoading.value = false;
      }
    }

    // 사진 선택 토글
    void togglePhotoSelection(String photoId) {
      final newSelection = Set<String>.from(selectedPhotos.value);
      if (newSelection.contains(photoId)) {
        newSelection.remove(photoId);
      } else {
        newSelection.add(photoId);
      }
      selectedPhotos.value = newSelection;
    }

    // 선택한 사진 삭제
    Future<void> deleteSelectedPhotos() async {
      if (selectedPhotos.value.isEmpty) return;

      final selectedIds = selectedPhotos.value;
      final photosToDelete = photos.value
          .where((photo) => selectedIds.contains(photo.asset.id))
          .toList();

      // 휴지통으로 이동
      for (final photo in photosToDelete) {
        photoService.moveToTrash(photo);
      }

      // 삭제된 사진을 목록에서 제거
      final updatedPhotos = photos.value
          .where((photo) => !selectedIds.contains(photo.asset.id))
          .toList();

      photos.value = updatedPhotos;
      deletedCount.value += photosToDelete.length;

      // 선택 초기화
      selectedPhotos.value = {};

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${photosToDelete.length}장의 사진이 휴지통으로 이동되었습니다'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: '실행취소',
            textColor: Colors.white,
            onPressed: () {
              // 휴지통에서 복원
              for (final photo in photosToDelete) {
                photoService.restoreFromTrash(photo);
              }

              // 목록에 다시 추가
              final restoredPhotos = List<PhotoModel>.from(photos.value);
              restoredPhotos.addAll(photosToDelete);
              photos.value = restoredPhotos;
              deletedCount.value -= photosToDelete.length;
            },
          ),
        ),
      );
    }

    // 스와이프 화면으로 이동
    void navigateToSwipeScreen(int index) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PhotoSwipeScreen()),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('사진 그리드'),
        centerTitle: true,
        actions: [
          // 선택 모드일 때만 표시되는 삭제 버튼
          if (selectedPhotos.value.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: deleteSelectedPhotos,
              tooltip: '선택한 사진 삭제',
            ),
          // 휴지통 버튼
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: navigateToTrash,
            tooltip: '휴지통',
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
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : !hasPermission.value
          ? _buildPermissionDenied(context)
          : photos.value.isEmpty
          ? _buildNoPhotos(context)
          : GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1.0,
              ),
              itemCount: photos.value.length + (isLoadingMore.value ? 3 : 0),
              itemBuilder: (context, index) {
                // 로딩 인디케이터 표시
                if (index >= photos.value.length) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final photo = photos.value[index];
                final isSelected = selectedPhotos.value.contains(
                  photo.asset.id,
                );

                return GestureDetector(
                  onTap: () {
                    if (selectedPhotos.value.isNotEmpty) {
                      // 선택 모드일 때는 선택/해제
                      togglePhotoSelection(photo.asset.id);
                    } else {
                      // 일반 모드일 때는 스와이프 화면으로 이동
                      navigateToSwipeScreen(index);
                    }
                  },
                  onLongPress: () {
                    // 길게 누르면 선택 모드 시작
                    togglePhotoSelection(photo.asset.id);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 썸네일 이미지
                      FutureBuilder<Uint8List?>(
                        future: loadThumbnail(photo),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError ||
                              !snapshot.hasData ||
                              snapshot.data == null) {
                            return Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              child: const Center(
                                child: Icon(Icons.error_outline, size: 30),
                              ),
                            );
                          }

                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            cacheHeight: 200,
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                          );
                        },
                      ),

                      // 선택 표시 오버레이
                      if (isSelected)
                        Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.5),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),

                      // 휴지통 표시
                      if (photo.isInTrash)
                        Positioned(
                          right: 5,
                          top: 5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.delete_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PhotoSwipeScreen()),
          ).then((_) {
            loadPhotos();
          });
        },
        tooltip: '스와이프 모드',
        child: const Icon(Icons.swipe),
      ),
    );
  }

  Widget _buildPermissionDenied(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.no_photography,
            size: 80,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            '사진 접근 권한이 필요합니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '설정에서 사진 접근 권한을 허용해주세요',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // 앱 설정 화면으로 이동
              openAppSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPhotos(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library,
            size: 80,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            '사진이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
