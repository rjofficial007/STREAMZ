import 'package:media_kit/media_kit.dart';

import 'package:streamz/core/platform/player_property_stub.dart'
    if (dart.library.io) 'package:streamz/core/platform/player_property_native.dart'
    as platform;

Future<void> setPlayerProperty(Player player, String property, String value) =>
    platform.setPlayerProperty(player, property, value);
