import 'package:flutter/material.dart';

/// Material3 디자인 기반의 애니메이션이 적용된 커스텀 다이얼로그
class CustomDialog extends StatefulWidget {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final Color? confirmColor;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final VoidCallback? onConfirm;
  final bool isDestructive;

  const CustomDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = '취소',
    this.confirmText = '확인',
    this.confirmColor,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.onConfirm,
    this.isDestructive = false,
  });

  /// 다이얼로그를 표시하는 정적 메서드
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    Color? confirmColor,
    IconData? icon,
    Color? iconColor,
    Color? iconBackgroundColor,
    bool isDestructive = false,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '다이얼로그 닫기',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CustomDialog(
          title: title,
          message: message,
          cancelText: cancelText,
          confirmText: confirmText,
          confirmColor: confirmColor,
          icon: icon,
          iconColor: iconColor,
          iconBackgroundColor: iconBackgroundColor,
          onConfirm: () => Navigator.of(context).pop(true),
          isDestructive: isDestructive,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // 애니메이션 효과
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: Tween<double>(
              begin: 0.5,
              end: 1.0,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CustomDialog> createState() => _CustomDialogState();
}

class _CustomDialogState extends State<CustomDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconRotateAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _iconScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _iconRotateAnimation = Tween<double>(
      begin: -0.25,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 아이콘 색상 설정
    final Color actualIconColor =
        widget.iconColor ??
        (widget.isDestructive ? colorScheme.error : colorScheme.primary);

    // 아이콘 배경색 설정
    final Color actualIconBackgroundColor =
        widget.iconBackgroundColor ??
        (widget.isDestructive
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer);

    // 확인 버튼 색상 설정
    final Color actualConfirmColor =
        widget.confirmColor ??
        (widget.isDestructive ? colorScheme.error : colorScheme.primary);

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘 표시 (있는 경우)
            if (widget.icon != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _iconRotateAnimation.value * 3.14159 * 2,
                      child: Transform.scale(
                        scale: _iconScaleAnimation.value,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: actualIconBackgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            size: 36,
                            color: actualIconColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 제목
            Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: widget.icon != null ? 16 : 24,
              ),
              child: Text(
                widget.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // 메시지
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Text(
                widget.message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // 버튼 영역
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 취소 버튼
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(false),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: colorScheme.outlineVariant.withOpacity(
                                0.5,
                              ),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          widget.cancelText,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                  // 확인 버튼
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (widget.onConfirm != null) {
                          widget.onConfirm!();
                        } else {
                          Navigator.of(context).pop(true);
                        }
                      },
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(28),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: colorScheme.outlineVariant.withOpacity(
                                0.5,
                              ),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          widget.confirmText,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: actualConfirmColor,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
