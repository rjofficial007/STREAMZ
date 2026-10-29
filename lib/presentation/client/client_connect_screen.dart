// presentation/client/client_connect_screen.dart
// ============================================================================
// STREAMZ — Client Connection Screen
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/core/theme/design_tokens.dart';
import 'package:streamz/presentation/client/client_connect_screen_tv.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_bottom_sheet.dart';
import 'package:streamz/presentation/shared/app_list_tile_card.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';

class ClientConnectScreen extends StatefulWidget {
  const ClientConnectScreen({super.key});

  @override
  State<ClientConnectScreen> createState() => _ClientConnectScreenState();
}

class _ClientConnectScreenState extends State<ClientConnectScreen> {
  final _ctrl = TextEditingController();
  // [SECURITY B1] Optional pairing-code field (manual handshake).
  final _codeCtrl = TextEditingController();
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
    super.dispose();
  }

  Future<void> _connect([String? manualIp, String? pairingToken]) async {
    final ip = (manualIp ?? _ctrl.text).trim();
    if (ip.isEmpty) return;
    // Explicit token (QR/discovery) wins; otherwise fall back to the field.
    final code = (pairingToken ?? _codeCtrl.text).trim();

    FocusScope.of(context).unfocus();
    _clientViewModel.stopDiscovery();

    final ok = await _clientViewModel.connect(
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
    if (DS.isTV(context)) {
      return const ClientConnectScreenTV();
    }

    final vm = context.watch<ClientViewModel>();

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppSliverAppBar(),
            AppContentSliver(sliver: _buildBody(vm)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSliverAppBar() {
    final tokens = context.tokens;
    return AppSliverAppBar(
      floating: true,
      pinned: true,
      titleSpacing: 0,
      leading: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              context.pop();
              return null;
            },
          ),
        },
        child: Focus(
          onKeyEvent: (_, ev) => handleTVSelectKey(ev, () => context.pop()),
          child: AppBackButton(onPressed: () => context.pop()),
        ),
      ),
      title: Text(
        'Connect to a server',
        style: AppTextStyles.titleLarge.copyWith(
          color: tokens.textPrimary,
          fontWeight: AppTextStyles.titleFontWeight,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildBody(ClientViewModel vm) {
    final tokens = context.tokens;
    return SliverList(
      delegate: SliverChildListDelegate([
        _HandshakeAnalysisCard(vm: vm),

        AppActionGrid(
          children: [
            AppActionCard(
              label: 'Scan QR',
              icon: LucideIcons.qrCode,
              onTap: _scanQR,
            ),
            AppActionCard(
              label: 'Manual IP',
              icon: LucideIcons.terminal,
              onTap: _showManualIpSheet,
            ),
            AppActionCard(
              label: vm.isDiscovering ? 'Stop scan' : 'Discover',
              icon: vm.isDiscovering ? LucideIcons.searchX : LucideIcons.search,
              onTap: () =>
                  vm.isDiscovering ? vm.stopDiscovery() : _startDiscovery(),
            ),
          ],
        ),

        if (vm.connectionError != null)
          _ErrorBanner(error: vm.connectionError!),

        // [SECURITY B1] Media may still load over HTTP — the banner explains
        // why live control (WS) is unavailable.
        if (vm.wsAuthError != null) _ErrorBanner(error: vm.wsAuthError!),

        Padding(
          padding: const EdgeInsets.fromLTRB(DS.s16, DS.s24, DS.s16, DS.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent servers',
                style: AppTextStyles.heading(
                  20,
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
            ],
          ),
        ),

        if (vm.ipHistory.isEmpty)
          const _EmptyHistoryPlaceholder()
        else
          ...vm.ipHistory.map(
            (ip) => _HistoryTile(ip: ip, onTap: () => _connect(ip)),
          ),

        const SizedBox(height: 100),
      ]),
    );
  }

  Future<void> _scanQR() async {
    final tokens = context.tokens;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'QR SCAN ONLY AVAILABLE ON MOBILE',
            style: AppTextStyles.style(
              color: tokens.background,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: tokens.textPrimary,
        ),
      );
      return;
    }
    final raw = await context.push<String>('/qr-scanner');
    if (raw == null || !mounted) return;
    // [SECURITY B1] New QRs encode http://<ip>:8080/?token=<code>;
    // legacy QRs are a bare IP (control plane will prompt for the code).
    final uri = Uri.tryParse(raw.trim());
    if (uri != null && uri.host.isNotEmpty) {
      _ctrl.text = uri.host;
      unawaited(_connect(uri.host, uri.queryParameters['token']));
    } else {
      _ctrl.text = raw.trim();
      unawaited(_connect(raw.trim()));
    }
  }

  void _showManualIpSheet() {
    final tokens = context.tokens;
    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSheetHeader(
                title: 'Connect manually',
                subtitle: 'Enter the server address and pairing code.',
                icon: LucideIcons.link,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DS.s24,
                  0,
                  DS.s24,
                  DS.s24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: AppTextStyles.style(color: tokens.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'IP address',
                        prefixIcon: Icon(LucideIcons.network),
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) {
                        ctx.pop();
                        _connect();
                      },
                    ),
                    const SizedBox(height: DS.s12),
                    // Pairing code authenticates the WebSocket control plane.
                    TextField(
                      controller: _codeCtrl,
                      style: AppTextStyles.style(color: tokens.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Pairing code (optional)',
                        prefixIcon: Icon(LucideIcons.keyRound),
                      ),
                      onSubmitted: (_) {
                        ctx.pop();
                        _connect();
                      },
                    ),
                    const SizedBox(height: DS.s20),
                    AppButton(
                      label: 'Initiate connection',
                      icon: LucideIcons.link,
                      onTap: () {
                        ctx.pop();
                        _connect();
                      },
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

class _HandshakeAnalysisCard extends StatelessWidget {
  const _HandshakeAnalysisCard({required this.vm});
  final ClientViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(DS.radius(20)),
        border: Border.all(color: tokens.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Connection status',
                style: AppTextStyles.titleLarge.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: AppTextStyles.titleFontWeight,
                ),
              ),
              _BlinkingDot(isOnline: vm.isDiscovering),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discovery',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vm.isDiscovering ? 'Searching' : 'Paused',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Most recent',
                      style: AppTextStyles.caption.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vm.ipHistory.firstOrNull ?? 'None',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              Container(height: 8, color: tokens.surface2),
              if (vm.isDiscovering) const _DiscoveryProgressBar(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _legend(
                  context,
                  'History',
                  '${vm.ipHistory.length} servers',
                  tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _legend(
                  context,
                  'Network',
                  'Ready',
                  tokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final tokens = context.tokens;
    return Row(
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: tokens.textMuted),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: tokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DiscoveryProgressBar extends StatefulWidget {
  const _DiscoveryProgressBar();

  @override
  State<_DiscoveryProgressBar> createState() => _DiscoveryProgressBarState();
}

class _DiscoveryProgressBarState extends State<_DiscoveryProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => FractionallySizedBox(
        widthFactor: _ctrl.value,
        child: Container(height: 8, color: tokens.accent),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.ip, required this.onTap});
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s8),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(DS.s16),
          child: Row(
            children: [
              Icon(LucideIcons.circleAlert, color: tokens.error, size: 22),
              const SizedBox(width: DS.s12),
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
                      style: AppTextStyles.supporting.copyWith(
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
}

class _EmptyHistoryPlaceholder extends StatelessWidget {
  const _EmptyHistoryPlaceholder();

  @override
  Widget build(BuildContext context) => const AppStateView(
    title: 'No recent servers',
    description: 'Servers you connect to will appear here.',
    icon: LucideIcons.history,
  );
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({required this.isOnline});
  final bool isOnline;

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
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
    if (!widget.isOnline) {
      return Container(width: 8, height: 8, color: tokens.textDisabled);
    }
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: tokens.success,
          boxShadow: [BoxShadow(color: tokens.success, blurRadius: 4)],
        ),
      ),
    );
  }
}
