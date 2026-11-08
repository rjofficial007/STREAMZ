import 'package:webview_all/webview_all.dart';
import 'package:webview_all_android/webview_all_android.dart';

Future<WebViewController> createServerWebViewController() async {
  final controller = WebViewController();
  final platformController = controller.platform;
  if (platformController is AndroidWebViewController) {
    await platformController.setMediaPlaybackRequiresUserGesture(false);
  }
  return controller;
}
