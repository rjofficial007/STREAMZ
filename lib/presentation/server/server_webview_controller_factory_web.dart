import 'package:webview_all/webview_all.dart';
import 'package:webview_all_web/webview_all_web.dart';

Future<WebViewController> createServerWebViewController() async =>
    WebViewController.fromPlatformCreationParams(
      WebWebViewControllerCreationParams(
        iFrameAllow: 'autoplay; fullscreen; picture-in-picture',
        iFrameAttributes: const {'allowfullscreen': ''},
      ),
    );
