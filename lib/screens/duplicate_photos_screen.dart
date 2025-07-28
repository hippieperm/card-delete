import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import '../widgets/photo_card.dart';
import '../widgets/custom_dialog.dart';
import 'dart:typed_data';

class DuplicatePhotosScreen extends HookWidget {
  final PhotoService photoService;
  final List<PhotoModel> allPhotos;

  const DuplicatePhotosScreen({
    Key? key,
    required this.photoService,
    required this.allPhotos,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 상태 변수
    final isScanning = useState(false);
    final scanProgress = useState(0.0);
    final duplicateGroups = useState<Map<String, List<PhotoModel>>>({});
    final expandedGroups = useState<Set<String>>({});
    final selectedPhotos = useState<Set<String>>({});

    // 중복 사진 스캔
    Future<void> scanForDuplicates() async {
      if (isScanning.value) return;

      isScanning.value = true;
      scanProgress.value = 0.0;

      try {
        final result = await photoService.findDuplicatePhotos(
          allPhotos,
          onProgress: (progress) {
            scanProgress.value = progress;
          },
        );

        duplicateGroups.value = result;

        // 첫 번째 그룹 자동 확장
        if (result.isNotEmpty) {
          expandedGroups.value = {result.keys.first};
        }
      } finally {
        isScanning.value = false;
      }
    }

    // 선택된 중복 사진 삭제
    Future<void> deleteSelectedDuplicates() async {
      if (selectedPhotos.value.isEmpty) return;

      // 확인 다이얼로그 표시
      final confirm = await CustomDialog.show(
        context: context,
        title: '중복 사진 삭제',
        message: '${selectedPhotos.value.length}장의 중복 사진을 휴지통으로 이동하시겠습니까?',
        confirmText: '삭제',
        icon: Icons.delete_outline,
        isDestructive: true,
      );

      if (confirm != true) return;

      // 선택된 사진 찾기
      final photosToDelete = <PhotoModel>[];
      for (final group in duplicateGroups.value.values) {
        for (final photo in group) {
          if (selectedPhotos.value.contains(photo.asset.id)) {
            photosToDelete.add(photo);
          }
        }
      }

      // 삭제 처리
      await photoService.deleteDuplicatePhotos(photosToDelete);

      // 상태 업데이트
      duplicateGroups.value = photoService.getDuplicateGroups();
      selectedPhotos.value = {};

      // 완료 메시지
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${photosToDelete.length}장의 중복 사진이 휴지통으로 이동되었습니다'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    // 그룹 확장/축소 토글
    void toggleGroupExpansion(String groupId) {
      final newExpandedGroups = Set<String>.from(expandedGroups.value);
      if (newExpandedGroups.contains(groupId)) {
        newExpandedGroups.remove(groupId);
      } else {
        newExpandedGroups.add(groupId);
      }
      expandedGroups.value = newExpandedGroups;
    }

    // 사진 선택/해제 토글
    void togglePhotoSelection(String photoId) {
      final newSelection = Set<String>.from(selectedPhotos.value);
      if (newSelection.contains(photoId)) {
        newSelection.remove(photoId);
      } else {
        newSelection.add(photoId);
      }
      selectedPhotos.value = newSelection;
    }

    // 그룹 내 모든 사진 선택 (첫 번째 제외)
    void selectAllInGroup(List<PhotoModel> group) {
      if (group.length <= 1) return;

      final newSelection = Set<String>.from(selectedPhotos.value);
      // 첫 번째 항목을 제외한 모든 항목 선택
      for (int i = 1; i < group.length; i++) {
        newSelection.add(group[i].asset.id);
      }
      selectedPhotos.value = newSelection;
    }

    // 그룹 내 선택 해제
    void deselectAllInGroup(List<PhotoModel> group) {
      final newSelection = Set<String>.from(selectedPhotos.value);
      for (final photo in group) {
        newSelection.remove(photo.asset.id);
      }
      selectedPhotos.value = newSelection;
    }

    // 모든 그룹에서 중복 항목 선택 (각 그룹의 첫 번째 항목 제외)
    void selectAllDuplicates() {
      final newSelection = <String>{};
      for (final group in duplicateGroups.value.values) {
        if (group.length <= 1) continue;

        // 첫 번째 항목을 제외한 모든 항목 선택
        for (int i = 1; i < group.length; i++) {
          newSelection.add(group[i].asset.id);
        }
      }
      selectedPhotos.value = newSelection;
    }

    // 초기 스캔 실행
    useEffect(() {
      scanForDuplicates();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('중복 사진 관리'),
        centerTitle: true,
        actions: [
          // 스캔 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isScanning.value ? null : scanForDuplicates,
            tooltip: '중복 사진 다시 스캔',
          ),

          // 모두 선택 버튼
          if (duplicateGroups.value.isNotEmpty && !isScanning.value)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: selectAllDuplicates,
              tooltip: '모든 중복 사진 선택',
            ),
        ],
      ),
      body: isScanning.value
          ? _buildScanningUI(context, scanProgress.value)
          : duplicateGroups.value.isEmpty
          ? _buildEmptyState(context)
          : _buildDuplicatesList(
              context,
              duplicateGroups.value,
              expandedGroups.value,
              selectedPhotos.value,
              toggleGroupExpansion,
              togglePhotoSelection,
              selectAllInGroup,
              deselectAllInGroup,
            ),
      floatingActionButton: selectedPhotos.value.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: deleteSelectedDuplicates,
              icon: const Icon(Icons.delete),
              label: Text('${selectedPhotos.value.length}장 삭제'),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            )
          : null,
    );
  }

  // 스캔 중 UI
  Widget _buildScanningUI(BuildContext context, double progress) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('중복 사진 스캔 중...', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // 중복 사진이 없을 때 UI
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text('중복된 사진이 없습니다', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '모든 사진이 고유합니다',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // 중복 사진 목록 UI
  Widget _buildDuplicatesList(
    BuildContext context,
    Map<String, List<PhotoModel>> groups,
    Set<String> expandedGroups,
    Set<String> selectedPhotos,
    Function(String) toggleGroupExpansion,
    Function(String) togglePhotoSelection,
    Function(List<PhotoModel>) selectAllInGroup,
    Function(List<PhotoModel>) deselectAllInGroup,
  ) {
    final groupEntries = groups.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: groupEntries.length,
      itemBuilder: (context, index) {
        final entry = groupEntries[index];
        final groupId = entry.key;
        final photos = entry.value;
        final isExpanded = expandedGroups.contains(groupId);

        // 그룹 내 선택된 사진 수
        int selectedCount = 0;
        for (final photo in photos) {
          if (selectedPhotos.contains(photo.asset.id)) {
            selectedCount++;
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 그룹 헤더
              ListTile(
                title: Text('중복 그룹 #${index + 1} (${photos.length}장)'),
                subtitle: Text(
                  '${selectedCount}장 선택됨',
                  style: TextStyle(
                    color: selectedCount > 0
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    '${photos.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 그룹 내 모두 선택 버튼
                    IconButton(
                      icon: const Icon(Icons.select_all),
                      onPressed: () => selectAllInGroup(photos),
                      tooltip: '그룹 내 모두 선택',
                    ),
                    // 그룹 확장/축소 버튼
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                      onPressed: () => toggleGroupExpansion(groupId),
                      tooltip: isExpanded ? '접기' : '펼치기',
                    ),
                  ],
                ),
                onTap: () => toggleGroupExpansion(groupId),
              ),

              // 확장된 경우 사진 목록 표시
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 1.0,
                        ),
                    itemCount: photos.length,
                    itemBuilder: (context, photoIndex) {
                      final photo = photos[photoIndex];
                      final isSelected = selectedPhotos.contains(
                        photo.asset.id,
                      );
                      final isOriginal = photoIndex == 0; // 첫 번째 사진은 원본으로 간주

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // 사진 썸네일
                          GestureDetector(
                            onTap: () => togglePhotoSelection(photo.asset.id),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: PhotoCard(photo: photo),
                            ),
                          ),

                          // 선택 표시 오버레이
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),

                          // 원본 표시 배지
                          if (isOriginal)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '원본',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ),

                          // 날짜 표시 배지
                          Positioned(
                            bottom: 4,
                            left: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatDate(photo.asset.createDateTime),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 날짜 포맷팅
  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일';
  }
}
