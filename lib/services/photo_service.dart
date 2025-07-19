import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/photo_model.dart';
import 'package:flutter/material.dart';

// 테스트용 더미 에셋 클래스
class DummyAssetEntity extends AssetEntity {
  final DateTime _createDateTime;

  DummyAssetEntity({
    required String id,
    required int width,
    required int height,
    required DateTime createDateTime,
  }) : _createDateTime = createDateTime,
       super(
         id: id,
         typeInt: 1, // 이미지 타입
         width: width,
         height: height,
         duration: 0, // 이미지는 duration이 0
       );

  @override
  Future<Uint8List?> get thumbnailData async {
    // 랜덤 색상의 이미지 생성
    return _generateColorImage();
  }

  @override
  Future<Uint8List?> thumbnailDataWithOption(
    ThumbnailOption option, {
    PMProgressHandler? progressHandler,
  }) async {
    // 랜덤 색상의 이미지 생성
    return _generateColorImage();
  }

  @override
  Future<Uint8List?> thumbnailDataWithSize(
    ThumbnailSize size, {
    ThumbnailFormat format = ThumbnailFormat.jpeg,
    int quality = 100,
    int frame = 0,
    PMProgressHandler? progressHandler,
  }) async {
    // 랜덤 색상의 이미지 생성
    return _generateColorImage();
  }

  @override
  Future<Uint8List?> get originBytes async {
    // 랜덤 색상의 이미지 생성
    return _generateColorImage();
  }

  @override
  DateTime get createDateTime => _createDateTime;

  // 랜덤 색상의 이미지 데이터 생성
  Uint8List _generateColorImage() {
    // 간단한 테스트 이미지 생성 (1x1 픽셀 PNG)
    // 이 데이터는 1x1 투명 PNG 이미지의 바이너리 데이터입니다
    final List<int> pngData = [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      8,
      6,
      0,
      0,
      0,
      31,
      21,
      196,
      137,
      0,
      0,
      0,
      13,
      73,
      68,
      65,
      84,
      120,
      156,
      99,
      250,
      207,
      240,
      31,
      0,
      4,
      2,
      1,
      0,
      73,
      106,
      7,
      118,
      0,
      0,
      0,
      0,
      73,
      69,
      78,
      68,
      174,
      66,
      96,
      130,
    ];

    return Uint8List.fromList(pngData);
  }
}

class PhotoService {
  // 휴지통에 있는 사진 목록
  final List<PhotoModel> _trashBin = [];

  // 휴지통 목록 가져오기
  List<PhotoModel> getTrashPhotos() {
    return List.unmodifiable(_trashBin);
  }

  // 휴지통으로 사진 이동
  void moveToTrash(PhotoModel photo) {
    photo.moveToTrash();
    if (!_trashBin.contains(photo)) {
      _trashBin.add(photo);
    }
  }

  // 휴지통에서 사진 복원
  void restoreFromTrash(PhotoModel photo) {
    photo.restoreFromTrash();
    _trashBin.remove(photo);
  }

  // 휴지통 비우기
  Future<void> emptyTrash() async {
    for (final photo in _trashBin.toList()) {
      await deletePhoto(photo.asset);
      _trashBin.remove(photo);
    }
  }

  // 휴지통에서 특정 사진 영구 삭제
  Future<bool> deleteFromTrash(PhotoModel photo) async {
    final result = await deletePhoto(photo.asset);
    if (result) {
      _trashBin.remove(photo);
    }
    return result;
  }

  // 테스트용 더미 사진 생성
  List<PhotoModel> getDummyPhotos() {
    // 테스트 이미지 데이터 생성
    final List<PhotoModel> dummyPhotos = [];

    // 5개의 테스트 이미지 생성
    for (int i = 0; i < 5; i++) {
      final dummyAsset = DummyAssetEntity(
        id: 'dummy_$i',
        width: 800,
        height: 600,
        createDateTime: DateTime.now().subtract(Duration(days: i)),
      );

      dummyPhotos.add(PhotoModel(asset: dummyAsset));
    }

    return dummyPhotos;
  }

  // 사진 권한 요청
  Future<bool> requestPermission() async {
    // 먼저 permission_handler로 권한 요청
    final status = await Permission.photos.request();
    if (status.isGranted) {
      return true;
    }

    // photo_manager로 권한 확인
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }

  // 모든 사진 가져오기
  Future<List<PhotoModel>> loadPhotos() async {
    final bool hasPermission = await requestPermission();
    if (!hasPermission) {
      print('사진 접근 권한이 없습니다.');
      return [];
    }

    try {
      // 모든 앨범 가져오기
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.image,
      );

      if (albums.isEmpty) {
        print('사용 가능한 앨범이 없습니다.');
        return [];
      }

      // 최근 사진 앨범 선택
      final AssetPathEntity recentAlbum = albums.first;
      print(
        '앨범 로드: ${recentAlbum.name}, 사진 수: ${await recentAlbum.assetCountAsync}',
      );

      // 앨범에서 사진 가져오기
      final List<AssetEntity> assets = await recentAlbum.getAssetListRange(
        start: 0,
        end: 100, // 최대 100개 사진만 로드 (성능 향상을 위해)
      );

      print('로드된 사진 수: ${assets.length}');

      // 사진 모델로 변환
      return assets.map((asset) => PhotoModel(asset: asset)).toList();
    } catch (e) {
      print('사진 로드 중 오류 발생: $e');
      return [];
    }
  }

  // 사진 삭제
  Future<bool> deletePhoto(AssetEntity asset) async {
    try {
      // PhotoManager.editor를 사용하여 사진 삭제 (iOS, Android 모두 동일하게 처리)
      final result = await PhotoManager.editor.deleteWithIds([asset.id]);
      return result.isNotEmpty;
    } catch (e) {
      print('사진 삭제 중 오류 발생: $e');
      return false;
    }
  }
}
