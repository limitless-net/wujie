import 'package:fl_clash/xboard/core/core.dart';
import 'package:fl_clash/xboard/domain/models/models.dart';

/// 套餐仓储接口
abstract class PlanRepository {
  /// 获取套餐列表
  Future<Result<List<DomainPlan>>> getPlans();

  /// 根据 ID 获取套餐详情
  Future<Result<DomainPlan>> getPlanById(int id);
}
