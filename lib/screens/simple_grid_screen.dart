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
    final currentSortOrder = useState<SortOrder>(photoService.currentSortOrder);

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

    // 정렬 방식 변경
    void changeSortOrder(SortOrder newSortOrder) async {
      if (currentSortOrder.value == newSortOrder) return;

      currentSortOrder.value = newSortOrder;
      photoService.setSortOrder(newSortOrder);
      await photoService.saveSortOrderPreference();
      loadPhotos(); // 새로운 정렬로 사진 다시 로드
    }

    // 정렬 옵션 다이얼로그 표시
    void showSortOptions() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        elevation: 0,
        transitionAnimationController: AnimationController(
          vsync: Navigator.of(context),
          duration: const Duration(milliseconds: 300),
        ),
        builder: (context) {
          return AnimatedPadding(
            padding: MediaQuery.of(context).viewInsets,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: ModalRoute.of(context)!.animation!,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: ModalRoute.of(context)!.animation!,
                  curve: Curves.easeOut,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 드래그 핸들
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        height: 4,
                        width: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // 제목
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sort,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '정렬 방식',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(),

                      // 정렬 옵션들
                      _AnimatedSortOptionList(
                        options: [
                          SortOptionItem(
                            icon: Icons.calendar_today,
                            title: '날짜 최신순',
                            subtitle: '최근에 찍은 사진부터 표시',
                            isSelected:
                                currentSortOrder.value == SortOrder.dateNewest,
                            onTap: () => changeSortOrder(SortOrder.dateNewest),
                          ),
                          SortOptionItem(
                            icon: Icons.calendar_today_outlined,
                            title: '날짜 오래된순',
                            subtitle: '오래된 사진부터 표시',
                            isSelected:
                                currentSortOrder.value == SortOrder.dateOldest,
                            onTap: () => changeSortOrder(SortOrder.dateOldest),
                          ),
                          SortOptionItem(
                            icon: Icons.photo_size_select_small,
                            title: '파일 크기 작은순',
                            subtitle: '작은 파일부터 표시',
                            isSelected:
                                currentSortOrder.value == SortOrder.sizeAsc,
                            onTap: () => changeSortOrder(SortOrder.sizeAsc),
                          ),
                          SortOptionItem(
                            icon: Icons.photo_size_select_large,
                            title: '파일 크기 큰순',
                            subtitle: '큰 파일부터 표시',
                            isSelected:
                                currentSortOrder.value == SortOrder.sizeDesc,
                            onTap: () => changeSortOrder(SortOrder.sizeDesc),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
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
      photoService.loadSortOrderPreference().then((_) {
        currentSortOrder.value = photoService.currentSortOrder;
        loadPhotos();
      });
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
          // 정렬 버튼
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: showSortOptions,
            tooltip: '정렬',
          ),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 썸네일 이미지
                      thumbnails.value.containsKey(photo.asset.id)
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),

                      // 파일 크기 표시 (크기순 정렬인 경우에만)
                      if ((currentSortOrder.value == SortOrder.sizeAsc ||
                              currentSortOrder.value == SortOrder.sizeDesc) &&
                          photo.fileSize != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            color: Colors.black.withOpacity(0.5),
                            child: Text(
                              _formatFileSize(photo.fileSize!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // 파일 크기 포맷팅
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// 정렬 옵션 아이템 모델
class SortOptionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  SortOptionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });
}

// 애니메이션 정렬 옵션 목록
class _AnimatedSortOptionList extends StatelessWidget {
  final List<SortOptionItem> options;

  const _AnimatedSortOptionList({Key? key, required this.options})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];

        // 각 아이템에 지연 애니메이션 적용
        return AnimatedBuilder(
          animation: ModalRoute.of(context)!.animation!,
          builder: (context, child) {
            final animationValue = ModalRoute.of(context)!.animation!.value;
            final delay = index * 0.1;
            final value = (animationValue - delay).clamp(0.0, 1.0);

            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _buildSortOptionItem(
            context: context,
            icon: option.icon,
            title: option.title,
            subtitle: option.subtitle,
            isSelected: option.isSelected,
            onTap: option.onTap,
          ),
        );
      },
    );
  }

  // 정렬 옵션 아이템 위젯
  Widget _buildSortOptionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        onTap();
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
