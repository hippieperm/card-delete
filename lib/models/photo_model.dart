import 'package:photo_manager/photo_manager.dart';

class PhotoModel {
  final AssetEntity asset;
  bool isDeleted;
  bool isInTrash;
  DateTime? trashDate;

  PhotoModel({
    required this.asset,
    this.isDeleted = false,
    this.isInTrash = false,
    this.trashDate,
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
}
