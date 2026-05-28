// core/di/service_locator.dart
// ============================================================================
// STREAMZ — Service Locator
// All services registered as singletons at app startup.
// ============================================================================

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart' show AppLifecycleBroadcaster;
import '../../data/local/media_scanner.dart';
import '../../data/local/progress_store.dart';
import '../../data/local/thumbnail_cache.dart';
import '../../data/network/http_server.dart';
import '../../data/network/udp_discovery.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/server_repository.dart';
import '../../domain/services/download_service.dart';
import '../../domain/services/remote_command_service.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // ── Infrastructure ────────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // ── App lifecycle broadcaster — registered first, used by ServerViewModel ─
  sl.registerSingleton<AppLifecycleBroadcaster>(AppLifecycleBroadcaster());

  // ── Local services ────────────────────────────────────────────────────────
  sl.registerLazySingleton<ProgressStore>(() => ProgressStore(sl<SharedPreferences>()));

  sl.registerLazySingleton<MediaScanner>(() => MediaScanner());

  // ThumbnailCache must be eagerly initialized (requires async directory setup).
  final thumbCache = ThumbnailCache();
  await thumbCache.init();
  sl.registerSingleton<ThumbnailCache>(thumbCache);

  // ── Network services ──────────────────────────────────────────────────────
  sl.registerLazySingleton<HttpServerService>(() => HttpServerService(scanner: sl<MediaScanner>(), thumbCache: sl<ThumbnailCache>()));

  sl.registerLazySingleton<UdpBroadcaster>(() => UdpBroadcaster());
  sl.registerLazySingleton<UdpDiscovery>(() => UdpDiscovery());

  // ── Repositories ──────────────────────────────────────────────────────────
  sl.registerLazySingleton<MediaRepository>(() => MediaRepository(scanner: sl<MediaScanner>(), progress: sl<ProgressStore>()));

  sl.registerLazySingleton<ServerRepository>(() => ServerRepository(sl<SharedPreferences>()));

  // ── Domain services ───────────────────────────────────────────────────────
  sl.registerLazySingleton<DownloadService>(() => DownloadService());
  sl.registerLazySingleton<RemoteCommandService>(() => RemoteCommandService());
}
