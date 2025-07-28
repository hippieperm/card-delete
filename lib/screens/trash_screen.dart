import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import '../widgets/photo_card.dart';
import '../widgets/custom_dialog.dart';

class TrashScreen extends HookWidget {
  final PhotoService photoService;

  const TrashScreen({Key? key, required this.photoService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final trashPhotos = useState<List<PhotoModel>>(
      photoService.getTrashPhotos(),
    );

    // 휴지통 목록 새로고침
    void refreshTrash() {
      trashPhotos.value = photoService.getTrashPhotos();
    }

    // 사진 복원
    void restorePhoto(PhotoModel photo) {
      photoService.restoreFromTrash(photo);
      refreshTrash();
    }

    // 사진 영구 삭제
    Future<void> permanentlyDeletePhoto(PhotoModel photo) async {
      // 삭제 확인 다이얼로그 표시
      final confirm = await CustomDialog.show(
        context: context,
        title: '영구 삭제',
        message: '이 사진을 영구적으로 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
        confirmText: '삭제',
        icon: Icons.delete_forever,
        isDestructive: true,
      );

      if (confirm == true) {
        final success = await photoService.deleteFromTrash(photo);
        refreshTrash();
      }
    }

    // 휴지통 비우기
    Future<void> emptyTrash() async {
      // 확인 다이얼로그 표시
      final confirm = await CustomDialog.show(
        context: context,
        title: '휴지통 비우기',
        message: '휴지통의 모든 사진을 영구적으로 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
        confirmText: '모두 삭제',
        icon: Icons.delete_forever_rounded,
        isDestructive: true,
      );

      if (confirm == true) {
        await photoService.emptyTrash();
        refreshTrash();
      }
    }

    // 모든 사진 복원
    Future<void> restoreAllPhotos() async {
      // 확인 다이얼로그 표시
      final confirm = await CustomDialog.show(
        context: context,
        title: '모든 사진 복원',
        message: '휴지통의 모든 사진을 복원하시겠습니까?',
        confirmText: '모두 복원',
        icon: Icons.restore_rounded,
      );

      if (confirm == true) {
        // 모든 사진 복원
        for (final photo in List<PhotoModel>.from(trashPhotos.value)) {
          photoService.restoreFromTrash(photo);
        }

        refreshTrash();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('휴지통'),
        centerTitle: true,
        actions: [
          // 휴지통 비우기 버튼
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: trashPhotos.value.isEmpty ? null : emptyTrash,
            tooltip: '휴지통 비우기',
          ),
        ],
      ),
      body: trashPhotos.value.isEmpty
          ? _buildEmptyTrash()
          : Stack(
              children: [
                // 사진 목록
                ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 8,
                    top: 8,
                    bottom: 100, // 하단 버튼을 위한 패딩
                  ),
                  itemCount: trashPhotos.value.length,
                  itemBuilder: (context, index) {
                    final photo = trashPhotos.value[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          // 사진 표시
                          SizedBox(
                            height: 200,
                            width: double.infinity,
                            child: PhotoCard(photo: photo),
                          ),

                          // 삭제 날짜 표시
                          if (photo.trashDate != null)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '삭제일: ${_formatDate(photo.trashDate!)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          // 버튼 행
                          ButtonBar(
                            children: [
                              FilledButton.tonal(
                                onPressed: () => restorePhoto(photo),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.restore, size: 18),
                                    SizedBox(width: 4),
                                    Text('복원'),
                                  ],
                                ),
                              ),
                              FilledButton.tonal(
                                onPressed: () => permanentlyDeletePhoto(photo),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_forever, size: 18),
                                    SizedBox(width: 4),
                                    Text('영구 삭제'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // 하단 고정 버튼 (모두 복원, 모두 삭제)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          // 모두 복원 버튼
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: trashPhotos.value.isEmpty
                                  ? null
                                  : restoreAllPhotos,
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('모두 복원'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // 모두 삭제 버튼
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: trashPhotos.value.isEmpty
                                  ? null
                                  : emptyTrash,
                              icon: const Icon(Icons.delete_forever_rounded),
                              label: const Text('모두 삭제'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyTrash() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline,
            size: 80,
            color: Colors.grey.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          const Text(
            '휴지통이 비어 있습니다',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
