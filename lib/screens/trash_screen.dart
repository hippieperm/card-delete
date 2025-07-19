import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import '../widgets/photo_card.dart';

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사진이 복원되었습니다'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }

    // 사진 영구 삭제
    Future<void> permanentlyDeletePhoto(PhotoModel photo) async {
      final success = await photoService.deleteFromTrash(photo);
      refreshTrash();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진이 영구적으로 삭제되었습니다'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
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

    // 휴지통 비우기
    Future<void> emptyTrash() async {
      // 확인 다이얼로그 표시
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('휴지통 비우기'),
          content: const Text('휴지통의 모든 사진을 영구적으로 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await photoService.emptyTrash();
        refreshTrash();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('휴지통을 비웠습니다'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 1),
            ),
          );
        }
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
          : ListView.builder(
              padding: const EdgeInsets.all(8),
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
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),

                      // 버튼 행
                      ButtonBar(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.restore),
                            label: const Text('복원'),
                            onPressed: () => restorePhoto(photo),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('영구 삭제'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () => permanentlyDeletePhoto(photo),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyTrash() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
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
