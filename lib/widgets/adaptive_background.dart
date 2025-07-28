import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'dart:typed_data';
import '../models/photo_model.dart';

/// 현재 표시되는 사진의 색상에 맞춰 그라데이션 배경을 생성하는 위젯
class AdaptiveBackground extends StatefulWidget {
  final Widget child;
  final PhotoModel? photo;
  final Uint8List? imageData;
  final bool enabled;
  final Duration transitionDuration;
  final Curve transitionCurve;

  const AdaptiveBackground({
    Key? key,
    required this.child,
    this.photo,
    this.imageData,
    this.enabled = true,
    this.transitionDuration = const Duration(milliseconds: 800),
    this.transitionCurve = Curves.easeInOut,
  }) : super(key: key);

  @override
  State<AdaptiveBackground> createState() => _AdaptiveBackgroundState();
}

class _AdaptiveBackgroundState extends State<AdaptiveBackground> {
  Color _primaryColor = Colors.black;
  Color _secondaryColor = Colors.black;
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _updateColors();
  }

  @override
  void didUpdateWidget(AdaptiveBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photo != oldWidget.photo ||
        widget.imageData != oldWidget.imageData) {
      _updateColors();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 이미지에서 색상 추출
  void _updateColors() {
    if (!widget.enabled) return;
    if (widget.photo == null && widget.imageData == null) return;

    // 디바운싱 - 빠른 이미지 변경 시 성능 최적화
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
      });

      try {
        PaletteGenerator? paletteGenerator;

        if (widget.imageData != null) {
          // 이미지 데이터로부터 팔레트 생성
          paletteGenerator = await PaletteGenerator.fromImageProvider(
            MemoryImage(widget.imageData!),
            maximumColorCount: 8,
            size: const Size(200, 200), // 성능을 위해 작은 크기로 분석
          );
        } else if (widget.photo != null) {
          // 썸네일 로드 시도
          final thumbnailData = await widget.photo!.asset.thumbnailData;
          if (thumbnailData != null) {
            paletteGenerator = await PaletteGenerator.fromImageProvider(
              MemoryImage(thumbnailData),
              maximumColorCount: 8,
              size: const Size(200, 200),
            );
          }
        }

        if (paletteGenerator != null && mounted) {
          // 주요 색상 추출
          final dominantColor =
              paletteGenerator.dominantColor?.color ?? Colors.black;
          final vibrantColor = paletteGenerator.vibrantColor?.color;
          final darkVibrantColor = paletteGenerator.darkVibrantColor?.color;
          final lightVibrantColor = paletteGenerator.lightVibrantColor?.color;

          // 색상 선택 로직 (다양한 옵션 중에서 가장 적합한 색상 조합 선택)
          Color primary = dominantColor;
          Color secondary = darkVibrantColor ?? dominantColor.withOpacity(0.7);

          // 색상이 너무 밝거나 어두운 경우 조정
          if (primary.computeLuminance() > 0.7) {
            primary = HSLColor.fromColor(primary).withLightness(0.6).toColor();
          } else if (primary.computeLuminance() < 0.1) {
            primary = HSLColor.fromColor(primary).withLightness(0.2).toColor();
          }

          if (secondary.computeLuminance() > 0.7) {
            secondary = HSLColor.fromColor(
              secondary,
            ).withLightness(0.5).toColor();
          } else if (secondary.computeLuminance() < 0.1) {
            secondary = HSLColor.fromColor(
              secondary,
            ).withLightness(0.15).toColor();
          }

          setState(() {
            _primaryColor = primary;
            _secondaryColor = secondary;
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 위젯이 비활성화된 경우 기본 배경 사용
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedContainer(
      duration: widget.transitionDuration,
      curve: widget.transitionCurve,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            _primaryColor.withOpacity(0.8),
            _secondaryColor.withOpacity(0.3),
            colorScheme.background.withOpacity(0.95),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: widget.child,
    );
  }
}
