import 'package:media_kit/media_kit.dart';

Future<void> setPlayerProperty(
  Player player,
  String property,
  String value,
) async {
  final platform = player.platform;
  if (platform is NativePlayer) {
    await platform.setProperty(property, value);
  }
}
