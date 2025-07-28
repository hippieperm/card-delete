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
  // 페이징을 위한 변수
  AssetPathEntity? _recentAlbum;
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMorePhotos = true;

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
    if (_trashBin.isEmpty) return;

    try {
      // 모든 사진의 ID를 수집
      final List<String> assetIds = _trashBin
          .map((photo) => photo.asset.id)
          .toList();

      // 한 번에 모든 사진 삭제
      final result = await PhotoManager.editor.deleteWithIds(assetIds);

      // 삭제 성공한 사진만 휴지통에서 제거
      if (result.isNotEmpty) {
        _trashBin.removeWhere((photo) => result.contains(photo.asset.id));
      }

      print('휴지통 비우기 완료: ${result.length}개 삭제됨');
    } catch (e) {
      print('휴지통 비우기 중 오류 발생: $e');
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

  // 사진 초기 로드
  Future<List<PhotoModel>> loadPhotos() async {
    // 페이징 변수 초기화
    _currentPage = 0;
    _hasMorePhotos = true;

    final bool hasPermission = await requestPermission();
    if (!hasPermission) {
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
      _recentAlbum = albums.first;
      print(
        '앨범 로드: ${_recentAlbum!.name}, 사진 수: ${await _recentAlbum!.assetCountAsync}',
      );

      // 첫 페이지 로드
      return loadMorePhotos();
    } catch (e) {
      print('사진 로드 중 오류 발생: $e');
      return [];
    }
  }

  // 더 많은 사진 로드 (페이징)
  Future<List<PhotoModel>> loadMorePhotos() async {
    if (!_hasMorePhotos || _recentAlbum == null) {
      return [];
    }

    try {
      // 앨범에서 사진 가져오기
      final List<AssetEntity> assets = await _recentAlbum!.getAssetListRange(
        start: _currentPage * _pageSize,
        end: (_currentPage + 1) * _pageSize,
      );

      // 더 로드할 사진이 있는지 확인
      _hasMorePhotos = assets.length == _pageSize;

      // 페이지 증가
      _currentPage++;

      print('추가 사진 로드: ${assets.length}장, 총 페이지: $_currentPage');

      // 사진 모델로 변환
      return assets.map((asset) => PhotoModel(asset: asset)).toList();
    } catch (e) {
      print('추가 사진 로드 중 오류 발생: $e');
      return [];
    }
  }

  // 더 로드할 사진이 있는지 확인
  bool get hasMorePhotos => _hasMorePhotos;

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
