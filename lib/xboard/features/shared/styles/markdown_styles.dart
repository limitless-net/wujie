import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Markdown样式配置
/// 用于统一管理应用内Markdown内容的显示样式
class NoticeMarkdownStyles {
  /// 获取通知内容的Markdown样式
  /// 
  /// 样式设计原则：
  /// - H1-H6: 降级处理，因为通知标题已在顶部显示
  /// - 正文: 适中的行高和字体大小，保持可读性
  /// - 链接: 使用主题色，支持点击
  /// - 代码: 等宽字体，有背景区分
  static MarkdownStyleSheet getNoticeContentStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return MarkdownStyleSheet(
      // ========== 段落 ==========
      p: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
        height: 1.6,
        letterSpacing: 0.15,
      ),

      // ========== 标题层级 (降级处理) ==========
      // H1: 正文主标题 - 使用 titleLarge
      h1: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
        height: 1.3,
        letterSpacing: 0.15,
      ),

      // H2: 二级标题 - 使用 titleMedium
      h2: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
        height: 1.3,
        letterSpacing: 0.15,
      ),

      // H3: 三级标题 - 使用 bodyLarge
      h3: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
        height: 1.3,
        letterSpacing: 0.15,
      ),

      // H4: 四级标题 - 使用 bodyMedium + bold
      h4: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
        height: 1.3,
        letterSpacing: 0.1,
      ),

      // H5: 五级标题 - 使用 bodyMedium + semibold
      h5: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: 1.3,
        letterSpacing: 0.1,
      ),

      // H6: 六级标题 - 使用 bodyMedium + medium
      h6: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        height: 1.3,
        letterSpacing: 0.1,
      ),

      // ========== 文本样式 ==========
      // 粗体
      strong: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),

      // 斜体
      em: textTheme.bodyMedium?.copyWith(
        fontStyle: FontStyle.italic,
        color: colorScheme.onSurface.withValues(alpha: 0.85),
      ),

      // 删除线
      del: textTheme.bodyMedium?.copyWith(
        decoration: TextDecoration.lineThrough,
        color: colorScheme.onSurface.withValues(alpha: 0.6),
      ),

      // ========== 链接 ==========
      a: textTheme.bodyMedium?.copyWith(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: colorScheme.primary.withValues(alpha: 0.6),
      ),

      // ========== 列表 ==========
      listBullet: textTheme.bodyMedium?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),

      // ========== 代码 ==========
      // 行内代码
      code: textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: colorScheme.surfaceContainerHighest,
        color: colorScheme.tertiary,
        letterSpacing: 0,
      ),

      // 代码块
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),

      codeblockPadding: const EdgeInsets.all(12),

      // ========== 引用块 ==========
      blockquote: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface.withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
        height: 1.5,
      ),

      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.5),
            width: 4,
          ),
        ),
      ),

      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),

      // ========== 水平分隔线 ==========
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),

      // ========== 表格 ==========
      tableHead: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),

      tableBody: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),

      tableBorder: TableBorder.all(
        color: colorScheme.outline.withValues(alpha: 0.2),
        width: 1,
      ),

      tableCellsPadding: const EdgeInsets.all(8),

      // ========== 复选框 ==========
      checkbox: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
    );
  }

  /// 获取帮助文档的Markdown样式
  /// (如果将来需要其他样式变体，可以在这里添加)
  static MarkdownStyleSheet getHelpDocumentStyle(BuildContext context) {
    // 可以基于 getNoticeContentStyle 进行调整
    // 例如：更大的标题、更宽松的间距等
    return getNoticeContentStyle(context);
  }
}

