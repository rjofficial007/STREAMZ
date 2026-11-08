// core/di/service_locator.dart
// ============================================================================
// STREAMZ — Service Locator
// All services registered as singletons at app startup.
// ============================================================================

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamz/core/theme/theme_service.dart';
import 'package:streamz/core/util/lifecycle_broadcaster.dart';
import 'package:streamz/data/local/media_scanner.dart';
import 'package:streamz/data/local/progress_store.dart';
import 'package:streamz/data/local/thumbnail_cache.dart';
import 'package:streamz/data/network/http_server.dart';
import 'package:streamz/data/network/udp_discovery.dart';
import 'package:streamz/data/repositories/media_repository.dart';
import 'package:streamz/data/repositories/server_repository.dart';
import 'package:streamz/domain/services/device_id_service.dart';
import 'package:streamz/domain/services/download_service.dart';
import 'package:streamz/domain/services/media_service.dart';
import 'package:streamz/domain/services/network_service.dart';
import 'package:streamz/domain/services/platform_service.dart';
import 'package:streamz/domain/services/queue_service.dart';
import 'package:streamz/domain/services/remote_command_service.dart';
import 'package:streamz/domain/services/server_lifecycle_service.dart';
import 'package:streamz/domain/services/station_service.dart';
import 'package:streamz/domain/services/video_thumbnail_service.dart';
import 'package:streamz/presentation/client/client_viewmodel.dart';
import 'package:streamz/presentation/server/server_viewmodel.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ── Infrastructure ────────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerSingleton<ThemeService>(ThemeService(prefs))

    // ── App lifecycle broadcaster — registered first, used by ServerViewModel ─
    ..registerSingleton<AppLifecycleBroadcaster>(AppLifecycleBroadcaster())

    // ── Local services ────────────────────────────────────────────────────────
    ..registerLazySingleton<ProgressStore>(() => ProgressStore(sl<SharedPreferences>()))
    ..registerLazySingleton<MediaScanner>(MediaScanner.new);

  // ThumbnailCache must be eagerly initialized (requires async directory setup).
  final thumbCache = ThumbnailCache();
  await thumbCache.init();
  sl
    ..registerSingleton<ThumbnailCache>(thumbCache)
    ..registerLazySingleton<VideoThumbnailService>(VideoThumbnailService.new)

    // ── Network services ──────────────────────────────────────────────────────
    ..registerLazySingleton<PlatformService>(PlatformService.new)
    ..registerLazySingleton<NetworkService>(NetworkService.new)
    ..registerLazySingleton<ServerLifecycleService>(
      () => ServerLifecycleService(networkService: sl<NetworkService>()),
    )
    ..registerLazySingleton<HttpServerService>(
      () => HttpServerService(
        scanner: sl<MediaScanner>(),
        thumbCache: sl<ThumbnailCache>(),
        thumbGenerator: sl<VideoThumbnailService>(),
        stationService: sl<StationService>(),
        queueService: sl<QueueService>(),
        serverRepository: sl<ServerRepository>(),
      ),
    )
    ..registerLazySingleton<UdpBroadcaster>(UdpBroadcaster.new)
    ..registerLazySingleton<UdpDiscovery>(UdpDiscovery.new)

    // ── Repositories ──────────────────────────────────────────────────────────
    ..registerLazySingleton<MediaRepository>(
      () => MediaRepository(
        scanner: sl<MediaScanner>(),
        progress: sl<ProgressStore>(),
        preferences: sl<SharedPreferences>(),
        deviceId: sl<DeviceIdService>(),
      ),
    )
    ..registerLazySingleton<ServerRepository>(() => ServerRepository(sl<SharedPreferences>()))

    // ── Domain services ───────────────────────────────────────────────────────
    ..registerLazySingleton<DeviceIdService>(() => DeviceIdService(sl<SharedPreferences>()))
    ..registerLazySingleton<DownloadService>(DownloadService.new)
    ..registerLazySingleton<RemoteCommandService>(
      () => RemoteCommandService(clientId: sl<DeviceIdService>().id),
    )
    ..registerLazySingleton<StationService>(StationService.new)
    ..registerLazySingleton<QueueService>(QueueService.new)
    ..registerLazySingleton<MediaService>(() => MediaService(repo: sl<MediaRepository>()))

    // ── ViewModels ────────────────────────────────────────────────────────────
    ..registerLazySingleton<ServerViewModel>(ServerViewModel.new)
    ..registerLazySingleton<ClientViewModel>(ClientViewModel.new);
}
