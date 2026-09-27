import 'dart:ui';
import 'package:flutter/material.dart';

/// Apple Liquid Glass Design System tokens & glassmorphic building blocks.
class LiquidGlassTheme {
  LiquidGlassTheme._();

  // Glass Tint Colors (Dark Mode)
  static const Color darkGlassBg = Color(0x1F2A2D3A);
  static const Color darkGlassBorder = Color(0x33FFFFFF);
  static const Color darkGlassShadow = Color(0x40000000);

  // Glass Tint Colors (Light Mode)
  static const Color lightGlassBg = Color(0x75FFFFFF);
  static const Color lightGlassBorder = Color(0x8AFFFFFF);
  static const Color lightGlassShadow = Color(0x14000000);

  // Accent Colors
  static const Color accentAmber = Color(0xFFFFD13B);
  static const Color accentBlue = Color(0xFF3897F0);
  static const Color accentPurple = Color(0xFF9E00FF);
  static const Color accentCyan = Color(0xFF00E5FF);

  /// Builds a frosted glass box decoration or crisp eye-friendly blended decoration based on `isLiquidGlass`.
  static BoxDecoration glassDecoration({
    required BuildContext context,
    required bool isLiquidGlass,
    double radius = 22.0,
    Color? customColor,
    Border? customBorder,
    List<BoxShadow>? customShadows,
    Gradient? customGradient,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isLiquidGlass) {
      // Eye-friendly blended modern fallback (harmonious slate/graphite palette)
      return BoxDecoration(
        color: customColor,
        borderRadius: BorderRadius.circular(radius),
        gradient: customGradient ??
            (customColor == null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF1A212E),
                            Color(0xFF131822),
                          ]
                        : const [
                            Color(0xFFFFFFFF),
                            Color(0xFFF8FAFC),
                          ],
                  )
                : null),
        border: customBorder ??
            Border.all(
              color: isDark ? const Color(0xFF2A3447) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
        boxShadow: customShadows ??
            [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
      );
    }

    // Apple Liquid Glass Active (Screenshot 4 aesthetic with specular highlight)
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: customGradient ??
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0x38FFFFFF),
                    Color(0x14FFFFFF),
                  ]
                : const [
                    Color(0xC8FFFFFF),
                    Color(0x8AFFFFFF),
                  ],
          ),
      border: customBorder ??
          Border.all(
            color: isDark ? const Color(0x4DFFFFFF) : const Color(0xB3FFFFFF),
            width: 1.2,
          ),
      boxShadow: customShadows ??
          [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.40) : Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 10),
            ),
          ],
    );
  }

  /// Specialized modal bottom sheet decoration (Liquid Glass or eye-friendly slate blend)
  static BoxDecoration modalSheetDecoration({
    required BuildContext context,
    required bool isLiquidGlass,
    double radius = 28.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isLiquidGlass) {
      return BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF161B26),
                  Color(0xFF0F131C),
                ]
              : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFF1F5F9),
                ],
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2B3548) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      );
    }

    // Frosted Apple Liquid Glass Sheet (Matching Screenshot 4 aesthetic)
    return BoxDecoration(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xE8161A26),
          Color(0xF50E1119),
        ],
      ),
      border: const Border(
        top: BorderSide(
          color: Color(0x66FFFFFF),
          width: 1.5,
        ),
      ),
      boxShadow: const [
        BoxShadow(
          color: Colors.black54,
          blurRadius: 35,
          offset: Offset(0, -8),
        ),
      ],
    );
  }

  /// Eye-friendly field fill color and border for text fields & dropdowns
  static InputDecoration fieldDecoration({
    required BuildContext context,
    required bool isLiquidGlass,
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fillColor = isLiquidGlass
        ? const Color(0x1FFFFFFF)
        : (isDark ? const Color(0xFF1B2230) : const Color(0xFFF1F5F9));

    final borderColor = isLiquidGlass
        ? const Color(0x33FFFFFF)
        : (isDark ? const Color(0xFF2B3548) : const Color(0xFFCBD5E1));

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(
        color: isLiquidGlass ? Colors.white70 : (isDark ? Colors.white70 : const Color(0xFF475569)),
        fontSize: 13,
      ),
      hintStyle: TextStyle(
        color: isLiquidGlass ? Colors.white38 : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
        fontSize: 13,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: accentAmber, width: 1.8),
      ),
    );
  }
}

/// Reusable Apple Liquid Glass Surface Container
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final bool isLiquidGlass;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;
  final double blurSigma;

  const LiquidGlassCard({
    super.key,
    required this.child,
    required this.isLiquidGlass,
    this.radius = 22.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.onTap,
    this.color,
    this.border,
    this.blurSigma = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = LiquidGlassTheme.glassDecoration(
      context: context,
      isLiquidGlass: isLiquidGlass,
      radius: radius,
      customColor: color,
      customBorder: border,
    );

    Widget content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (isLiquidGlass) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}

/// Dynamic ambient gradient background with glowing orbs when Liquid Glass is on.
class LiquidGlassBackground extends StatelessWidget {
  final Widget child;
  final bool isLiquidGlass;

  const LiquidGlassBackground({
    super.key,
    required this.child,
    required this.isLiquidGlass,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isLiquidGlass) {
      return Container(
        color: isDark ? const Color(0xFF121214) : const Color(0xFFF6F8FB),
        child: child,
      );
    }

    return Stack(
      children: [
        // Base Ambient Gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF0F1016),
                        Color(0xFF141520),
                        Color(0xFF10111A),
                      ]
                    : const [
                        Color(0xFFE8F1FC),
                        Color(0xFFF3F0FC),
                        Color(0xFFE7F6FE),
                      ],
              ),
            ),
          ),
        ),

        // Glowing Ambient Orb 1 (Top Right)
        Positioned(
          top: -80,
          right: -80,
          width: 320,
          height: 320,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF2B1F4A).withValues(alpha: 0.45)
                  : const Color(0xFF90CAFF).withValues(alpha: 0.55),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // Glowing Ambient Orb 2 (Center Left)
        Positioned(
          top: 280,
          left: -100,
          width: 280,
          height: 280,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF132B40).withValues(alpha: 0.5)
                  : const Color(0xFFE1BEE7).withValues(alpha: 0.55),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // Glowing Ambient Orb 3 (Bottom Right)
        Positioned(
          bottom: -60,
          right: 30,
          width: 300,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF382914).withValues(alpha: 0.4)
                  : const Color(0xFFFFE082).withValues(alpha: 0.5),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // Foreground Content
        child,
      ],
    );
  }
}
