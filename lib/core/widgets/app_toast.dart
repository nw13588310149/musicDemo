import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final text = message.trim();
    if (text.isEmpty) {
      return;
    }

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }
    final size = MediaQuery.maybeSizeOf(context) ?? const Size(1440, 900);
    final scale = math.min(size.width / 1440, size.height / 900);
    double ui(num value) => value * (scale.isFinite && scale > 0 ? scale : 1);

    _timer?.cancel();
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: ui(72),
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, ui(10) * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: ui(188),
                      maxWidth: ui(420),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui(18),
                        vertical: ui(12),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(ui(14)),
                        border: Border.all(
                          color: const Color(0xFFF0ECFF),
                          width: ui(1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x1F4D2B88),
                            blurRadius: ui(22),
                            offset: Offset(0, ui(10)),
                          ),
                          BoxShadow(
                            color: const Color(0x0F000000),
                            blurRadius: ui(4),
                            offset: Offset(0, ui(1)),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: ui(22),
                            height: ui(22),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFB68EFF), Color(0xFF8741FF)],
                              ),
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: ui(14),
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: ui(10)),
                          Flexible(
                            child: Text(
                              text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF0B081A),
                                fontSize: ui(14),
                                fontFamily: 'PingFang SC',
                                fontWeight: FontWeight.w500,
                                height: 20 / 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
    _timer = Timer(duration, () {
      _entry?.remove();
      _entry = null;
    });
  }
}
