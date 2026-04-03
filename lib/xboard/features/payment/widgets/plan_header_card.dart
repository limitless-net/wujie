import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/xboard/domain/domain.dart';
import '../utils/price_calculator.dart';

/// 套餐信息头部卡片
class PlanHeaderCard extends StatelessWidget {
  final DomainPlan plan;

  const PlanHeaderCard({
    super.key,
    required this.plan,
  });

  String _getTrafficDisplay(BuildContext context) {
    if (plan.transferQuota == 0) {
      return AppLocalizations.of(context).xboardUnlimited;
    }
    return PriceCalculator.formatTraffic(plan.transferQuota.toDouble());
  }

  String _getSpeedLimitDisplay(BuildContext context) {
    if (plan.speedLimit == null) {
      return AppLocalizations.of(context).xboardUnlimited;
    }
    return '${plan.speedLimit}Mbps';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左边：大图标（占两行高度）
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          // 右边：上下两行
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 第一行：套餐名字（稍大，居中）
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // 第二行：流量 + 速率（居中）
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCompactInfo(
                      Icons.cloud_download_outlined,
                      _getTrafficDisplay(context),
                    ),
                    const SizedBox(width: 10),
                    _buildCompactInfo(
                      Icons.speed,
                      _getSpeedLimitDisplay(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

