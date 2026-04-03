import 'package:fl_clash/xboard/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/update_check_state.dart';
import '../services/update_service.dart';

// 初始化文件级日志器
final _logger = FileLogger('update_check_provider.dart');

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
final updateCheckProvider =
    StateNotifierProvider<UpdateCheckNotifier, UpdateCheckState>((ref) {
  final updateService = ref.watch(updateServiceProvider);
  return UpdateCheckNotifier(updateService: updateService);
});
class UpdateCheckNotifier extends StateNotifier<UpdateCheckState> {
  final UpdateService _updateService;
  UpdateCheckNotifier({
    required UpdateService updateService,
  })  : _updateService = updateService,
        super(const UpdateCheckState());
  Future<void> initialize() async {
    _logger.info('开始检查更新');
    await checkForUpdates();
  }
  Future<void> refresh() async {
    _logger.info('刷新检查更新');
    await checkForUpdates();
  }
  Future<void> checkForUpdates() async {
    if (!mounted) return;
    state = state.copyWith(
      isChecking: true,
      error: null,
    );
    try {
      final currentVersion = await _updateService.getCurrentVersion();
      _logger.info('当前版本: $currentVersion');
      state = state.copyWith(currentVersion: currentVersion);
      final updateInfo = await _updateService.checkForUpdates();
      if (!mounted) return;
      state = state.copyWith(
        isChecking: false,
        hasUpdate: updateInfo["hasUpdate"] as bool? ?? false,
        latestVersion: updateInfo["latestVersion"]?.toString(),
        updateUrl: updateInfo["updateUrl"]?.toString(),
        releaseNotes: updateInfo["releaseNotes"]?.toString(),
        forceUpdate: updateInfo["forceUpdate"] as bool? ?? false,
      );
      if (state.hasUpdate) {
        _logger.info('发现新版本: ${state.latestVersion}');
        if (state.releaseNotes != null && state.releaseNotes!.isNotEmpty) {
          // _logger.debug('发布说明: ${state.releaseNotes}');
        }
      } else {
        _logger.info('已是最新版本');
      }
    } catch (e) {
      if (!mounted) return;
      _logger.error('检查更新失败', e);
      state = state.copyWith(
        isChecking: false,
        error: e.toString(),
      );
    }
  }
}