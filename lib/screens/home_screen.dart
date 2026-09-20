import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import '../widgets/themed_background.dart';

import '../models/plant.dart';
import '../data/mock_plants.dart';
import '../providers/language_provider.dart';
import 'search_screen.dart';
import 'scan_screen.dart';
import 'plant_details_screen.dart';
import 'profile_screen.dart' as profile;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentNavIndex = 0;
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeContent(
        staggerController: _staggerController,
        onScanTap: _showCameraOptionsSheet,
        onProfileTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const profile.ProfileScreen())),
        onSearchTap: () => setState(() => _currentNavIndex = 1),
      ),
      const SearchScreen(),
    ];

    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;
    final tr = ref.read(translationProvider);
    String t(String key) => tr[key]?[isTamil ? 'tamil' : 'english'] ?? key;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ThemedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _currentNavIndex,
          children: screens,
        ),
        extendBody: true,
        bottomNavigationBar: RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark 
                  ? const Color(0xFF162319).withValues(alpha: 0.95) 
                  : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark 
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: isDark ? [] : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navItem(Icons.home_rounded, t('home'), 0),
                    _scanButton(),
                    _navItem(Icons.menu_book_rounded, t('dictionary'), 1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = _currentNavIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Increased contrast for visibility on watery background
    final activeColor = isDark ? Colors.white : const Color(0xFF1B5E20); 
    final inactiveColor = isDark 
        ? Colors.white.withValues(alpha: 0.5) 
        : Colors.black.withValues(alpha: 0.5);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentNavIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isActive ? activeColor : inactiveColor, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scanButton() {
    return GestureDetector(
      onTap: _showCameraOptionsSheet,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.document_scanner_rounded,
            color: Colors.white, size: 26),
      ),
    );
  }

  void _showCameraOptionsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1B2A1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Identify Plant',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select an option to scan and identify plant toxicity',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            _sheetOptionTile(
              icon: Icons.camera_alt_rounded,
              title: 'Camera',
              subtitle: 'Open camera to snap a photo',
              onTap: () {
                Navigator.pop(ctx);
                _pickAndScan(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            _sheetOptionTile(
              icon: Icons.photo_library_rounded,
              title: 'Photos / Gallery',
              subtitle: 'Choose photo from gallery',
              onTap: () {
                Navigator.pop(ctx);
                _pickAndScan(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sheetOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanScreen(initialImageFile: imageFile),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }
}

// ── Home Content ──────────────────────────────────────────────────────────
class _HomeContent extends ConsumerStatefulWidget {
  final AnimationController staggerController;
  final VoidCallback onScanTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSearchTap;

  const _HomeContent({
    required this.staggerController,
    required this.onScanTap,
    required this.onProfileTap,
    required this.onSearchTap,
  });

  @override
  ConsumerState<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<_HomeContent> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;
    final tr = ref.read(translationProvider);
    String t(String key) => tr[key]?[isTamil ? 'tamil' : 'english'] ?? key;

    final harmfulPlants = mockPlants.where((p) => p.isHarmful).toList();
    final safePlants = mockPlants.where((p) => !p.isHarmful).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: _Animated(
              controller: widget.staggerController,
              delay: 0.0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('greeting'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t('subtitle_label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF264633),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _LangToggle(ref: ref, isTamil: isTamil),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: widget.onProfileTap,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAEFE8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person_rounded,
                                color: Color(0xFF264633), size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Title ──
          SliverToBoxAdapter(
            child: _Animated(
              controller: widget.staggerController,
              delay: 0.1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        t('main_title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          height: 1.1,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onSearchTap,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAEFE8),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.search_rounded,
                            color: Color(0xFF264633), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Category chips with smooth in-place selection animation ──
          SliverToBoxAdapter(
            child: _Animated(
              controller: widget.staggerController,
              delay: 0.2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 0, 0),
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _Chip(
                        icon: Icons.eco_rounded,
                        label: t('all'),
                        active: _selectedFilter == 'all',
                        onTap: () => setState(() => _selectedFilter = 'all'),
                      ),
                      _Chip(
                        icon: Icons.warning_amber_rounded,
                        label: t('toxic'),
                        active: _selectedFilter == 'harmful',
                        onTap: () => setState(() => _selectedFilter = 'harmful'),
                      ),
                      _Chip(
                        icon: Icons.check_circle_outline,
                        label: t('safe'),
                        active: _selectedFilter == 'harmless',
                        onTap: () => setState(() => _selectedFilter = 'harmless'),
                      ),
                      _Chip(
                        icon: Icons.document_scanner_rounded,
                        label: t('scan_plant'),
                        active: false,
                        onTap: widget.onScanTap,
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Animated Content Sections depending on filter ──
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey<String>(_selectedFilter),
                children: [
                  // Toxic section (shown if 'all' or 'harmful')
                  if (_selectedFilter == 'all' || _selectedFilter == 'harmful') ...[
                    _SectionHeader(
                      title: t('common_toxic_plants'),
                      icon: Icons.warning_amber_rounded,
                      iconColor: Colors.red[700],
                      actionLabel: t('view_all'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(initialFilter: 'harmful'),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 240,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: harmfulPlants.length,
                        addRepaintBoundaries: true,
                        addAutomaticKeepAlives: true,
                        itemBuilder: (_, i) => _PlantCard(
                          plant: harmfulPlants[i],
                          isTamil: isTamil,
                          isHarmful: true,
                        ),
                      ),
                    ),
                  ],

                  // Safe section (shown if 'all' or 'harmless')
                  if (_selectedFilter == 'all' || _selectedFilter == 'harmless') ...[
                    _SectionHeader(
                      title: t('safe_plants'),
                      icon: Icons.check_circle_outline,
                      iconColor: const Color(0xFF264633),
                      actionLabel: t('view_all'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(initialFilter: 'harmless'),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 240,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: safePlants.length,
                        addRepaintBoundaries: true,
                        addAutomaticKeepAlives: true,
                        itemBuilder: (_, i) => _PlantCard(
                          plant: safePlants[i],
                          isTamil: isTamil,
                          isHarmful: false,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── Animated wrapper ─────────────────────────────────────────────────────
// Performance fix: cache the CurvedAnimation in a StatefulWidget to avoid
// creating new CurvedAnimation objects on every rebuild, which causes GC
// pressure and frame drops. Also use RepaintBoundary to isolate repaint regions.
class _Animated extends StatefulWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;
  const _Animated({required this.controller, required this.delay, required this.child});

  @override
  State<_Animated> createState() => _AnimatedState();
}

class _AnimatedState extends State<_Animated> {
  late final CurvedAnimation _anim;

  @override
  void initState() {
    super.initState();
    _anim = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(widget.delay, min(widget.delay + 0.3, 1.0), curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Opacity(
          opacity: _anim.value,
          child: Transform.translate(
              offset: Offset(0, 18 * (1 - _anim.value)), child: child),
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title, actionLabel;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: iconColor ?? const Color(0xFF2E7D32), size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip ──────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2E7D32) : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16,
                  color: active ? Colors.white : const Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: active ? Colors.white : const Color(0xFF2E7D32))),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Language toggle ──────────────────────────────────────────────────────
class _LangToggle extends StatelessWidget {
  final WidgetRef ref;
  final bool isTamil;
  const _LangToggle({required this.ref, required this.isTamil});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _item('EN', !isTamil, () =>
              ref.read(languageProvider.notifier).state = AppLanguage.english),
          _item('TA', isTamil, () =>
              ref.read(languageProvider.notifier).state = AppLanguage.tamil),
        ],
      ),
    );
  }

  Widget _item(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2E7D32) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF2E7D32))),
      ),
    );
  }
}

// ── Plant card ───────────────────────────────────────────────────────────
class _PlantCard extends StatelessWidget {
  final Plant plant;
  final bool isTamil;
  final bool isHarmful;
  const _PlantCard({required this.plant, required this.isTamil, required this.isHarmful});

  @override
  Widget build(BuildContext context) {
    final p = plant;
    final dangerColor = isHarmful ? Colors.red[700]! : const Color(0xFF2E7D32);
    final dangerIcon = isHarmful ? Icons.warning_amber_rounded : Icons.check_circle_rounded;
    final rating = switch (p.susceptibilityLevel) {
      SusceptibilityLevel.low => '1.0',
      SusceptibilityLevel.medium => '2.5',
      SusceptibilityLevel.high => '4.0',
      SusceptibilityLevel.critical => '5.0',
    };

    final heroTag = 'home_plant_${isHarmful ? "harmful" : "safe"}_${p.plantId}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => PlantDetailsScreen(
              plant: p,
              showVetButton: isHarmful,
              heroTag: heroTag,
            ),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 250),
          ),
        );
      },
      child: RepaintBoundary(
        child: Container(
          width: 165,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        child: Image.asset(
                          p.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFE8F5E9),
                            child: Icon(Icons.eco_rounded,
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.3), size: 40),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(dangerIcon, size: 12, color: dangerColor),
                            const SizedBox(width: 3),
                            Text(rating,
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTamil ? p.tamilName : p.englishName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.scientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
