import 'dart:ui';
import 'package:flutter/material.dart';

/// Apple Liquid Glass Design System tokens & glassmorphic building blocks.
/// Implements 3 distinct aesthetic styles:
/// 1. Light Mode (Off): Milk white background blended with mixed light colorful sky blue (Screenshot 1).
/// 2. Dark Mode (Off): Electric midnight navy with glowing cosmic royal blue aura (Screenshot 2).
/// 3. Liquid Glass (On): Apple iOS 18 / VisionOS 3D Liquid Glass with strong backdrop blur,
///    specular highlight sheen, beveled 3D borders, and zero readability interference (Screenshot 3).
class LiquidGlassTheme {
  LiquidGlassTheme._();

  // --- Pure Liquid Glass Core Tokens (Matching exact CSS specifications) ---
  /// --lg-bg-color: rgba(255, 255, 255, 0.25);
  static const Color lgBgColor = Color(0x40FFFFFF);
  static const Color lgBgColorDark = Color(0x28FFFFFF);

  /// --lg-highlight: rgba(255, 255, 255, 0.75);
  static const Color lgHighlight = Color(0xBFFFFFFF);

  /// --lg-text: #ffffff;
  static const Color lgText = Color(0xFFFFFFFF);

  /// --lg-red: #fb4268; (Active accent color)
  static const Color lgRed = Color(0xFFFB4268);

  /// --lg-grey: #444739; (Muted inactive navigation color)
  static const Color lgGrey = Color(0xFF444739);

  /// Active pill background: rgba(0, 0, 0, 0.25);
  static const Color lgActivePillBg = Color(0x40000000);

  // Glass Tint Tokens (Liquid Glass Mode - Screenshot 3)
  static const Color darkGlassBgTop = Color(0x35FFFFFF);
  static const Color darkGlassBgBottom = Color(0x0EFFFFFF);
  static const Color darkGlassBorder = Color(0x55FFFFFF);
  static const Color darkGlassShadow = Color(0x59000000);

  static const Color lightGlassBgTop = Color(0x75FFFFFF);
  static const Color lightGlassBgBottom = Color(0x28FFFFFF);
  static const Color lightGlassBorder = Color(0x99FFFFFF);
  static const Color lightGlassShadow = Color(0x18000000);

  // Screenshot 1 Palette Tokens (Milk White + Light Colorful Blue)
  static const Color milkWhiteBg = Color(0xFFFFFFFF);
  static const Color milkWhiteSurface = Color(0xFFFFFFFF);
  static const Color milkWhiteSurfaceSubtle = Color(0xFFF8FAFD);
  static const Color lightSkyBlueTint = Color(0xFFD6E8FB);
  static const Color lightSkyBlueAccent = Color(0xFF2563EB);
  static const Color lightBorder = Color(0xFFE2ECF6);

  // Screenshot 2 Palette Tokens (Electric Midnight Navy + Glowing Royal Blue)
  static const Color midnightNavyBgTop = Color(0xFF03061A);
  static const Color midnightNavyBgBottom = Color(0xFF070E36);
  static const Color midnightNavyCard = Color(0xFF0C1338);
  static const Color midnightNavyCardSecondary = Color(0xFF080D28);
  static const Color electricBlue = Color(0xFF38BDF8);
  static const Color royalIndigo = Color(0xFF2563EB);
  static const Color midnightBorder = Color(0xFF1D2B66);

  // Accent Colors
  static const Color accentAmber = Color(0xFFFFD13B);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentElectricBlue = Color(0xFF38BDF8);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentCoral = Color(0xFFFB4268);

