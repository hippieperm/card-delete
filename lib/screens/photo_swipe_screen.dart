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

class PhotoSwipeScreen extends HookWidget {
  const PhotoSwipeScreen({Key? key}) : super(key: key);

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
    final isUsingDummyData = useState(false);
    final currentCardIndex = useState(0);
    final scrollController = useMemoized(() => ScrollController(), []);
    final CardSwiperController controller = useMemoized(
      () => CardSwiperController(),
      [],
    );
    // 드래그 중인지 여부를 추적하는 상태
    final isDragging = useState(false);

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

    // 추가 사진 로드
    Future<void> loadMorePhotos() async {
      if (isLoadingMore.value || isUsingDummyData.value) return;

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

    // 썸네일 로드 및 캐싱 함수
    Future<Uint8List?> loadThumbnail(PhotoModel photo, String cacheKey) async {
      try {
        // 이미 로드 중인지 확인 (중복 로드 방지)
        if (_thumbnailCache.containsKey(cacheKey)) {
          return _thumbnailCache[cacheKey];
        }

        // 작은 썸네일 크기로 로드
        final thumbnailOption = ThumbnailOption(
          size: const ThumbnailSize.square(200),
          format: ThumbnailFormat.jpeg,
          quality: 80, // 품질 낮춰 빠르게 로드
        );

        final data = await photo.asset.thumbnailDataWithOption(thumbnailOption);

        if (data != null && data.isNotEmpty) {
          // 캐시에 저장
          _thumbnailCache[cacheKey] = data;
          return data;
        }

        return null;
      } catch (e) {
        print('썸네일 로드 오류: $e');
        return null;
      }
    }

    // 여러 썸네일을 미리 로드하는 함수
    void preloadThumbnails(int currentIdx) {
      final photosList = photos.value;
      // 현재 보이는 항목 주변의 썸네일을 미리 로드 (앞뒤로 5개씩)
      final startIdx = (currentIdx - 5).clamp(0, photosList.length - 1);
      final endIdx = (currentIdx + 5).clamp(0, photosList.length - 1);

      for (int i = startIdx; i <= endIdx; i++) {
        if (i == currentIdx) continue; // 현재 항목은 이미 로드 중

        final photo = photosList[i];
        if (photo.asset is DummyAssetEntity) continue; // 더미 이미지는 로드할 필요 없음

        final cacheKey = 'thumb_${photo.asset.id}';
        if (!_thumbnailCache.containsKey(cacheKey)) {
          // 백그라운드에서 썸네일 로드
          loadThumbnail(photo, cacheKey);
        }
      }
    }

    // 현재 카드 변경 시 호출되는 함수
    void onCardChanged(int previousIndex, int? currentIndex) {
      if (currentIndex == null) return;

      // 현재 인덱스 업데이트
      currentCardIndex.value = currentIndex;

      // 마지막 카드에 가까워지면 추가 로드
      if (!isUsingDummyData.value && currentIndex >= photos.value.length - 3) {
        loadMorePhotos();
      }

      // 썸네일 미리 로드
      preloadThumbnails(currentIndex);
    }

    // 스크롤 이벤트 리스너
    useEffect(() {
      void onScroll() {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 100) {
          loadMorePhotos();
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController]);

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

    // 썸네일 위젯 생성 함수
    Widget buildThumbnail(PhotoModel photo) {
      if (photo.asset is DummyAssetEntity) {
        // 테스트 이미지인 경우 색상 박스 표시
        final colors = [
          Colors.blue,
          Colors.red,
          Colors.green,
          Colors.orange,
          Colors.purple,
          Colors.teal,
          Colors.amber,
          Colors.indigo,
        ];

        // 에셋 ID를 기반으로 일관된 색상 선택
        final index = photo.asset.id.hashCode % colors.length;
        final color = colors[index.abs()];

        return Container(
          color: color,
          child: Center(
            child: Icon(
              Icons.image,
              size: 24,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        );
      }

      // 실제 이미지는 메모리 캐시를 활용하여 로드
      final String cacheKey = 'thumb_${photo.asset.id}';

      // 캐시된 이미지가 있는지 확인
      if (_thumbnailCache.containsKey(cacheKey)) {
        return Image.memory(
          _thumbnailCache[cacheKey]!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: 200, // 썸네일은 작은 크기로 캐싱
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.red, size: 24),
              ),
            );
          },
        );
      }

      // 캐시된 이미지가 없으면 FutureBuilder로 로드
      return FutureBuilder<Uint8List?>(
        future: loadThumbnail(photo, cacheKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.red, size: 24),
              ),
            );
          }

          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 200, // 썸네일은 작은 크기로 캐싱
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.red, size: 24),
                ),
              );
            },
          );
        },
      );
    }

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
              color: isUsingDummyData.value
                  ? Theme.of(context).colorScheme.primary
                  : null,
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
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : !hasPermission.value
          ? _buildPermissionDenied(context)
          : photos.value.isEmpty
          ? _buildNoPhotos(context)
          : Column(
              children: [
                // 메인 카드 스와이퍼
                Expanded(
                  child: CardSwiper(
                    controller: controller,
                    cardsCount: photos.value.length,
                    cardBuilder:
                        (context, index, percentThresholdX, percentThresholdY) {
                          // 드래그 중에는 이미 생성된 카드를 재사용하기 위해 ValueKey 사용
                          final card = RepaintBoundary(
                            key: ValueKey(
                              'photo_card_${photos.value[index].asset.id}',
                            ),
                            child: PhotoCard(photo: photos.value[index]),
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
                  ),
                ),

                // 하단 썸네일 리스트
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    // 성능 최적화: 화면에 보이는 항목만 빌드
                    cacheExtent: 500, // 캐시 확장
                    itemCount:
                        photos.value.length + (isLoadingMore.value ? 1 : 0),
                    itemBuilder: (context, index) {
                      // 로딩 인디케이터 표시
                      if (index == photos.value.length) {
                        return Container(
                          width: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      }

                      final photo = photos.value[index];
                      return GestureDetector(
                        onTap: () {
                          // 해당 인덱스로 메인 카드 이동
                          // 현재 인덱스와 탭한 인덱스의 차이에 따라 왼쪽/오른쪽으로 스와이프
                          final currentIndex = currentCardIndex.value;
                          if (currentIndex < index) {
                            // 오른쪽으로 이동 (다음 사진)
                            for (int i = currentIndex; i < index; i++) {
                              controller.swipeRight();
                            }
                          } else if (currentIndex > index) {
                            // 왼쪽으로 이동 (이전 사진)
                            for (int i = index; i < currentIndex; i++) {
                              controller.swipeLeft();
                            }
                          }
                          // 현재 인덱스 업데이트
                          currentCardIndex.value = index;
                          // 썸네일 미리 로드
                          preloadThumbnails(index);
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: currentCardIndex.value == index
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: buildThumbnail(photo),
                        ),
                      );
                    },
                  ),
                ),

                // 하단 컨트롤 버튼
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
                onPressed: () => controller.swipeLeft(),
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
                onPressed: () => controller.swipeRight(),
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
