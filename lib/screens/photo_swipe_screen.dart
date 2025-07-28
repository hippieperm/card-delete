import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import '../widgets/photo_card.dart';
import 'dart:typed_data';
import 'trash_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'grid_view_screen.dart';

class PhotoSwipeScreen extends HookWidget {
  final int initialIndex;

  const PhotoSwipeScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  // 썸네일 캐시
  static final Map<String, Uint8List> _thumbnailCache = {};

  @override
  Widget build(BuildContext context) {
    final photoService = useMemoized(() => PhotoService(), []);
    final photos = useState<List<PhotoModel>>([]);
    final displayPhotos = useState<List<PhotoModel>>([]);
    final isLoading = useState(true);
    final isLoadingMore = useState(false);
    final hasPermission = useState(false);
    final deletedCount = useState(0);
    final isUsingDummyData = useState(false);
    final currentCardIndex = useState(initialIndex);
    final CardSwiperController controller = useMemoized(
      () => CardSwiperController(),
      [],
    );
    // 드래그 중인지 여부를 추적하는 상태
    final isDragging = useState(false);

    // 추가 사진 로드
    Future<void> loadMorePhotos() async {
      if (isLoadingMore.value || isUsingDummyData.value) return;

      isLoadingMore.value = true;
      try {
        final morePhotos = await photoService.loadMorePhotos();
        if (morePhotos.isNotEmpty) {
          // 전체 사진 목록 업데이트
          photos.value = [...photos.value, ...morePhotos];

          // 휴지통에 없는 사진만 표시 목록에 추가
          final newPhotos = morePhotos
              .where((photo) => !photo.isInTrash)
              .toList();
          if (newPhotos.isNotEmpty) {
            displayPhotos.value = [...displayPhotos.value, ...newPhotos];
          }
        }
      } finally {
        isLoadingMore.value = false;
      }
    }

    // 현재 카드 변경 시 호출되는 함수
    void onCardChanged(int previousIndex, int? currentIndex) {
      if (currentIndex == null) return;

      // 현재 인덱스 업데이트
      currentCardIndex.value = currentIndex;

      // 마지막 카드에 가까워지면 추가 로드
      if (!isUsingDummyData.value &&
          currentIndex >= displayPhotos.value.length - 3) {
        loadMorePhotos();
      }
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

          // 휴지통에 없는 사진만 표시 목록에 추가
          final filteredPhotos = loadedPhotos
              .where((photo) => !photo.isInTrash)
              .toList();
          displayPhotos.value = filteredPhotos;

          if (displayPhotos.value.isEmpty) {
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
      } finally {
        isLoading.value = false;
      }
    }

    // 사진 삭제 함수 (휴지통으로 이동)
    Future<void> deletePhoto(int index) async {
      if (displayPhotos.value.isEmpty || index >= displayPhotos.value.length)
        return;

      final photo = displayPhotos.value[index];

      // 휴지통으로 이동
      await photoService.moveToTrash(photo);

      // 삭제된 사진을 목록에서 제거
      final updatedPhotos = List<PhotoModel>.from(displayPhotos.value);
      updatedPhotos.removeAt(index);
      displayPhotos.value = updatedPhotos;

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
              final restoredPhotos = List<PhotoModel>.from(displayPhotos.value);
              if (index < restoredPhotos.length) {
                restoredPhotos.insert(index, photo);
              } else {
                restoredPhotos.add(photo);
              }
              displayPhotos.value = restoredPhotos;
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

    // 그리드 화면으로 이동
    void navigateToGrid() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GridViewScreen()),
      ).then((_) {
        // 그리드 화면에서 돌아오면 목록 새로고침
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
        title: const Text('사진 정리하기'),
        centerTitle: true,
        actions: [
          // 그리드 보기 버튼
          IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: navigateToGrid,
            tooltip: '그리드 보기',
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
          : displayPhotos.value.isEmpty
          ? _buildNoPhotos(context)
          : Column(
              children: [
                // 메인 카드 스와이퍼
                Expanded(
                  child: CardSwiper(
                    controller: controller,
                    cardsCount: displayPhotos.value.length,
                    cardBuilder:
                        (context, index, percentThresholdX, percentThresholdY) {
                          // 인덱스 범위 확인
                          if (index >= displayPhotos.value.length) {
                            return Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              child: const Center(
                                child: Text('사진을 불러올 수 없습니다'),
                              ),
                            );
                          }

                          // 드래그 중에는 이미 생성된 카드를 재사용하기 위해 ValueKey 사용
                          final card = RepaintBoundary(
                            key: ValueKey(
                              'photo_card_${displayPhotos.value[index].asset.id}',
                            ),
                            child: PhotoCard(photo: displayPhotos.value[index]),
                          );

                          // 스와이프 방향에 따른 오버레이 추가
                          if (percentThresholdX.abs() < 0.05) {
                            // 스와이프가 거의 없는 경우 기본 카드만 표시
                            return card;
                          }

                          // 스와이프 방향 및 진행률
                          final isLeftSwipe = percentThresholdX < 0;
                          final progress = percentThresholdX.abs().clamp(
                            0.0,
                            1.0,
                          );

                          // 아이콘 크기 계산 (정수로 변환)
                          final iconSize = (24 + (56 * progress)).toInt();

                          return Stack(
                            children: [
                              // 기본 카드
                              card,

                              // 스와이프 방향에 따른 오버레이
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isLeftSwipe
                                        ? Theme.of(context).colorScheme.error
                                              .withOpacity(0.5 * progress)
                                        : Theme.of(context).colorScheme.primary
                                              .withOpacity(0.3 * progress),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isLeftSwipe
                                          ? Icons.delete_forever
                                          : Icons.arrow_forward,
                                      color: Colors.white,
                                      size: iconSize.toDouble(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                    onSwipe: (previousIndex, currentIndex, direction) {
                      // 사진이 없으면 스와이프 무시
                      if (displayPhotos.value.isEmpty) return false;

                      // 현재 인덱스 업데이트 및 썸네일 미리 로드
                      onCardChanged(previousIndex, currentIndex);

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
                    allowedSwipeDirection:
                        const AllowedSwipeDirection.symmetric(horizontal: true),
                    threshold: 50, // 스와이프 감도 조정 (높을수록 덜 민감)
                    maxAngle: 30.0, // 최대 회전 각도 제한
                    isLoop: true, // 무한 루프 활성화
                    duration: const Duration(milliseconds: 400), // 애니메이션 지속 시간
                    initialIndex: initialIndex < displayPhotos.value.length
                        ? initialIndex
                        : 0,
                  ),
                ),

                // 하단 컨트롤 버튼
                _buildBottomControls(
                  context,
                  controller,
                  displayPhotos.value.isEmpty,
                ),
              ],
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

  Widget _buildBottomControls(
    BuildContext context,
    CardSwiperController controller,
    bool isPhotosEmpty,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 삭제 버튼
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.tonalIcon(
                onPressed: isPhotosEmpty ? null : () => controller.swipeLeft(),
                icon: const Icon(Icons.delete_outline),
                label: const Text('삭제'),
                style:
                    FilledButton.styleFrom(
                      backgroundColor: colorScheme.errorContainer,
                      foregroundColor: colorScheme.onErrorContainer,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ).copyWith(
                      overlayColor: MaterialStateProperty.resolveWith<Color?>(
                        (states) => states.contains(MaterialState.pressed)
                            ? colorScheme.error.withOpacity(0.1)
                            : null,
                      ),
                    ),
              ),
            ),
          ),

          // 다음 버튼
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: FilledButton.icon(
                onPressed: isPhotosEmpty ? null : () => controller.swipeRight(),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('다음'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
