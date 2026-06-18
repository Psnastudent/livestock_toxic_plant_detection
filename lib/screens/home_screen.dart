import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      _HomeContent(staggerController: _staggerController),
      const SearchScreen(),
      const ScanScreen(),
      const SearchScreen(),
      const profile.ProfileScreen(),
    ];

    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;
    final tr = ref.read(translationProvider);
    String t(String key) => tr[key]?[isTamil ? 'tamil' : 'english'] ?? key;

    return Scaffold(
      body: IndexedStack(
        index: _currentNavIndex,
        children: screens,
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, t('home'), 0),
              _navItem(Icons.search_rounded, t('search'), 1),
              _scanButton(),
              _navItem(Icons.menu_book_rounded, t('dictionary'), 3),
              _navItem(Icons.person_rounded, t('profile'), 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = _currentNavIndex == index;
    final activeColor = const Color(0xFF2E7D32);
    final inactiveColor =
        Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4) ??
            Colors.grey;

    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? activeColor : inactiveColor, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scanButton() {
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = 2),
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
}

// ── Home Content ──────────────────────────────────────────────────────────
class _HomeContent extends ConsumerWidget {
  final AnimationController staggerController;
  const _HomeContent({required this.staggerController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              controller: staggerController,
              delay: 0.0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('greeting'),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t('subtitle_label'),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2E7D32),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _LangToggle(ref: ref, isTamil: isTamil),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const profile.ProfileScreen())),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.person_rounded,
                                color: Color(0xFF2E7D32), size: 22),
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
              controller: staggerController,
              delay: 0.1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      t('main_title'),
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        height: 1.1,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SearchScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.search_rounded,
                            color: const Color(0xFF2E7D32), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Category chips ──
          SliverToBoxAdapter(
            child: _Animated(
              controller: staggerController,
              delay: 0.2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 0, 0),
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _Chip(icon: Icons.eco_rounded, label: t('all'), active: true,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
                      _Chip(icon: Icons.warning_amber_rounded, label: t('toxic'), active: false,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
                      _Chip(icon: Icons.check_circle_outline, label: t('safe'), active: false,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
                      _Chip(icon: Icons.document_scanner_rounded, label: t('scan_plant'), active: false,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()))),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Toxic section ──
          SliverToBoxAdapter(
            child: _Animated(
              controller: staggerController,
              delay: 0.3,
              child: _SectionHeader(
                title: '⚠️  ${t('common_toxic_plants')}',
                actionLabel: t('view_all'),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SearchScreen())),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Animated(
              controller: staggerController,
              delay: 0.4,
              child: SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: harmfulPlants.length,
                  itemBuilder: (_, i) => _PlantCard(
                    plant: harmfulPlants[i],
                    isTamil: isTamil,
                    isHarmful: true,
                  ),
                ),
              ),
            ),
          ),

          // ── Safe section ──
          SliverToBoxAdapter(
            child: _Animated(
              controller: staggerController,
              delay: 0.5,
              child: _SectionHeader(
                title: '🌿  ${t('safe_plants')}',
                actionLabel: t('view_all'),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SearchScreen())),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Animated(
              controller: staggerController,
              delay: 0.6,
              child: SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: safePlants.length,
                  itemBuilder: (_, i) => _PlantCard(
                    plant: safePlants[i],
                    isTamil: isTamil,
                    isHarmful: false,
                  ),
                ),
              ),
            ),
          ),

          // ── Scan CTA ──
          SliverToBoxAdapter(
            child: _Animated(
              controller: staggerController,
              delay: 0.7,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ScanScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t('scan_plant'),
                                  style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(t('scan_subtitle'),
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ── Animated wrapper ─────────────────────────────────────────────────────
class _Animated extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;
  const _Animated({required this.controller, required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, min(delay + 0.3, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
            offset: Offset(0, 18 * (1 - anim.value)), child: child),
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title, actionLabel;
  final VoidCallback onTap;
  const _SectionHeader({required this.title, required this.actionLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color)),
          GestureDetector(
            onTap: onTap,
            child: Text(actionLabel,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32))),
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
class _PlantCard extends StatefulWidget {
  final Plant plant;
  final bool isTamil;
  final bool isHarmful;
  const _PlantCard({required this.plant, required this.isTamil, required this.isHarmful});

  @override
  State<_PlantCard> createState() => _PlantCardState();
}

class _PlantCardState extends State<_PlantCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plant;
    final dangerColor = widget.isHarmful ? Colors.red[700]! : const Color(0xFF2E7D32);
    final dangerIcon = widget.isHarmful ? Icons.warning_amber_rounded : Icons.check_circle_rounded;
    final rating = switch (p.susceptibilityLevel) {
      SusceptibilityLevel.low => '1.0',
      SusceptibilityLevel.medium => '2.5',
      SusceptibilityLevel.high => '4.0',
      SusceptibilityLevel.critical => '5.0',
    };

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => PlantDetailsScreen(plant: p, showVetButton: widget.isHarmful)));
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
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
                      tag: 'plant_image_${p.plantId}',
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
                      widget.isTamil ? p.tamilName : p.englishName,
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
