import 'package:flutter/material.dart';

class ThemedBackground extends StatelessWidget {
  final Widget child;

  const ThemedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0C1710), Color(0xFF16321F), Color(0xFF0F2015)]
              : const [Color(0xFFF0F5F1), Color(0xFFE8F5E9), Color(0xFFF3F7F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Aurora effect 1
          Positioned(
            top: -200,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF388E3C).withValues(alpha: 0.25),
                          const Color(0xFF388E3C).withValues(alpha: 0.0),
                        ]
                      : [
                          const Color(0xFF81C784).withValues(alpha: 0.4),
                          const Color(0xFF81C784).withValues(alpha: 0.0),
                        ],
                ),
              ),
            ),
          ),
          // Aurora effect 2
          Positioned(
            bottom: -200,
            right: -150,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF4CAF50).withValues(alpha: 0.15),
                          const Color(0xFF4CAF50).withValues(alpha: 0.0),
                        ]
                      : [
                          const Color(0xFFA5D6A7).withValues(alpha: 0.3),
                          const Color(0xFFA5D6A7).withValues(alpha: 0.0),
                        ],
                ),
              ),
            ),
          ),
          // Content
          child,
        ],
      ),
    );
  }
}
