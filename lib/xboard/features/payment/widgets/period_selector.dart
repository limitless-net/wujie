import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import '../utils/price_calculator.dart';

/// 周期选择器
class PeriodSelector extends StatelessWidget {
  final List<Map<String, dynamic>> periods;
  final String? selectedPeriod;
  final Function(String) onPeriodSelected;
  final int? couponType;
  final int? couponValue;

  const PeriodSelector({
    super.key,
    required this.periods,
    required this.selectedPeriod,
    required this.onPeriodSelected,
    this.couponType,
    this.couponValue,
  });

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            AppLocalizations.of(context).xboardSelectPaymentPeriod,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        if (periods.length <= 2)
          _buildRowLayout(context)
        else
          _buildGridLayout(context),
      ],
    );
  }

  Widget _buildRowLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseWidth = 800.0; // 统一基准宽度
    final scaleFactor = (screenWidth / baseWidth).clamp(0.8, 1.5);
    final horizontalPadding = (3 * scaleFactor).clamp(2.0, 6.0);
    
    return Row(
      children: periods.map((period) {
        final isSelected = selectedPeriod == period['period'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: _PeriodCard(
              period: period,
              isSelected: isSelected,
              onTap: () => onPeriodSelected(period['period']),
              couponType: couponType,
              couponValue: couponValue,
              scaleFactor: scaleFactor,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseWidth = 800.0; // 统一基准宽度
    final scaleFactor = (screenWidth / baseWidth).clamp(0.8, 1.5);
    
    // 根据屏幕宽度动态调整列数
    final crossAxisCount = screenWidth > 600 ? 3 : 2;
    
    // 根据屏幕大小动态调整间距
    final spacing = (6 * scaleFactor).clamp(4.0, 12.0);
    
    // 根据屏幕大小动态调整宽高比
    final aspectRatio = (3.0 * scaleFactor).clamp(2.5, 3.5);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: periods.length,
      itemBuilder: (context, index) {
        final period = periods[index];
        final isSelected = selectedPeriod == period['period'];
        return _PeriodCard(
          period: period,
          isSelected: isSelected,
          onTap: () => onPeriodSelected(period['period']),
          couponType: couponType,
          couponValue: couponValue,
          scaleFactor: scaleFactor,
        );
      },
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final Map<String, dynamic> period;
  final bool isSelected;
  final VoidCallback onTap;
  final int? couponType;
  final int? couponValue;
  final double scaleFactor;

  const _PeriodCard({
    required this.period,
    required this.isSelected,
    required this.onTap,
    this.couponType,
    this.couponValue,
    this.scaleFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final periodPrice = period['price']?.toDouble() ?? 0.0;
    final displayPrice = isSelected && couponType != null
        ? PriceCalculator.calculateFinalPrice(
            periodPrice,
            couponType,
            couponValue,
          )
        : periodPrice;

    final hasDiscount = isSelected && 
        couponType != null && 
        displayPrice < periodPrice;

    // 根据屏幕大小动态调整尺寸
    final padding = (6 * scaleFactor).clamp(4.0, 10.0);
    final borderRadius = (8 * scaleFactor).clamp(6.0, 12.0);
    final iconSize = (14 * scaleFactor).clamp(12.0, 18.0);
    final labelFontSize = (11 * scaleFactor).clamp(10.0, 13.0);
    final priceFontSize = (13 * scaleFactor).clamp(12.0, 16.0);
    final originalPriceFontSize = (9 * scaleFactor).clamp(8.0, 11.0);
    final horizontalSpacing = (3 * scaleFactor).clamp(2.0, 5.0);
    final verticalSpacing = (3 * scaleFactor).clamp(2.0, 5.0);
    final priceSpacing = (4 * scaleFactor).clamp(3.0, 6.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.shade200.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 第一行：图标 + 周期名称
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  size: iconSize,
                ),
                SizedBox(width: horizontalSpacing),
                Flexible(
                  child: Text(
                    period['label'],
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            SizedBox(height: verticalSpacing),
            // 第二行：价格（有折扣时显示原价+折扣价，否则只显示价格）
            if (hasDiscount)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    PriceCalculator.formatPrice(periodPrice),
                    style: TextStyle(
                      fontSize: originalPriceFontSize,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.white70,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(width: priceSpacing),
                  Text(
                    PriceCalculator.formatPrice(displayPrice),
                    style: TextStyle(
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            else
              Text(
                PriceCalculator.formatPrice(periodPrice),
                style: TextStyle(
                  fontSize: priceFontSize,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.blue.shade700,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

