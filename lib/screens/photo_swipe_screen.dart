import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import '../widgets/photo_card.dart';
import '../widgets/custom_dialog.dart';
import '../widgets/adaptive_background.dart';
import 'dart:typed_data';
import 'trash_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'grid_view_screen.dart';

class PhotoSwipeScreen extends HookWidget {
  final int initialIndex;
  final Function(PhotoModel?)? onPhotoChanged;

  const PhotoSwipeScreen({super.key, this.initialIndex = 0, this.onPhotoChanged});

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
    final controller = useMemoized(() => CardSwiperController(), []);
    final currentCardIndex = useState(initialIndex);
    // 드래그 중인지 여부를 추적하는 상태
    final isDragging = useState(false);
    final currentPhoto = useState<PhotoModel?>(null);
    final currentSortOrder = useState<SortOrder>(photoService.currentSortOrder);

    // 사진 로드 함수
    Future<void> loadPhotos() async {
      if (!context.mounted) return; // 컨텍스트가 유효한지 확인

      isLoading.value = true;
      try {
        final permissionGranted = await photoService.requestPermission();
        if (!context.mounted) return; // 비동기 작업 후 컨텍스트 확인

        hasPermission.value = permissionGranted;

        if (permissionGranted) {
          final loadedPhotos = await photoService.loadPhotos();
          if (!context.mounted) return; // 비동기 작업 후 컨텍스트 확인

          photos.value = loadedPhotos;

          // 휴지통에 없는 사진만 표시 목록에 추가
          final filteredPhotos = loadedPhotos
              .where((photo) => !photo.isInTrash)
              .toList();

          displayPhotos.value = filteredPhotos;

          // 현재 표시할 사진 설정
          if (filteredPhotos.isNotEmpty) {
            final index = initialIndex < filteredPhotos.length
                ? initialIndex
                : 0;
            currentPhoto.value = filteredPhotos[index];
            // 콜백 호출
            if (onPhotoChanged != null) {
              onPhotoChanged!(filteredPhotos[index]);
            }
          } else {
            // 사진이 없는 경우
            currentPhoto.value = null;
            if (onPhotoChanged != null) {
              onPhotoChanged!(null);
            }
          }
        }
      } catch (e) {
        debugPrint('사진 로드 중 오류: $e');
      } finally {
        if (context.mounted) {
          // 컨텍스트가 유효한지 확인
          isLoading.value = false;
        }
      }
    }

    // 추가 사진 로드
    Future<void> loadMorePhotos() async {
      if (!context.mounted || isLoadingMore.value) return; // 컨텍스트 확인 및 중복 로드 방지

      isLoadingMore.value = true;
      try {
        final morePhotos = await photoService.loadMorePhotos();
        if (!context.mounted) return; // 비동기 작업 후 컨텍스트 확인

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
        if (context.mounted) {
          // 컨텍스트가 유효한지 확인
          isLoadingMore.value = false;
        }
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

    // 초기 데이터 로드
    useEffect(() {
      photoService.loadSortOrderPreference().then((_) {
        currentSortOrder.value = photoService.currentSortOrder;
        loadPhotos();
      });
      return () {
        // 명시적으로 아무것도 하지 않음 (ValueNotifier는 자동으로 dispose됨)
        // 이렇게 하면 FlutterError가 발생하지 않음
      };
    }, []);

    // 현재 카드 변경 시 호출되는 함수
    void onCardChanged(int previousIndex, int? currentIndex) {
      if (currentIndex == null) return;

      // 현재 인덱스 업데이트
      currentCardIndex.value = currentIndex;

      // 현재 표시 중인 사진 업데이트
      if (currentIndex < displayPhotos.value.length) {
        currentPhoto.value = displayPhotos.value[currentIndex];
        // 콜백 호출
        if (onPhotoChanged != null) {
          onPhotoChanged!(displayPhotos.value[currentIndex]);
        }
      }

      // 마지막 카드에 가까워지면 추가 로드
      if (!isUsingDummyData.value &&
          currentIndex >= displayPhotos.value.length - 3) {
        loadMorePhotos();
      }
    }

    // 사진 삭제 함수 (휴지통으로 이동)
    Future<void> deletePhoto(int index) async {
      if (displayPhotos.value.isEmpty || index >= displayPhotos.value.length) {
        return;
      }

      final photo = displayPhotos.value[index];

      // 삭제 확인 다이얼로그 표시 제거 - 메인 화면에서는 바로 삭제
      // 휴지통으로 이동
      await photoService.moveToTrash(photo);

      // 삭제된 사진을 목록에서 제거
      final updatedPhotos = List<PhotoModel>.from(displayPhotos.value);
      updatedPhotos.removeAt(index);
      displayPhotos.value = updatedPhotos;

      // 현재 표시 중인 사진 업데이트
      if (updatedPhotos.isNotEmpty &&
          currentCardIndex.value < updatedPhotos.length) {
        currentPhoto.value = updatedPhotos[currentCardIndex.value];
        // 콜백 호출
        if (onPhotoChanged != null) {
          onPhotoChanged!(updatedPhotos[currentCardIndex.value]);
        }
      } else if (updatedPhotos.isNotEmpty) {
        currentPhoto.value = updatedPhotos[0];
        // 콜백 호출
        if (onPhotoChanged != null) {
          onPhotoChanged!(updatedPhotos[0]);
        }
      } else {
        currentPhoto.value = null;
        // 콜백 호출
        if (onPhotoChanged != null) {
          onPhotoChanged!(null);
        }
      }

      deletedCount.value++;
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

    return AdaptiveBackground(
      photo: currentPhoto.value,
      enabled: currentPhoto.value != null,
      child: Scaffold(
        backgroundColor: Colors.transparent, // 배경을 투명하게 설정
        extendBodyBehindAppBar: true, // AppBar 뒤로 body 확장
        appBar: AppBar(
          backgroundColor: Colors.transparent, // AppBar 배경 투명하게
          elevation: 0,
          title: const Text('사진 정리하기'),
          centerTitle: true,
          actions: [
            // 정렬 버튼
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: showSortOptions,
              tooltip: '정렬',
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
            : SafeArea(
                child: Column(
                  children: [
                    // 메인 카드 스와이퍼
                    Expanded(
                      child: CardSwiper(
                        controller: controller,
                        cardsCount: displayPhotos.value.length,
                        cardBuilder:
                            (
                              context,
                              index,
                              percentThresholdX,
                              percentThresholdY,
                            ) {
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
                                child: PhotoCard(
                                  photo: displayPhotos.value[index],
                                ),
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
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .error
                                                  .withOpacity(0.5 * progress)
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .primary
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
                            const AllowedSwipeDirection.symmetric(
                              horizontal: true,
                            ),
                        threshold: 50, // 스와이프 감도 조정 (높을수록 덜 민감)
                        maxAngle: 30.0, // 최대 회전 각도 제한
                        isLoop: true, // 무한 루프 활성화
                        duration: const Duration(
                          milliseconds: 400,
                        ), // 애니메이션 지속 시간
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
              ),
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
                      overlayColor: WidgetStateProperty.resolveWith<Color?>(
                        (states) => states.contains(WidgetState.pressed)
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

  const _AnimatedSortOptionList({super.key, required this.options});

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
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
