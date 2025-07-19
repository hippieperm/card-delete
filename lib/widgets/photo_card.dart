import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';
import '../models/photo_model.dart';
import '../services/photo_service.dart';

class PhotoCard extends StatelessWidget {
  final PhotoModel photo;

  const PhotoCard({Key? key, required this.photo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // 사진 표시
            Positioned.fill(child: _buildPhotoWidget()),

            // 휴지통 표시 (휴지통에 있는 경우)
            if (photo.isInTrash)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '휴지통',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 사진 정보 표시 (하단)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(photo.asset.createDateTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${photo.asset.width} x ${photo.asset.height}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 사진 위젯 생성
  Widget _buildPhotoWidget() {
    // DummyAssetEntity인 경우 색상 박스 표시
    if (photo.asset is DummyAssetEntity) {
      return Container(
        color: _getRandomColor(),
        child: Center(
          child: Icon(
            Icons.image,
            size: 100,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      );
    }

    // 실제 이미지 로드 시도
    return FutureBuilder<Uint8List?>(
      future: _loadThumbnail(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          print('사진 로드 오류: ${snapshot.error}');
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.red, size: 50),
                  SizedBox(height: 8),
                  Text('이미지를 불러올 수 없습니다', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('이미지 렌더링 오류: $error');
            return Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.error, color: Colors.red, size: 50),
              ),
            );
          },
        );
      },
    );
  }

  // 랜덤 색상 생성
  Color _getRandomColor() {
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
    return colors[index.abs()];
  }

  // 썸네일 로드 함수
  Future<Uint8List?> _loadThumbnail() async {
    try {
      // 먼저 작은 썸네일 시도
      final data = await photo.asset.thumbnailDataWithSize(
        const ThumbnailSize.square(500),
      );

      if (data != null && data.isNotEmpty) return data;

      // 실패하면 원본 데이터 시도
      final originData = await photo.asset.originBytes;
      if (originData != null && originData.isNotEmpty) return originData;

      // 모두 실패하면 null 반환
      print('썸네일과 원본 모두 로드 실패');
      return null;
    } catch (e) {
      print('썸네일 로드 중 오류: $e');
      return null;
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일';
  }
}
