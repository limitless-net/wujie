import 'package:flutter/material.dart';

import 'ticket_chat_dialog.dart';

/// 右下角悬浮客服按钮
class FloatingServiceButton extends StatefulWidget {
  const FloatingServiceButton({super.key});

  @override
  State<FloatingServiceButton> createState() => _FloatingServiceButtonState();
}

class _FloatingServiceButtonState extends State<FloatingServiceButton>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final Animation<double> _breathAnim;
  late final AnimationController _hoverController;
  late final Animation<double> _hoverScale;
  late final Animation<double> _hoverElevation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.0, end: 4.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hoverScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
    _hoverElevation = Tween<double>(begin: 4.0, end: 10.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool hovering) {
    if (hovering == _isHovered) return;
    setState(() => _isHovered = hovering);
    if (hovering) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  void _openChat() {
    TicketChatDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = colorScheme.primary;

    return Tooltip(
      message: '在线客服',
      preferBelow: true,
      verticalOffset: 30,
      child: MouseRegion(
        onEnter: (_) => _onHoverChanged(true),
        onExit: (_) => _onHoverChanged(false),
        cursor: SystemMouseCursors.click,
        child: AnimatedBuilder(
          animation: Listenable.merge([_breathAnim, _hoverController]),
          builder: (context, child) {
            return Transform.scale(
              scale: _hoverScale.value,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    // 呼吸灯光晕
                    BoxShadow(
                      color: primary.withValues(
                        alpha: 0.25 + (_breathAnim.value / 4) * 0.2,
                      ),
                      blurRadius: 12 + _breathAnim.value * 2,
                      spreadRadius: 2 + _breathAnim.value,
                    ),
                    // 悬浮增强光晕
                    if (_hoverController.value > 0)
                      BoxShadow(
                        color: primary.withValues(
                          alpha: 0.2 * _hoverController.value,
                        ),
                        blurRadius: 16 + _hoverElevation.value,
                        spreadRadius: 3 * _hoverController.value,
                      ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: _openChat,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: const Alignment(-0.3, -0.9),
                  end: const Alignment(0.3, 1.0),
                  colors: [
                    Color.lerp(primary, Colors.white, isDark ? 0.28 : 0.22)!,
                    Color.lerp(primary, Colors.black, isDark ? 0.03 : 0.03)!,
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.30),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.headset_mic,
                size: 22,
                color: Colors.white.withValues(alpha: 0.92),
                shadows: [
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.30),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
