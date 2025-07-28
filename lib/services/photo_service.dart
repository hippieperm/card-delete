import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/photo_model.dart';

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
  // 싱글톤 인스턴스
  static final PhotoService _instance = PhotoService._internal();

  // 싱글톤 팩토리 생성자
  factory PhotoService() {
    return _instance;
  }

  // 내부 생성자
  PhotoService._internal() {
    _loadTrashBin();
  }

  // 휴지통 저장 키
  static const String _trashBinKey = 'photo_trash_bin';

  // 중복 사진 캐시 키
  static const String _duplicatePhotosKey = 'duplicate_photos';

  // 앨범 및 사진 관련 변수
  AssetPathEntity? _recentAlbum;
  int _currentPage = 0;
  final int _pageSize = 30;
  final Map<String, DateTime> _trashBin = {}; // 휴지통 (asset ID -> 삭제 날짜)

  // 중복 사진 관련 변수
  final Map<String, List<PhotoModel>> _duplicateGroups = {}; // 해시값 -> 중복 사진 목록
  bool _isDuplicateScanRunning = false;

  // 썸네일 캐시
  final Map<String, Uint8List> _thumbnailCache = {};

  // 권한 요청
  Future<bool> requestPermission() async {
    debugPrint('권한 요청 시작');

    // 안드로이드 13(API 33) 이상에서는 READ_MEDIA_IMAGES 권한 필요
    // 안드로이드 12 이하에서는 READ_EXTERNAL_STORAGE 권한 필요
    try {
      // 먼저 photo_manager의 권한 요청
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      debugPrint('photo_manager 권한 상태: ${ps.isAuth}');

      if (ps.isAuth) {
        return true;
      }

      debugPrint('photo_manager 권한 거부됨, permission_handler로 시도');

      // permission_handler를 사용하여 직접 권한 요청
      // 안드로이드 13 이상
      final photos = await Permission.photos.request();
      debugPrint('Permission.photos 상태: ${photos.isGranted}');

      // 안드로이드 12 이하
      final storage = await Permission.storage.request();
      debugPrint('Permission.storage 상태: ${storage.isGranted}');

      // 미디어 라이브러리 (iOS)
      final media = await Permission.mediaLibrary.request();
      debugPrint('Permission.mediaLibrary 상태: ${media.isGranted}');

      // 추가 권한 시도 (안드로이드 13 이상)
      await Permission.accessMediaLocation.request();

      if (photos.isGranted || storage.isGranted || media.isGranted) {
        // 권한이 부여되었으므로 photo_manager 권한 다시 확인
        final PermissionState newPs =
            await PhotoManager.requestPermissionExtend();
        debugPrint('photo_manager 권한 재확인: ${newPs.isAuth}');

        // 마지막 시도 - 직접 PhotoManager 초기화
        if (!newPs.isAuth) {
          debugPrint('PhotoManager 초기화 시도');
          await PhotoManager.clearFileCache();
          await PhotoManager.setIgnorePermissionCheck(true);
          final finalPs = await PhotoManager.requestPermissionExtend();
          debugPrint('최종 권한 상태: ${finalPs.isAuth}');
          return finalPs.isAuth;
        }

        return newPs.isAuth;
      }

      // 사용자에게 설정으로 이동하도록 안내
      debugPrint('사진 접근 권한이 거부되었습니다. 설정에서 권한을 허용해주세요.');
      return false;
    } catch (e) {
      debugPrint('권한 요청 중 오류 발생: $e');
      return false;
    }
  }

  // 사진 로드
  Future<List<PhotoModel>> loadPhotos() async {
    debugPrint('loadPhotos 호출됨 - PhotoService');
    _currentPage = 0;

    try {
      // 권한 확인
      final permitted = await requestPermission();
      debugPrint('권한 확인 결과: $permitted');
      if (!permitted) {
        debugPrint('권한 없음, 빈 목록 반환');
        return [];
      }

      // PhotoManager 초기화 시도
      try {
        debugPrint('PhotoManager 초기화 시도');
        await PhotoManager.clearFileCache();
        await PhotoManager.setIgnorePermissionCheck(true);
      } catch (e) {
        debugPrint('PhotoManager 초기화 오류 (무시): $e');
      }

      // 앨범 로드
      try {
        debugPrint('앨범 로드 시작');
        final albums =
            await PhotoManager.getAssetPathList(
              onlyAll: true,
              type: RequestType.image,
              hasAll: true,
            ).timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                debugPrint('앨범 로드 타임아웃');
                return [];
              },
            );

        debugPrint('앨범 수: ${albums.length}');

        if (albums.isEmpty) {
          debugPrint('앨범이 없음, 빈 목록 반환');
          return [];
        }

        _recentAlbum = albums.first;
        debugPrint('최근 앨범 설정됨: ${_recentAlbum?.name}');
      } catch (e) {
        debugPrint('앨범 로드 오류: $e');
        return [];
      }

      // 에셋 로드 (직접 방식 시도)
      try {
        debugPrint('에셋 로드 시작: 직접 방식');

        // 직접 에셋 로드 시도
        final List<AssetEntity> assets = await _recentAlbum!
            .getAssetListRange(start: 0, end: _pageSize)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('직접 에셋 로드 타임아웃');
                return [];
              },
            );

        debugPrint('직접 로드된 에셋 수: ${assets.length}');

        if (assets.isNotEmpty) {
          _currentPage++;

          // 에셋으로 PhotoModel 생성
          final List<PhotoModel> photos = [];
          for (final asset in assets) {
            try {
              final isInTrash = _trashBin.containsKey(asset.id);
              final trashDate = _trashBin[asset.id];
              photos.add(
                PhotoModel(
                  asset: asset,
                  isInTrash: isInTrash,
                  trashDate: trashDate,
                ),
              );
            } catch (e) {
              debugPrint('PhotoModel 생성 오류: $e');
              // 개별 오류는 무시하고 계속 진행
            }
          }

          debugPrint('반환할 사진 모델 수 (직접 방식): ${photos.length}');
          return photos;
        }
      } catch (e) {
        debugPrint('직접 에셋 로드 오류 (페이징 방식으로 대체): $e');
      }

      // 페이징 방식으로 에셋 로드 (대체 방식)
      try {
        debugPrint('에셋 로드 시작: 페이징 방식 (대체)');
        final assets = await _recentAlbum!
            .getAssetListPaged(page: _currentPage, size: _pageSize)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('페이징 에셋 로드 타임아웃');
                return [];
              },
            );

        debugPrint('페이징 로드된 에셋 수: ${assets.length}');

        if (assets.isEmpty) {
          debugPrint('에셋이 없음, 빈 목록 반환');
          return [];
        }

        _currentPage++;

        // 에셋으로 PhotoModel 생성
        final List<PhotoModel> photos = [];
        for (final asset in assets) {
          try {
            final isInTrash = _trashBin.containsKey(asset.id);
            final trashDate = _trashBin[asset.id];
            photos.add(
              PhotoModel(
                asset: asset,
                isInTrash: isInTrash,
                trashDate: trashDate,
              ),
            );
          } catch (e) {
            debugPrint('PhotoModel 생성 오류: $e');
            // 개별 오류는 무시하고 계속 진행
          }
        }

        debugPrint('반환할 사진 모델 수 (페이징 방식): ${photos.length}');
        return photos;
      } catch (e) {
        debugPrint('페이징 에셋 로드 오류: $e');
        return [];
      }
    } catch (e) {
      debugPrint('사진 로드 중 일반 오류: $e');
      return [];
    }
  }

  // 추가 사진 로드
  Future<List<PhotoModel>> loadMorePhotos() async {
    debugPrint('loadMorePhotos 호출됨 - 페이지: $_currentPage');

    if (_recentAlbum == null) {
      debugPrint('최근 앨범이 없음, 빈 목록 반환');
      return [];
    }

    try {
      final assets = await _recentAlbum!.getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );
      debugPrint('추가 로드된 에셋 수: ${assets.length}');

      if (assets.isEmpty) {
        debugPrint('더 이상 에셋이 없음');
        return [];
      }

      _currentPage++;

      final List<PhotoModel> photos = [];
      for (final asset in assets) {
        try {
          final isInTrash = _trashBin.containsKey(asset.id);
          final trashDate = _trashBin[asset.id];
          photos.add(
            PhotoModel(
              asset: asset,
              isInTrash: isInTrash,
              trashDate: trashDate,
            ),
          );
        } catch (e) {
          debugPrint('PhotoModel 생성 오류: $e');
          // 개별 오류는 무시하고 계속 진행
        }
      }

      debugPrint('반환할 추가 사진 모델 수: ${photos.length}');
      return photos;
    } catch (e) {
      debugPrint('추가 사진 로드 오류: $e');
      return [];
    }
  }

  // 휴지통으로 이동
  Future<void> moveToTrash(PhotoModel photo) async {
    _trashBin[photo.asset.id] = DateTime.now();
    photo.isInTrash = true;
    photo.trashDate = _trashBin[photo.asset.id];
    await _saveTrashBin();
  }

  // 휴지통에서 복원
  void restoreFromTrash(PhotoModel photo) {
    _trashBin.remove(photo.asset.id);
    photo.isInTrash = false;
    photo.trashDate = null;
    _saveTrashBin();
  }

  // 휴지통 비우기 (모든 사진 영구 삭제)
  Future<void> emptyTrash() async {
    if (_trashBin.isEmpty) return;

    // 모든 사진을 한 번에 삭제하기 위해 ID 목록 생성
    final List<String> assetIds = _trashBin.keys.toList();

    // 일괄 삭제 시도
    try {
      // 먼저 에셋 객체로 변환
      List<AssetEntity> assets = [];
      for (final id in assetIds) {
        try {
          final asset = await AssetEntity.fromId(id);
          if (asset != null) {
            assets.add(asset);
          }
        } catch (e) {
          debugPrint('에셋 로드 오류: $e');
        }
      }

      // 에셋 일괄 삭제
      if (assets.isNotEmpty) {
        final result = await PhotoManager.editor.deleteWithIds(assetIds);
        if (result.isNotEmpty) {
          _trashBin.clear();
          await _saveTrashBin();
          return;
        }
      }

      // 개별 삭제 시도
      for (final asset in assets) {
        try {
          final result = await PhotoManager.editor.deleteWithIds([asset.id]);
          if (result.isNotEmpty) {
            _trashBin.remove(asset.id);
          }
        } catch (e) {
          debugPrint('개별 사진 삭제 오류: $e');
        }
      }

      _trashBin.clear();
      await _saveTrashBin();
    } catch (e) {
      debugPrint('휴지통 비우기 오류: $e');
      _trashBin.clear();
      await _saveTrashBin();
    }
  }

  // 휴지통에서 특정 사진 영구 삭제
  Future<bool> deleteFromTrash(PhotoModel photo) async {
    if (!_trashBin.containsKey(photo.asset.id)) {
      return false;
    }

    try {
      final result = await PhotoManager.editor.deleteWithIds([photo.asset.id]);
      if (result.isNotEmpty) {
        _trashBin.remove(photo.asset.id);
        await _saveTrashBin();
        return true;
      }
    } catch (e) {
      debugPrint('사진 삭제 오류: $e');
    }
    return false;
  }

  // 휴지통 목록 가져오기
  List<PhotoModel> getTrashPhotos() {
    final List<PhotoModel> trashPhotos = [];

    for (final entry in _trashBin.entries) {
      final assetId = entry.key;
      final trashDate = entry.value;

      // 이미 로드된 사진 중에서 찾기
      final asset = _findAssetById(assetId);
      if (asset != null) {
        trashPhotos.add(
          PhotoModel(asset: asset, isInTrash: true, trashDate: trashDate),
        );
      }
    }

    // 날짜 기준으로 정렬 (최근 삭제된 항목이 먼저 표시)
    trashPhotos.sort(
      (a, b) => (b.trashDate ?? DateTime.now()).compareTo(
        a.trashDate ?? DateTime.now(),
      ),
    );

    return trashPhotos;
  }

  // 휴지통 상태 저장
  Future<void> _saveTrashBin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _trashBin.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      );
      await prefs.setString(_trashBinKey, jsonEncode(data));
    } catch (e) {
      debugPrint('휴지통 저장 오류: $e');
    }
  }

  // 휴지통 상태 로드
  Future<void> _loadTrashBin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? trashData = prefs.getString(_trashBinKey);

      if (trashData != null && trashData.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(trashData);

        // 기존 데이터 초기화
        _trashBin.clear();

        // 데이터 복원
        data.forEach((key, value) {
          try {
            _trashBin[key] = DateTime.parse(value);
          } catch (e) {
            debugPrint('날짜 파싱 오류: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('휴지통 로드 오류: $e');
    }
  }

  // ID로 에셋 찾기
  AssetEntity? _findAssetById(String id) {
    // 최근 앨범에서 에셋 찾기
    return AssetEntity(id: id, typeInt: 1, width: 0, height: 0);
  }

  // 중복 사진 스캔
  Future<Map<String, List<PhotoModel>>> findDuplicatePhotos(
    List<PhotoModel> photos, {
    Function(double)? onProgress,
  }) async {
    if (_isDuplicateScanRunning) {
      return _duplicateGroups;
    }

    _isDuplicateScanRunning = true;
    _duplicateGroups.clear();

    // 이미지 해시 맵 (해시 -> 사진 목록)
    final Map<String, List<PhotoModel>> hashMap = {};

    // 이미 계산된 해시 캐시
    final Map<String, String> hashCache = {};

    try {
      // 캐시된 중복 사진 정보 로드
      await _loadDuplicateCache();

      int processedCount = 0;
      final int totalCount = photos.length;

      // 휴지통에 없는 사진만 처리
      final List<PhotoModel> validPhotos = photos
          .where((p) => !p.isInTrash)
          .toList();

      for (final photo in validPhotos) {
        // 진행률 업데이트
        processedCount++;
        final double progress = processedCount / totalCount;
        onProgress?.call(progress);

        // 이미 해시가 계산된 경우 캐시에서 가져옴
        String? hash = hashCache[photo.asset.id];

        if (hash == null) {
          // 썸네일 로드
          final Uint8List? thumbnail = await _loadThumbnail(photo.asset);
          if (thumbnail == null) continue;

          // 이미지 해시 계산
          hash = _calculateImageHash(thumbnail);
          hashCache[photo.asset.id] = hash;
        }

        // 해시 맵에 추가
        if (!hashMap.containsKey(hash)) {
          hashMap[hash] = [];
        }
        hashMap[hash]!.add(photo);
      }

      // 중복된 항목만 필터링 (2개 이상인 경우)
      hashMap.forEach((hash, photoList) {
        if (photoList.length > 1) {
          // 날짜 기준으로 정렬 (최신 사진이 먼저 표시)
          photoList.sort(
            (a, b) => b.asset.createDateTime.compareTo(a.asset.createDateTime),
          );
          _duplicateGroups[hash] = photoList;
        }
      });

      // 중복 사진 정보 캐시에 저장
      await _saveDuplicateCache();

      return _duplicateGroups;
    } catch (e) {
      debugPrint('중복 사진 스캔 오류: $e');
      return {};
    } finally {
      _isDuplicateScanRunning = false;
    }
  }

  // 중복 사진 그룹 가져오기
  Map<String, List<PhotoModel>> getDuplicateGroups() {
    return _duplicateGroups;
  }

  // 중복 사진 정보 저장
  Future<void> _saveDuplicateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 중복 그룹의 에셋 ID만 저장
      final Map<String, List<String>> serializedGroups = {};
      _duplicateGroups.forEach((hash, photos) {
        serializedGroups[hash] = photos.map((p) => p.asset.id).toList();
      });

      await prefs.setString(_duplicatePhotosKey, jsonEncode(serializedGroups));
    } catch (e) {
      debugPrint('중복 사진 캐시 저장 오류: $e');
    }
  }

  // 중복 사진 정보 로드
  Future<void> _loadDuplicateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cacheData = prefs.getString(_duplicatePhotosKey);

      if (cacheData != null && cacheData.isNotEmpty) {
        // 저장된 데이터는 현재 사용하지 않음 (사진이 변경되었을 수 있으므로)
        // 필요한 경우 여기서 캐시 데이터를 파싱하여 사용할 수 있음
      }
    } catch (e) {
      debugPrint('중복 사진 캐시 로드 오류: $e');
    }
  }

  // 이미지 해시 계산 (간단한 perceptual hash)
  String _calculateImageHash(Uint8List imageData) {
    // MD5 해시 사용 (간단한 구현)
    final digest = md5.convert(imageData);
    return digest.toString();
  }

  // 썸네일 로드 (캐싱 포함)
  Future<Uint8List?> _loadThumbnail(AssetEntity asset) async {
    final String cacheKey = asset.id;

    // 캐시에 있으면 캐시에서 반환
    if (_thumbnailCache.containsKey(cacheKey)) {
      return _thumbnailCache[cacheKey];
    }

    try {
      // 썸네일 로드
      final data = await asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
        quality: 80,
      );

      if (data != null) {
        // 캐시에 저장
        _thumbnailCache[cacheKey] = data;
        return data;
      }
    } catch (e) {
      debugPrint('썸네일 로드 오류: $e');
    }

    return null;
  }

  // 선택한 중복 사진 삭제
  Future<void> deleteDuplicatePhotos(List<PhotoModel> photosToDelete) async {
    for (final photo in photosToDelete) {
      await moveToTrash(photo);
    }

    // 중복 그룹 업데이트
    _updateDuplicateGroupsAfterDeletion(photosToDelete);
  }

  // 삭제 후 중복 그룹 업데이트
  void _updateDuplicateGroupsAfterDeletion(List<PhotoModel> deletedPhotos) {
    final Set<String> deletedIds = deletedPhotos.map((p) => p.asset.id).toSet();

    // 각 그룹에서 삭제된 사진 제거
    _duplicateGroups.forEach((hash, photos) {
      photos.removeWhere((photo) => deletedIds.contains(photo.asset.id));
    });

    // 1개 이하로 남은 그룹 제거
    _duplicateGroups.removeWhere((hash, photos) => photos.length <= 1);

    // 캐시 업데이트
    _saveDuplicateCache();
  }
}
