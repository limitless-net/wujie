import '../../../core/http/http_service.dart';
import '../../../core/models/api_response.dart';
import '../models/xboard_plan_models.dart';
import '../../../core/exceptions/xboard_exceptions.dart';

/// XBoard 套餐 API 实现
class XBoardPlanApi {
  final HttpService _httpService;

  XBoardPlanApi(this._httpService);

  Future<ApiResponse<List<Plan>>> fetchPlans() async {
    try {
      final result = await _httpService.getRequest('/api/v1/user/plan/fetch');
      return ApiResponse.fromJson(
        result,
        (json) => (json as List<dynamic>)
            .map((e) => Plan.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('获取套餐列表失败: $e');
    }
  }

  /// 游客获取套餐列表（无需登录）
  Future<ApiResponse<List<Plan>>> fetchGuestPlans() async {
    try {
      final result = await _httpService.getRequest('/api/v1/guest/plan/fetch');
      return ApiResponse.fromJson(
        result,
        (json) => (json as List<dynamic>)
            .map((e) => Plan.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      if (e is XBoardException) rethrow;
      throw ApiException('获取游客套餐列表失败: $e');
    }
  }
}
