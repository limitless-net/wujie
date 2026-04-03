/// XBoard 模块统一导出
///
/// 这是 XBoard 模块的公共 API 入口
library;

// ========== Core 核心基础层 ==========
export 'core/core.dart';

// ========== Infrastructure 基础设施层 ==========
export 'infrastructure/infrastructure.dart';

// ========== Config 配置模块 ==========
export 'config/xboard_config.dart';

// ========== SDK适配层 ==========
export 'adapter/initialization/sdk_provider.dart';

// 新的状态管理层（推荐使用）
export 'adapter/state/user_state.dart';
export 'adapter/state/subscription_state.dart';
export 'adapter/state/order_state.dart';
export 'adapter/state/plan_state.dart';
export 'adapter/state/notice_state.dart';
export 'adapter/state/ticket_state.dart';
export 'adapter/state/invite_state.dart';
export 'adapter/state/payment_state.dart';
export 'adapter/state/config_state.dart';



// 注意：SubscriptionInfo从SDK层导出，不要从Config层重复导出

// ========== Services 业务服务层 ==========
export 'services/services.dart';

// ========== Features 功能模块 ==========
export 'features/auth/auth.dart';
export 'features/subscription/subscription.dart';
export 'features/payment/payment.dart';
export 'features/invite/invite.dart';
export 'features/profile/profile.dart';

// ========== 系统功能模块 ==========
export 'features/domain_status/domain_status.dart';
export 'features/latency/latency.dart';
export 'features/online_support/online_support.dart';
export 'features/remote_task/remote_task.dart';
export 'features/update_check/update_check.dart';
export 'features/notice/notice.dart';

// ========== 共享组件 ==========
export 'features/shared/shared.dart';
