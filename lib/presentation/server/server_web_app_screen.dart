import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:streamz/core/constants/app_strings.dart';
import 'package:streamz/core/constants/app_text_styles.dart';
import 'package:streamz/core/theme/app_theme.dart';
import 'package:streamz/presentation/server/server_webview_controller_factory.dart'
    as webview_factory;
import 'package:streamz/presentation/shared/app_back_button.dart';
import 'package:streamz/presentation/shared/app_state_view.dart';
import 'package:webview_all/webview_all.dart';

class ServerWebAppScreen extends StatefulWidget {
  const ServerWebAppScreen({super.key, required this.url});

  final Uri url;

  @override
  State<ServerWebAppScreen> createState() => _ServerWebAppScreenState();
}

class _ServerWebAppScreenState extends State<ServerWebAppScreen> {
  WebViewController? _controller;
  String? _loadError;
  bool _isLoading = true;

  bool get _isBlockedByWebMixedContent =>
      kIsWeb && Uri.base.scheme == 'https' && widget.url.scheme == 'http';

  @override
  void initState() {
    super.initState();
    if (_isBlockedByWebMixedContent) {
      _isLoading = false;
      _loadError =
          'This browser blocks a local HTTP page inside a secure app. '
          'Open ${AppStrings.appTitle} over HTTP or serve the host over HTTPS.';
      return;
    }

    unawaited(_configureWebView());
  }

  Future<void> _configureWebView() async {
    try {
      final controller = await webview_factory.createServerWebViewController();
      if (!mounted) return;
      _controller = controller;

      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (progress == 100 && mounted) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _loadError = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _loadError = null;
            });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) return;
            setState(() {
              _isLoading = false;
              _loadError = error.description;
            });
          },
        ),
      );

      await controller.loadRequest(widget.url);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _reload() async {
    if (_isBlockedByWebMixedContent) return;
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await controller.reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _handleBack() async {
    final controller = _controller;
    if (controller != null) {
      try {
        if (await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
      } catch (_) {
        // Some browser iframe APIs cannot inspect history for a remote origin.
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: AppScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: AppBackButton(onPressed: () => unawaited(_handleBack())),
          title: Text(
            'Web app',
            style: AppTextStyles.style(
              color: tokens.textPrimary,
              fontSize: 20,
              fontWeight: AppTextStyles.titleFontWeight,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Reload web app',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller != null) WebViewWidget(controller: _controller!),
              if (_isLoading && _loadError == null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: tokens.surface2,
                    color: tokens.accent,
                  ),
                ),
              if (_loadError != null)
                ColoredBox(
                  color: tokens.background,
                  child: AppStateView(
                    kind: AppStateKind.error,
                    title: 'Unable to load the web app',
                    description:
                        '$_loadError\nCheck that the server is running and this device can reach it.',
                    icon: Icons.wifi_off_rounded,
                    actionLabel: _isBlockedByWebMixedContent ? null : 'Retry',
                    onAction: _isBlockedByWebMixedContent ? null : _reload,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
