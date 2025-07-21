import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';
import '../models/photo_model.dart';
import '../services/photo_service.dart';

class PhotoCard extends StatelessWidget {
  final PhotoModel photo;

  // 이미지 캐싱을 위한 정적 맵
  static final Map<String, Uint8List> _imageCache = {};

  const PhotoCard({Key? key, required this.photo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: AbsorbPointer(
          absorbing: true,
          child: Stack(
            children: [
              // 사진 표시
              Positioned.fill(child: _buildPhotoWidget()),

              // 휴지통 표시 (휴지통에 있는 경우)
              if (photo.isInTrash)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete,
                          color: colorScheme.onError,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '휴지통',
                          style: TextStyle(
                            color: colorScheme.onError,
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
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

    // 캐시에서 이미지 확인
    final String cacheKey = photo.asset.id;
    if (_imageCache.containsKey(cacheKey)) {
      return Image.memory(
        _imageCache[cacheKey]!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: 1000, // 캐싱 최적화
        cacheHeight: 1000, // 캐싱 최적화
        filterQuality: FilterQuality.medium, // 렌더링 품질
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.error, color: Colors.red, size: 50),
            ),
          );
        },
      );
    }

    // 캐시에 없는 경우 FutureBuilder로 로드
    return FutureBuilder<Uint8List?>(
      key: ValueKey('photo_future_${photo.asset.id}'), // 키를 사용하여 불필요한 재구축 방지
      future: _loadThumbnail(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[100],
            child: const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
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
          gaplessPlayback: true,
          cacheWidth: 1000, // 캐싱 최적화
          cacheHeight: 1000, // 캐싱 최적화
          filterQuality: FilterQuality.medium, // 렌더링 품질
          errorBuilder: (context, error, stackTrace) {
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
    final String cacheKey = photo.asset.id;

    // 캐시에서 이미지 확인
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey];
    }

    try {
      // 캐싱을 위한 옵션 설정
      final ThumbnailOption option = ThumbnailOption(
        size: const ThumbnailSize.square(500),
        format: ThumbnailFormat.jpeg,
        quality: 95,
      );

      // 캐싱된 썸네일 시도
      final data = await photo.asset.thumbnailDataWithOption(option);

      if (data != null && data.isNotEmpty) {
        // 캐시에 저장
        _imageCache[cacheKey] = data;
        return data;
      }

      // 실패하면 원본 데이터 시도
      final originData = await photo.asset.originBytes;
      if (originData != null && originData.isNotEmpty) {
        // 캐시에 저장
        _imageCache[cacheKey] = originData;
        return originData;
      }

      // 모두 실패하면 null 반환
      return null;
    } catch (e) {
      return null;
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일';
  }
}
