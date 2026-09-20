import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/mock_plants.dart';
import '../models/plant.dart';
import '../providers/language_provider.dart';
import 'plant_details_screen.dart';

import '../widgets/themed_background.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialFilter;
  const SearchScreen({super.key, this.initialFilter});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _searchQuery = '';
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'all';
  }

  List<Plant> get _filteredPlants {
    return mockPlants.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchesQuery = p.englishName.toLowerCase().contains(q) ||
          p.tamilName.toLowerCase().contains(q) ||
          p.scientificName.toLowerCase().contains(q);
      if (!matchesQuery) return false;
      if (_selectedFilter == 'all') return true;
      if (_selectedFilter == 'harmful') return p.isHarmful;
      if (_selectedFilter == 'harmless') return !p.isHarmful;
      if (_selectedFilter == 'eatable') return p.isEatable;
      if (_selectedFilter == 'not_eatable') return !p.isEatable;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final plants = _filteredPlants;
    final lang = ref.watch(languageProvider);
    final isTamil = lang == AppLanguage.tamil;
    final tr = ref.read(translationProvider);
    String t(String key) => tr[key]?[isTamil ? 'tamil' : 'english'] ?? key;
    final canPop = Navigator.canPop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filters = [
      {'key': 'all', 'label': t('all'), 'icon': Icons.eco_rounded},
      {'key': 'harmful', 'label': t('harmful'), 'icon': Icons.warning_amber_rounded},
      {'key': 'harmless', 'label': t('harmless'), 'icon': Icons.check_circle_outline},
      {'key': 'eatable', 'label': t('eatable'), 'icon': Icons.restaurant_rounded},
      {'key': 'not_eatable', 'label': t('not_eatable'), 'icon': Icons.block_rounded},
    ];

    return ThemedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
                child: Row(
                  children: [
                    if (canPop)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    Expanded(
                      child: Text(
                        t('plant_dictionary'),
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: GlassCard(
                  borderRadius: 18,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: t('search_by_name'),
                      hintStyle: GoogleFonts.outfit(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2E7D32)),
                      filled: false,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),

              // Filters
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 0, 4),
                child: SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: filters.map((f) {
                      final selected = _selectedFilter == f['key'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFilter = f['key'] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF2E7D32)
                                  : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE8F5E9)),
                              borderRadius: BorderRadius.circular(22),
                              border: selected
                                  ? null
                                  : Border.all(
                                      color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
                                    ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  f['icon'] as IconData,
                                  size: 14,
                                  color: selected
                                      ? Colors.white
                                      : (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  f['label'] as String,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : const Color(0xFF2E7D32)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Count
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${plants.length} ${t('plants_found')}',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ),

          // Grid
          Expanded(
            child: plants.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48,
                            color: Theme.of(context).dividerColor),
                        const SizedBox(height: 12),
                        Text(t('no_plants_found'),
                            style: GoogleFonts.outfit(
                                color: Theme.of(context).textTheme.bodyMedium?.color)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                    physics: const BouncingScrollPhysics(),
                    addRepaintBoundaries: true,
                    addAutomaticKeepAlives: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: plants.length,
                    itemBuilder: (_, i) => _GridCard(
                        plant: plants[i], isTamil: isTamil, t: t),
                  ),
          ),
        ],
      ),
    ),
  ),
);
}
}

class _GridCard extends StatelessWidget {
  final Plant plant;
  final bool isTamil;
  final String Function(String) t;
  const _GridCard({required this.plant, required this.isTamil, required this.t});

  @override
  Widget build(BuildContext context) {
    final p = plant;
    final dangerColor = p.isHarmful ? Colors.red[700]! : const Color(0xFF2E7D32);
    final dangerText = p.isHarmful ? t('toxic') : t('safe');

    final heroTag = 'search_grid_plant_${p.plantId}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => PlantDetailsScreen(
              plant: p,
              showVetButton: p.isHarmful,
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
        child: GlassCard(
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.asset(
                          p.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFE8F5E9),
                            child: Icon(Icons.eco_rounded,
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.3), size: 32),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: dangerColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(dangerText,
                            style: GoogleFonts.outfit(
                                fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isTamil ? p.tamilName : p.englishName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: Theme.of(context).textTheme.bodyLarge?.color)),
                      const SizedBox(height: 2),
                      Text(p.scientificName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                              fontSize: 10, fontStyle: FontStyle.italic,
                              color: Theme.of(context).textTheme.bodyMedium?.color)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (p.isEatable ? Colors.green : Colors.grey).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.isEatable ? t('edible') : t('not_fodder'),
                          style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: p.isEatable ? Colors.green[700] : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
