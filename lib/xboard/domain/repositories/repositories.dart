/// 领域层：Repository 接口统一导出
/// 
/// 这些接口定义了数据访问的契约
/// 具体实现由基础设施层提供（XBoard、V2Board等）

export 'user_repository.dart';
export 'auth_repository.dart';
export 'plan_repository.dart';
export 'subscription_repository.dart';
export 'order_repository.dart';
export 'payment_repository.dart';
export 'invite_repository.dart';
export 'notice_repository.dart';
export 'ticket_repository.dart';
