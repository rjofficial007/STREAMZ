// presentation/shared/theme_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/streamz_theme.dart';
import '../../core/theme/theme_service.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final tokens = context.tokens;
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context, isMobile),
            _buildThemeGrid(context, themeService, isMobile),
            _buildSystemSettings(context, themeService, isMobile),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isMobile) {
    final tokens = context.tokens;
    return SliverAppBar(
      backgroundColor: tokens.surface1,
      floating: true,
      elevation: 0,
      pinned: true,
      centerTitle: true,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(LucideIcons.chevronLeft, size: 20, color: tokens.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'APPEARANCE CENTER',
                  style: GoogleFonts.barlowCondensed(color: tokens.textPrimary, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w900, letterSpacing: 4),
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: tokens.border.withValues(alpha: 0.15), height: 1),
      ),
    );
  }

  Widget _buildThemeGrid(BuildContext context, ThemeService themeService, bool isMobile) {
    final tokens = context.tokens;
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'OPERATIONAL IDENTITIES', LucideIcons.palette),
              Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: tokens.border.withValues(alpha: 0.15)),
                    vertical: BorderSide.none,
                  ),
                  color: tokens.border.withValues(alpha: 0.15),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.0, crossAxisSpacing: 1, mainAxisSpacing: 1),
                  itemCount: StreamzTheme.all.length,
                  itemBuilder: (context, index) {
                    final theme = StreamzTheme.all[index];
                    final isSelected = themeService.currentTheme.identity == theme.identity;

                    return _ThemeActionCard(theme: theme, isSelected: isSelected, onTap: () => themeService.setTheme(theme.identity));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: tokens.textMuted, size: 16),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildSystemSettings(BuildContext context, ThemeService themeService, bool isMobile) {
    final tokens = context.tokens;
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'SYSTEM CONFIGURATION', LucideIcons.settings),
              Container(
                decoration: BoxDecoration(
                  color: tokens.surface1,
                  border: Border(bottom: BorderSide(color: tokens.border.withValues(alpha: 0.15))),
                ),
                child: SwitchListTile(
                  activeThumbColor: tokens.accent,
                  activeTrackColor: tokens.accent.withValues(alpha: 0.2),
                  inactiveThumbColor: tokens.textMuted,
                  inactiveTrackColor: tokens.surface2,
                  title: Text(
                    'REDUCED MOTION',
                    style: GoogleFonts.dmMono(color: tokens.textPrimary, fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'DISABLE SCANNING LINES & GLITCH EFFECTS',
                    style: GoogleFonts.dmMono(color: tokens.textMuted, fontSize: 10),
                  ),
                  value: themeService.reducedMotion,
                  onChanged: (val) => themeService.setReducedMotion(val),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeActionCard extends StatefulWidget {
  final StreamzTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeActionCard({required this.theme, required this.isSelected, required this.onTap});

  @override
  State<_ThemeActionCard> createState() => _ThemeActionCardState();
}

class _ThemeActionCardState extends State<_ThemeActionCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final themeTokens = widget.theme.tokens;

    return AppCard(
      onTap: widget.onTap,
      child: Focus(
        onFocusChange: (v) => setState(() => _isFocused = v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(color: _isFocused ? tokens.surface3 : tokens.surface1),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: themeTokens.background,
                        border: Border.all(color: themeTokens.textPrimary, width: 1.5),
                      ),
                      child: Center(child: Icon(LucideIcons.shield, size: 20, color: themeTokens.textPrimary)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.theme.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlowCondensed(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1, color: tokens.textPrimary),
                    ),

                  ],
                ),
              ),
              if (widget.isSelected) Positioned(top: 0, right: 0, child: Icon(LucideIcons.check, color: tokens.success, size: 16)),
              if (_isFocused)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: tokens.accent, width: 2)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
