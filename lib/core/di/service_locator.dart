// core/di/service_locator.dart
// ============================================================================
// STREAMZ — Service Locator
// All services registered as singletons at app startup.
// ============================================================================

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/lifecycle_broadcaster.dart';
import '../../data/local/media_scanner.dart';
import '../../data/local/progress_store.dart';
import '../../data/local/thumbnail_cache.dart';
import '../../data/network/http_server.dart';
import '../../data/network/udp_discovery.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/server_repository.dart';
import '../../domain/services/device_id_service.dart';
import '../../domain/services/download_service.dart';
import '../../domain/services/media_service.dart';
import '../../domain/services/network_service.dart';
import '../../domain/services/remote_command_service.dart';
import '../../domain/services/station_service.dart';
import '../../domain/services/queue_service.dart';
import '../../domain/services/server_lifecycle_service.dart';
import '../../domain/services/video_thumbnail_service.dart';
import '../../presentation/server/server_viewmodel.dart';
import '../../presentation/client/client_viewmodel.dart';
import '../theme/theme_service.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ── Infrastructure ────────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  sl.registerSingleton<ThemeService>(ThemeService(prefs));

  // ── App lifecycle broadcaster — registered first, used by ServerViewModel ─
  sl.registerSingleton<AppLifecycleBroadcaster>(AppLifecycleBroadcaster());

  // ── Local services ────────────────────────────────────────────────────────
  sl.registerLazySingleton<ProgressStore>(() => ProgressStore(sl<SharedPreferences>()));

  sl.registerLazySingleton<MediaScanner>(() => MediaScanner());

  // ThumbnailCache must be eagerly initialized (requires async directory setup).
  final thumbCache = ThumbnailCache();
  await thumbCache.init();
  sl.registerSingleton<ThumbnailCache>(thumbCache);

  sl.registerLazySingleton<VideoThumbnailService>(() => VideoThumbnailService());

  // ── Network services ──────────────────────────────────────────────────────
  sl.registerLazySingleton<NetworkService>(() => NetworkService());
  sl.registerLazySingleton<ServerLifecycleService>(() => ServerLifecycleService());

  sl.registerLazySingleton<HttpServerService>(() => HttpServerService(scanner: sl<MediaScanner>(), thumbCache: sl<ThumbnailCache>(), thumbGenerator: sl<VideoThumbnailService>()));

  sl.registerLazySingleton<UdpBroadcaster>(() => UdpBroadcaster());
  sl.registerLazySingleton<UdpDiscovery>(() => UdpDiscovery());

  // ── Repositories ──────────────────────────────────────────────────────────
  sl.registerLazySingleton<MediaRepository>(() => MediaRepository(scanner: sl<MediaScanner>(), progress: sl<ProgressStore>()));

  sl.registerLazySingleton<ServerRepository>(() => ServerRepository(sl<SharedPreferences>()));

  // ── Domain services ───────────────────────────────────────────────────────
  sl.registerLazySingleton<DeviceIdService>(() => DeviceIdService(sl<SharedPreferences>()));
  sl.registerLazySingleton<DownloadService>(() => DownloadService());
  sl.registerLazySingleton<RemoteCommandService>(() => RemoteCommandService());
  sl.registerLazySingleton<StationService>(() => StationService());
  sl.registerLazySingleton<QueueService>(() => QueueService());
  sl.registerLazySingleton<MediaService>(() => MediaService(repo: sl<MediaRepository>()));

  // ── ViewModels ────────────────────────────────────────────────────────────
  sl.registerLazySingleton<ServerViewModel>(() => ServerViewModel());
  sl.registerLazySingleton<ClientViewModel>(() => ClientViewModel());
}