  /// Signature Liquid Glass outer drop shadows:
  /// box-shadow: 0 6px 6px rgba(0, 0, 0, 0.2), 0 0 20px rgba(0, 0, 0, 0.1);
  static List<BoxShadow> glassShadows([bool isDark = false]) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.20),
          blurRadius: 6,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.10),
          blurRadius: 20,
          offset: Offset.zero,
        ),
      ];

  /// Builds a frosted 3D glass box decoration or milk-white / electric-navy decoration based on mode.
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
      if (!isDark) {
        // Screenshot 1 Style: Milk white card with soft light blue border & subtle shadow
        return BoxDecoration(
          color: customColor ?? milkWhiteSurface,
          borderRadius: BorderRadius.circular(radius),
          gradient: customGradient ??
              (customColor == null
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFF9FBFE),
                      ],
                    )
                  : null),
          border: customBorder ??
              Border.all(
                color: lightBorder,
                width: 1.0,
              ),
          boxShadow: customShadows ??
              [
                BoxShadow(
                  color: const Color(0xFF0F2B5C).withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
        );
      }

      // Screenshot 2 Style: Electric midnight navy card with glowing indigo border & deep shadow
      return BoxDecoration(
        color: customColor,
        borderRadius: BorderRadius.circular(radius),
        gradient: customGradient ??
            (customColor == null
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0C1338),
                      Color(0xFF080D28),
                    ],
                  )
                : null),
        border: customBorder ??
            Border.all(
              color: midnightBorder,
              width: 1.0,
            ),
        boxShadow: customShadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xFF1D3DF0).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
      );
    }

    // Pure Liquid Glass Style: Exact translucent overlay + specular highlight + double shadow
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: customColor ?? (isDark ? lgBgColorDark : lgBgColor),
      border: customBorder ??
          Border.all(
            color: lgHighlight.withValues(alpha: isDark ? 0.45 : 0.65),
            width: 1.2,
          ),
      boxShadow: customShadows ?? glassShadows(isDark),
    );
  }

  /// Specialized modal bottom sheet decoration matching the 3 styles
  static BoxDecoration modalSheetDecoration({
    required BuildContext context,
    required bool isLiquidGlass,
    double radius = 28.0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isLiquidGlass) {
      if (!isDark) {
        // Screenshot 1 Style: Milk white modal sheet
        return BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF7FAFD),
            ],
          ),
          border: const Border(
            top: BorderSide(
              color: lightBorder,
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2B5C).withValues(alpha: 0.10),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
        );
      }

      // Screenshot 2 Style: Electric midnight navy modal sheet
      return BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0E1640),
            Color(0xFF070B24),
          ],
        ),
        border: const Border(
          top: BorderSide(
            color: midnightBorder,
            width: 1.5,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 32,
            offset: Offset(0, -6),
          ),
        ],
      );
    }

    // Screenshot 3 Style: Apple 3D Liquid Glass frosted bottom sheet
    return BoxDecoration(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [
                Color(0xCC111827),
                Color(0xEE090D18),
              ]
            : const [
                Color(0xDDFFFFFF),
                Color(0xEEF3F7FC),
              ],
      ),
      border: Border(
        top: BorderSide(
          color: isDark ? const Color(0x66FFFFFF) : const Color(0xB3FFFFFF),
          width: 1.5,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.18),
          blurRadius: 36,
          offset: const Offset(0, -8),
        ),
      ],
    );
  }

  /// Field fill color and border for text fields & dropdowns
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
        ? (isDark ? const Color(0x18FFFFFF) : const Color(0x35FFFFFF))
        : (isDark ? const Color(0xFF0F173D) : const Color(0xFFF1F6FB));

    final borderColor = isLiquidGlass
        ? (isDark ? const Color(0x40FFFFFF) : const Color(0x80FFFFFF))
        : (isDark ? const Color(0xFF1D2B66) : const Color(0xFFD6E3F0));

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(
        color: isLiquidGlass
            ? (isDark ? Colors.white70 : const Color(0xFF334155))
            : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF475569)),
        fontSize: 13,
      ),
      hintStyle: TextStyle(
        color: isLiquidGlass
            ? (isDark ? Colors.white38 : const Color(0xFF94A3B8))
            : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
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
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
          width: 1.8,
        ),
      ),
    );
  }
}

/// Renders the specular highlight layer:
/// box-shadow: inset 1px 1px 0 var(--lg-highlight), inset 0 0 5px var(--lg-highlight);
class LiquidGlassSpecularPainter extends CustomPainter {
  final double radius;
  final Color highlightColor;

  const LiquidGlassSpecularPainter({
    required this.radius,
    this.highlightColor = LiquidGlassTheme.lgHighlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 1. Inset 1px 1px top-left specular highlight rim
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.35, 0.70, 1.0],
        colors: [
          highlightColor, // 75% white specular shine
          highlightColor.withValues(alpha: 0.55),
          highlightColor.withValues(alpha: 0.15),
          highlightColor.withValues(alpha: 0.30),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect.deflate(0.6), borderPaint);

    // 2. Inset 0 0 5px soft inner glow
    final innerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          highlightColor.withValues(alpha: 0.35),
          highlightColor.withValues(alpha: 0.08),
        ],
      ).createShader(rect);

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect.deflate(1.75), innerGlowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LiquidGlassSpecularPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.highlightColor != highlightColor;
}

