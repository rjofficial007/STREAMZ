// presentation/client/client_connect_screen_tv.dart
// ============================================================================
// STREAMZ — TV Client Connection Screen (NOC Dashboard - V2)
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';

class ClientConnectScreenTV extends StatefulWidget {
  const ClientConnectScreenTV({super.key});

  @override
  State<ClientConnectScreenTV> createState() => _ClientConnectScreenTVState();
}

class _ClientConnectScreenTVState extends State<ClientConnectScreenTV> {
  final _ctrl = TextEditingController();
  // [SECURITY B1] Optional pairing-code field (manual handshake).
  final _codeCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showManualInput = false;
  late final ClientViewModel _clientViewModel;

  @override
  void initState() {
    super.initState();
    _clientViewModel = context.read<ClientViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startDiscovery();
    });
  }

  void _startDiscovery() {
    _clientViewModel.startDiscovery((ip, token) {
      if (!mounted || _ctrl.text.isNotEmpty) return;
      _ctrl.text = ip;
      unawaited(_connect(ip, token));
    });
  }

  @override
  void dispose() {
    _clientViewModel.stopDiscovery(notify: false);
    _ctrl.dispose();
    _codeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _connect([String? manualIp, String? pairingToken]) async {
    final ip = (manualIp ?? _ctrl.text).trim();
    if (ip.isEmpty) return;
    // Explicit token (QR/discovery) wins; otherwise fall back to the field.
    final code = (pairingToken ?? _codeCtrl.text).trim();

    // Stop discovery before connecting
    context.read<ClientViewModel>().stopDiscovery();

    final ok = await context.read<ClientViewModel>().connect(
      ip,
      pairingToken: code.isEmpty ? null : code,
    );
    if (!mounted) return;

    if (ok) {
      if (mounted) context.pushReplacement('/client/interface');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientViewModel>();
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = (size.width * 0.05).clamp(24.0, 80.0);

    return AppScaffold(
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, vm),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: DS.contentMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: DS.s24),

                            // Integrated Manual IP Input OR Quick Actions
                            if (_showManualInput)
                              _buildIntegratedInput(context)
                            else
                              _buildQuickActions(vm),

                            if (vm.connectionError != null)
                              _buildErrorBanner(context, vm.connectionError!),
                            // [SECURITY B1] WS control plane rejected the pairing
                            // token — media may still load over HTTP.
                            if (vm.wsAuthError != null)
                              _buildErrorBanner(context, vm.wsAuthError!),

                            SizedBox(
                              height: (size.height * 0.05).clamp(24.0, 48.0),
                            ),
                            Text(
                              'Recent servers',
                              style: AppTextStyles.heading(
                                (size.width * 0.016).clamp(20.0, 30.0),
                                spacing: -0.3,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: DS.s4),
                            Text(
                              'Reconnect to a server you used before.',
                              style: AppTextStyles.supporting.copyWith(
                                color: tokens.textMuted,
                              ),
                            ),
                            const SizedBox(height: DS.s16),
                            if (vm.ipHistory.isEmpty)
                              _buildEmptyHistory(context)
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: size.width > 1200 ? 2 : 1,
                                      childAspectRatio: size.width > 1200
                                          ? 4
                                          : 5,
                                      crossAxisSpacing: DS.s24,
                                      mainAxisSpacing: DS.s16,
                                    ),
                                itemCount: vm.ipHistory.length,
                                itemBuilder: (context, index) {
                                  final ip = vm.ipHistory[index];
                                  return _HistoryTileTV(
                                    ip: ip,
                                    onTap: () => _connect(ip),
                                  );
                                },
                              ),
                            const SizedBox(height: DS.s80),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildFooter(context),
              ],
            ),
          ),

          // Loading Overlay
          if (vm.isLoading)
            Positioned.fill(
              child: Container(
                color: tokens.background.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: tokens.accent),
                      const SizedBox(height: 24),
                      Text(
                        'INITIATING HANDSHAKE...',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: tokens.accent,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntegratedInput(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);

    return Container(
      padding: EdgeInsets.all((size.width * 0.025).clamp(16.0, 32.0)),
      decoration: BoxDecoration(
        color: tokens.surface1,
        border: Border.all(color: tokens.accent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MANUAL HANDSHAKE',
            style: AppTextStyles.style(
              color: tokens.textSecondary,
              fontSize: (size.width * 0.009).clamp(10.0, 14.0),
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: (size.height * 0.03).clamp(16.0, 24.0)),
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (v) {
                    if (v) _focusNode.requestFocus();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? tokens.accent
                            : tokens.borderStrong,
                      ),
                      color: tokens.surface2,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      style: AppTextStyles.style(
                        color: tokens.textPrimary,
                        fontSize: (size.width * 0.015).clamp(18.0, 24.0),
                      ),
                      decoration: InputDecoration(
                        hintText: 'ENTER IPv4 ADDRESS...',
                        hintStyle: TextStyle(color: tokens.textMuted),
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _connect(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _DialogBtn(label: 'INITIATE', isPrimary: true, onTap: _connect),
              const SizedBox(width: 16),
              _DialogBtn(
                label: 'CANCEL',
                onTap: () => setState(() => _showManualInput = false),
              ),
            ],
          ),
          SizedBox(height: (size.height * 0.015).clamp(8.0, 14.0)),
          // [SECURITY B1] Optional pairing code for the WS control plane
          // (shown on the server's QR sheet).
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: tokens.borderStrong),
              color: tokens.surface2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _codeCtrl,
              style: AppTextStyles.style(
                color: tokens.textPrimary,
                fontSize: (size.width * 0.012).clamp(14.0, 18.0),
              ),
              decoration: InputDecoration(
                hintText: 'PAIRING CODE (OPTIONAL)...',
                hintStyle: TextStyle(color: tokens.textMuted),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _connect(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ClientViewModel vm) => Row(
    children: [
      Expanded(
        child: _TVConnectCard(
          label: 'MANUAL IP',
          subLabel: 'DIRECT NODE ADDRESSING',
          code: 'TCP-01',
          icon: LucideIcons.terminal,
          onTap: () {
            setState(() => _showManualInput = true);
            _focusNode.requestFocus();
          },
          autofocus: true,
        ),
      ),
      const SizedBox(width: DS.s24),
      Expanded(
        child: _TVConnectCard(
          label: vm.isDiscovering ? 'STOP SCAN' : 'DISCOVER',
          subLabel: 'AUTOMATIC NODE SEARCH',
          code: 'UDP-02',
          icon: vm.isDiscovering ? LucideIcons.searchX : LucideIcons.search,
          onTap: () =>
              vm.isDiscovering ? vm.stopDiscovery() : _startDiscovery(),
        ),
      ),
    ],
  );

  Widget _buildHeader(BuildContext context, ClientViewModel vm) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = (size.width * 0.05).clamp(24.0, 80.0);
    final verticalPad = (size.height * 0.04).clamp(16.0, 40.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLIENT NODE // HANDSHAKE ANALYSIS',
                  style: AppTextStyles.style(
                    color: tokens.textPrimary,
                    fontSize: (size.width * 0.02).clamp(20.0, 32.0),
                    fontWeight: AppTextStyles.titleFontWeight,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: DS.s8),
                Container(
                  height: 2,
                  width: (size.width * 0.1).clamp(100.0, 200.0),
                  color: tokens.accent,
                ),
              ],
            ),
          ),
          _StatusModule(
            label: 'SCAN STATUS',
            value: vm.isDiscovering ? 'ACTIVE' : 'IDLE',
          ),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          _StatusModule(
            label: 'LAST NODE',
            value: vm.ipHistory.firstOrNull ?? 'NONE',
          ),
          SizedBox(width: (size.width * 0.03).clamp(16.0, 48.0)),
          _StatusModule(
            label: 'HISTORY',
            value: '${vm.ipHistory.length} NODES',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final horizontalPad = (size.width * 0.05).clamp(24.0, 80.0);
    final verticalPad = (size.height * 0.04).clamp(16.0, 40.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      child: Row(
        children: [
          Text(
            'PROTOCOL: TCP/UDP // MODE: DISTRIBUTED // AUTH: TOKEN',
            style: AppTextStyles.style(
              color: tokens.textMuted,
              fontSize: (size.width * 0.008).clamp(9.0, 12.0),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          const _BlinkingDotTV(),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String error) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: DS.s16),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(DS.s20),
          child: Row(
            children: [
              Icon(LucideIcons.circleAlert, color: tokens.error, size: 24),
              const SizedBox(width: DS.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection issue',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: DS.s4),
                    Text(
                      error,
                      style: AppTextStyles.body.copyWith(
                        color: tokens.textSecondary,
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

  Widget _buildEmptyHistory(BuildContext context) => const AppStateView(
    title: 'No recent servers',
    description: 'Servers you connect to will appear here.',
    icon: LucideIcons.history,
  );
}

class _StatusModule extends StatelessWidget {
  const _StatusModule({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: tokens.textMuted,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TVConnectCard extends StatefulWidget {
  const _TVConnectCard({
    required this.label,
    required this.subLabel,
    required this.code,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
  });
  final String label;
  final String subLabel;
  final String code;
  final IconData icon;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_TVConnectCard> createState() => _TVConnectCardState();
}

class _TVConnectCardState extends State<_TVConnectCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = _isFocused ? tokens.surface3 : tokens.surface1;
    final borderColor = _isFocused ? tokens.accent : tokens.border;
    final size = MediaQuery.sizeOf(context);

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) {
        setState(() => _isFocused = v);
        if (v) handleTVFocusScroll(v, context);
      },
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: (size.height * 0.3).clamp(180.0, 300.0),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(DS.radius(24)),
              border: Border.all(color: borderColor, width: _isFocused ? 4 : 1),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SYS_TYPE // ${widget.code}',
                    style: AppTextStyles.style(
                      color: _isFocused
                          ? tokens.textPrimary
                          : tokens.textMuted,
                      fontSize: (size.width * 0.008).clamp(9.0, 12.0),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: (size.height * 0.02).clamp(12.0, 24.0)),
                  Icon(
                    widget.icon,
                    color: _isFocused
                        ? tokens.textPrimary
                        : tokens.textSecondary,
                    size: (size.width * 0.035).clamp(32.0, 56.0),
                  ),
                  SizedBox(height: (size.height * 0.02).clamp(12.0, 24.0)),
                  Text(
                    widget.label,
                    style: AppTextStyles.style(
                      color: tokens.textPrimary,
                      fontSize: (size.width * 0.018).clamp(20.0, 32.0),
                      letterSpacing: 0.8,
                      fontWeight: AppTextStyles.titleFontWeight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DS.s4),
                  Text(
                    widget.subLabel,
                    style: AppTextStyles.style(
                      color: _isFocused
                          ? tokens.textPrimary
                          : tokens.textMuted,
                      fontSize: (size.width * 0.008).clamp(9.0, 12.0),
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
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

class _HistoryTileTV extends StatelessWidget {
  const _HistoryTileTV({required this.ip, required this.onTap});
  final String ip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppListTileCard(
    title: ip,
    subtitle: 'Previously connected server',
    icon: LucideIcons.hardDrive,
    onTap: onTap,
  );
}

class _DialogBtn extends StatefulWidget {
  const _DialogBtn({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  State<_DialogBtn> createState() => _DialogBtnState();
}

class _DialogBtnState extends State<_DialogBtn> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bgColor = _isFocused
        ? tokens.accent
        : (widget.isPrimary ? tokens.surface4 : tokens.background);
    final textColor = _isFocused
        ? tokens.background
        : (widget.isPrimary ? tokens.textPrimary : tokens.textSecondary);

    return Focus(
      onFocusChange: (v) => setState(() => _isFocused = v),
      onKeyEvent: (_, ev) => handleTVSelectKey(ev, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: tokens.accent),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.style(
              color: textColor,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingDotTV extends StatefulWidget {
  const _BlinkingDotTV();

  @override
  State<_BlinkingDotTV> createState() => _BlinkingDotTVState();
}

class _BlinkingDotTVState extends State<_BlinkingDotTV>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FadeTransition(
      opacity: _ctrl,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tokens.success,
              boxShadow: [BoxShadow(color: tokens.success, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'SYSTEM SCANNING',
            style: AppTextStyles.caption.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
