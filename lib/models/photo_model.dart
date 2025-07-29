import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';

class PhotoModel {
  final AssetEntity asset;
  bool isDeleted;
  bool isInTrash;
  DateTime? trashDate;
  int? fileSize; // 파일 크기 (바이트)

  PhotoModel({
    required this.asset,
    this.isDeleted = false,
    this.isInTrash = false,
    this.trashDate,
    this.fileSize,
  });

  // 휴지통으로 이동
  void moveToTrash() {
    isInTrash = true;
    trashDate = DateTime.now();
  }

  // 휴지통에서 복원
  void restoreFromTrash() {
    isInTrash = false;
    trashDate = null;
  }

  // 파일 크기 로드
  Future<void> loadFileSize() async {
    try {
      final file = await asset.file;
      if (file != null) {
        fileSize = await file.length();
      }
    } catch (e) {
      debugPrint('파일 크기 로드 오류: $e');
    }
  }
}