/// Reusable Liquid Glass Surface Container implementing the 4-layer architecture:
/// 1. .glass-filter   (BackdropFilter blur)
/// 2. .glass-overlay  (rgba(255, 255, 255, 0.25))
/// 3. .glass-specular (box-shadow: inset 1px 1px 0 var(--lg-highlight), inset 0 0 5px var(--lg-highlight))
/// 4. .glass-content  (child)
/// Outer container: box-shadow: 0 6px 6px rgba(0, 0, 0, 0.2), 0 0 20px rgba(0, 0, 0, 0.1);
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
    this.radius = 24.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.onTap,
    this.color,
    this.border,
    this.blurSigma = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;

    if (isLiquidGlass) {
      content = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: LiquidGlassTheme.glassShadows(isDark),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              // Layer 1: .glass-filter (BackdropFilter blur)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                  child: const SizedBox.expand(),
                ),
              ),
              // Layer 2: .glass-overlay (background: var(--lg-bg-color))
              Positioned.fill(
                child: Container(
                  color: color ??
                      (isDark
                          ? LiquidGlassTheme.lgBgColorDark
                          : LiquidGlassTheme.lgBgColor),
                ),
              ),
              // Layer 3: .glass-specular (inset 1px 1px 0 + inset 0 0 5px highlight)
              Positioned.fill(
                child: CustomPaint(
                  painter: LiquidGlassSpecularPainter(
                    radius: radius,
                    highlightColor: LiquidGlassTheme.lgHighlight,
                  ),
                ),
              ),
              // Layer 4: .glass-content
              Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ],
          ),
        ),
      );
    } else {
      final decoration = LiquidGlassTheme.glassDecoration(
        context: context,
        isLiquidGlass: false,
        radius: radius,
        customColor: color,
        customBorder: border,
      );

      content = Container(
        padding: padding,
        decoration: decoration,
        child: child,
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

/// Dynamic ambient gradient background implementing:
/// 1. Light Mode (Liquid Glass OFF - Screenshot 1):
///    Milk white background blended with mixed light colorful blue according to window structure.
/// 2. Dark Mode (Liquid Glass OFF - Screenshot 2):
///    Deep electric midnight navy background with glowing royal blue atmospheric aura.
/// 3. Liquid Glass (ON - Screenshot 3):
///    Apple 3D Liquid Glass aesthetic with authentic atmospheric depth under the glass,
///    allowing BackdropFilter to render realistic optical refraction with zero interference for text and buttons.
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
      if (!isDark) {
        // Screenshot 1 Style: Eye-friendly soothing pastel sky-blue canvas blended with milk white
        return Stack(
          children: [
            // Structural top-to-bottom soothing sky-blue atmospheric gradient
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.35, 0.70, 1.0],
                    colors: [
                      Color(0xFFB8D8F8), // Rich soothing sky blue at top (like Screenshot 1)
                      Color(0xFFCDE5FB), // Gentle calming celestial blue
                      Color(0xFFDFEEFD), // Soft eye-friendly powder blue
                      Color(0xFFEBF4FD), // Comfortable pastel ice-milk tone at base (NEVER blinding white!)
                    ],
                  ),
                ),
              ),
            ),

            // Soft atmospheric colorful light blue glow near upper right / header
            Positioned(
              top: -60,
              right: -50,
              width: 300,
              height: 300,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF90C8FC).withValues(alpha: 0.60),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // Soft cyan-blue ambient glow at upper left
            Positioned(
              top: 100,
              left: -80,
              width: 260,
              height: 260,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFA8D8FD).withValues(alpha: 0.45),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // Content
            child,
          ],
        );
      }

      // Screenshot 2 Style: Electric midnight navy background with glowing royal blue aura
      return Stack(
        children: [
          // Base Electric Midnight Navy Gradient
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.35, 0.70, 1.0],
                  colors: [
                    Color(0xFF03061A), // Deepest midnight navy
                    Color(0xFF060D33), // Electric indigo tone
                    Color(0xFF0A1448), // Royal midnight blue
                    Color(0xFF04071E), // Cosmic finish
                  ],
                ),
              ),
            ),
          ),

          // Central Glowing Royal Blue Ambient Aura (Matching circular battery/orb meter in Screenshot 2)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            height: 280,
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1D3DF0).withValues(alpha: 0.32),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 85, sigmaY: 85),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),

          // Lower electric blue ambient glow
          Positioned(
            bottom: -40,
            right: -30,
            width: 260,
            height: 260,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF18296B).withValues(alpha: 0.28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // Content
          child,
        ],
      );
    }

    // Screenshot 3 Style: Apple 3D Liquid Glass with dynamic atmospheric lighting under the glass
    return Stack(
      children: [
        // Base Ambient Gradient Layer
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF090B14),
                        Color(0xFF111422),
                        Color(0xFF0B0D18),
                      ]
                    : const [
                        Color(0xFFDCEAF8),
                        Color(0xFFEDE9F8),
                        Color(0xFFDFEFFD),
                      ],
              ),
            ),
          ),
        ),

        // Glowing Ambient Orb 1 (Top Right - Radiant Coral/Red glow matching --lg-red: #fb4268)
        Positioned(
          top: -40,
          right: -40,
          width: 320,
          height: 320,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? LiquidGlassTheme.lgRed.withValues(alpha: 0.45) // Vivid coral-red glow (#fb4268)
                  : const Color(0xFF60A5FA).withValues(alpha: 0.55),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // Glowing Ambient Orb 2 (Center Left - Radiant Cyan/Turquoise glow like ss1 reference)
        Positioned(
          top: 240,
          left: -80,
          width: 300,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF06B6D4).withValues(alpha: 0.45) // Vivid turquoise/cyan glow
                  : const Color(0xFFA78BFA).withValues(alpha: 0.50),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // Glowing Ambient Orb 3 (Bottom Right - Radiant Indigo glow)
        Positioned(
          bottom: -30,
          right: 20,
          width: 300,
          height: 300,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF6366F1).withValues(alpha: 0.40) // Vivid indigo glow
                  : const Color(0xFF38BDF8).withValues(alpha: 0.45),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 85, sigmaY: 85),
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
