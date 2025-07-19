import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/photo_model.dart';

class PhotoService {
  // 사진 권한 요청
  Future<bool> requestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      return true;
    } else {
      await Permission.photos.request();
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      return ps.isAuth;
    }
  }

  // 모든 사진 가져오기
  Future<List<PhotoModel>> loadPhotos() async {
    final bool hasPermission = await requestPermission();
    if (!hasPermission) {
      return [];
    }

    // 모든 앨범 가져오기
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );

    if (albums.isEmpty) {
      return [];
    }

    // 최근 사진 앨범 선택
    final AssetPathEntity recentAlbum = albums.first;

    // 앨범에서 사진 가져오기
    final List<AssetEntity> assets = await recentAlbum.getAssetListRange(
      start: 0,
      end: 1000, // 최대 1000개 사진 로드
    );

    // 사진 모델로 변환
    return assets.map((asset) => PhotoModel(asset: asset)).toList();
  }

  // 사진 삭제
  Future<bool> deletePhoto(AssetEntity asset) async {
    try {
      // iOS와 Android에서 사진 삭제 방식이 다름
      if (Platform.isIOS) {
        // iOS에서는 photo_manager의 deleteWithIds 사용
        final result = await PhotoManager.editor.deleteWithIds([asset.id]);
        return result.isNotEmpty;
      } else {
        // Android에서는 직접 파일 삭제
        final File? file = await asset.file;
        if (file != null) {
          await file.delete();
          return true;
        }
        return false;
      }
    } catch (e) {
      print('사진 삭제 중 오류 발생: $e');
      return false;
    }
  }
}
