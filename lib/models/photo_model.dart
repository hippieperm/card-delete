import 'package:photo_manager/photo_manager.dart';

class PhotoModel {
  final AssetEntity asset;
  bool isDeleted;

  PhotoModel({required this.asset, this.isDeleted = false});
}
