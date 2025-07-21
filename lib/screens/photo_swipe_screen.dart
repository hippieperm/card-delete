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
                // 메인 카드 스와이퍼
                Expanded(
                  child: CardSwiper(
                    controller: controller,
                    cardsCount: photos.value.length,
                    cardBuilder:
                        (context, index, percentThresholdX, percentThresholdY) {
                          // 드래그 중에는 이미 생성된 카드를 재사용하기 위해 ValueKey 사용
                          return RepaintBoundary(
                            key: ValueKey(
                              'photo_card_${photos.value[index].asset.id}',
                            ),
                            child: PhotoCard(photo: photos.value[index]),
                          );
                        },
                    onSwipe: (previousIndex, currentIndex, direction) {
                      // 현재 인덱스 업데이트
                      if (currentIndex != null) {
                        currentCardIndex.value = currentIndex;

                        // 마지막 카드에 가까워지면 추가 로드
                        if (!isUsingDummyData.value &&
                            currentIndex >= photos.value.length - 3) {
                          loadMorePhotos();
                        }
                      }

                      if (direction == CardSwiperDirection.left) {
                        // 왼쪽으로 스와이프: 사진 삭제 (휴지통으로 이동)
                        deletePhoto(previousIndex);
                      }
                      // 오른쪽으로 스와이프: 다음 사진으로 넘어감
                      return true;
                    },
                    // 스와이프 방향 변경 이벤트는 지원하지 않는 것 같습니다.
                    // 대신 다른 방식으로 해결해보겠습니다.
                    numberOfCardsDisplayed: 1,
                    backCardOffset: const Offset(0, 0),
                    padding: const EdgeInsets.all(24.0),
                    allowedSwipeDirection:
                        const AllowedSwipeDirection.symmetric(horizontal: true),
                    threshold: 50, // 스와이프 감도 조정 (높을수록 덜 민감)
                    maxAngle: 30, // 최대 회전 각도 제한
                    isLoop: true, // 무한 루프 활성화
                    duration: const Duration(milliseconds: 400), // 애니메이션 지속 시간
                  ),
                ),

                // 하단 썸네일 리스트
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
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
                    itemCount:
                        photos.value.length + (isLoadingMore.value ? 1 : 0),
                    itemBuilder: (context, index) {
                      // 로딩 인디케이터 표시
                      if (index == photos.value.length) {
                        return Container(
                          width: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                        },
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: currentCardIndex.value == index
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildThumbnail(photo),
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

  Widget _buildThumbnail(PhotoModel photo) {
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

    // 실제 이미지는 FutureBuilder로 썸네일 로드
    return FutureBuilder<Uint8List?>(
      future: photo.asset.thumbnailDataWithSize(
        const ThumbnailSize.square(200),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
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
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.error, color: Colors.red, size: 24),
              ),
            );
          },
        );
      },
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
