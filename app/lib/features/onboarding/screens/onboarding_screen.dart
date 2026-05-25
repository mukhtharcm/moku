import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../library/cubit/library_cubit.dart';
import '../../../app_shell.dart';
import '../../../core/ui/ui.dart';

const _kOnboardingCompleted = 'onboarding_completed';

Future<bool> isOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingCompleted) ?? false;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding({bool importBook = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleted, true);

    if (!mounted) return;

    // Navigate to main app
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );

    // Trigger import after navigation if requested
    if (importBook) {
      // Small delay to let the app shell mount
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) return;
        // The library cubit will be available in the new context
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Page content
            PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              physics: const ClampingScrollPhysics(),
              children: [
                _WelcomePage(onNext: () => _goToPage(1)),
                _ImportPage(
                  onNext: () => _goToPage(2),
                  onImport: () async {
                    final cubit = context.read<LibraryCubit>();
                    await cubit.importBook();
                    if (mounted) _goToPage(2);
                  },
                ),
                _SyncPage(onFinish: () => _completeOnboarding()),
              ],
            ),

            // Page indicator + skip
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Skip button
                      if (_currentPage < 2)
                        TextButton(
                          onPressed: () => _completeOnboarding(),
                          child: Text(
                            l10n.onboardingSkip,
                            style: TextStyle(
                              color: colors.textSecondary.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 72),

                      const Spacer(),

                      // Page dots
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final isActive = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? colors.accent
                                  : colors.textPrimary.withValues(
                                      alpha: 0.15,
                                    ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),

                      const Spacer(),

                      // Spacer for balance
                      const SizedBox(width: 72),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 1: Welcome ─────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // App icon representation — bookmark shape
            _BookmarkIcon(size: 120, color: MokuTheme.warmAccent),
            const SizedBox(height: 32),

            // Title
            Text(
              l10n.onboardingWelcomeTitle,
              style: GoogleFonts.literata(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              l10n.onboardingWelcomeSubtitle,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: colors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.onboardingWelcomeBody,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: colors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(flex: 2),

            // Get Started button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  l10n.onboardingGetStarted,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ─── Page 2: Import ──────────────────────────────────────────────────────────

class _ImportPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onImport;
  const _ImportPage({required this.onNext, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Illustration — stack of books
            _BooksStackIcon(size: 120, color: colors.accent),
            const SizedBox(height: 32),

            Text(
              l10n.onboardingImportTitle,
              style: GoogleFonts.literata(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Text(
              l10n.onboardingImportBody,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: colors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(flex: 2),

            // Import button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.add_rounded, size: 22),
                label: Text(
                  l10n.commonImportFiles,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Skip / do it later
            TextButton(
              onPressed: onNext,
              child: Text(
                l10n.onboardingImportLater,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colors.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }
}

// ─── Page 3: Sync ────────────────────────────────────────────────────────────

class _SyncPage extends StatelessWidget {
  final VoidCallback onFinish;
  const _SyncPage({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Sync icon
            _SyncIcon(size: 120, color: colors.accent),
            const SizedBox(height: 32),

            Text(
              l10n.onboardingSyncTitle,
              style: GoogleFonts.literata(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            Text(
              l10n.onboardingSyncOfflineBody,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.onboardingSyncServerBody,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(flex: 2),

            // Start reading button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.auto_stories_rounded, size: 22),
                label: Text(
                  l10n.onboardingStartReading,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ─── Custom painted icons ────────────────────────────────────────────────────

class _BookmarkIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _BookmarkIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.3,
      child: CustomPaint(painter: _BookmarkPainter(color: color)),
    );
  }
}

class _BookmarkPainter extends CustomPainter {
  final Color color;
  _BookmarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadow = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final w = size.width * 0.6;
    final h = size.height * 0.85;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2;
    final notch = h * 0.15;

    final path = Path()
      ..moveTo(left, top)
      ..lineTo(left + w, top)
      ..lineTo(left + w, top + h)
      ..lineTo(left + w / 2, top + h - notch)
      ..lineTo(left, top + h)
      ..close();

    // Shadow
    canvas.drawPath(path.shift(const Offset(2, 4)), shadow);
    // Bookmark shape
    canvas.drawPath(path, paint);

    // Subtle inner highlight
    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(left, top, w, h));
    canvas.drawPath(path, highlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BooksStackIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _BooksStackIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.2,
      height: size,
      child: CustomPaint(painter: _BooksStackPainter(color: color)),
    );
  }
}

class _BooksStackPainter extends CustomPainter {
  final Color color;
  _BooksStackPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Three stacked book shapes, slightly rotated
    final books = [
      (angle: -0.12, offset: const Offset(-6, 4), shade: 0.3),
      (angle: 0.08, offset: const Offset(4, 2), shade: 0.15),
      (angle: 0.0, offset: Offset.zero, shade: 0.0),
    ];

    for (final book in books) {
      canvas.save();
      canvas.translate(cx + book.offset.dx, cy + book.offset.dy);
      canvas.rotate(book.angle);

      final bw = size.width * 0.45;
      final bh = size.height * 0.7;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: bw, height: bh),
        const Radius.circular(6),
      );

      // Shadow
      final shadow = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(rect.shift(const Offset(2, 3)), shadow);

      // Book
      final bookColor = Color.lerp(color, Colors.white, book.shade) ?? color;
      canvas.drawRRect(rect, Paint()..color = bookColor);

      // Spine line
      canvas.drawLine(
        Offset(-bw / 2 + bw * 0.15, -bh / 2 + 8),
        Offset(-bw / 2 + bw * 0.15, bh / 2 - 8),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = 2,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SyncIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _SyncIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.sync_rounded,
      size: size * 0.8,
      color: color.withValues(alpha: 0.8),
    );
  }
}
