import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

/// HTML样式配置
/// 用于统一管理应用内HTML内容的显示样式
class NoticeHtmlStyles {
  /// 将Color转换为CSS颜色字符串
  static String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).substring(2)}';
  }

  /// 获取通知内容的HTML Widget配置
  static HtmlWidget buildNoticeHtml({
    required BuildContext context,
    required String htmlContent,
    required Function(String?)? onTapUrl,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return HtmlWidget(
      htmlContent,
      onTapUrl: (url) {
        onTapUrl?.call(url);
        return true; // 返回true表示已处理
      },
      textStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
        height: 1.6,
      ),
      customStylesBuilder: (element) {
        // 根据不同的HTML标签返回对应的样式
        switch (element.localName) {
          case 'h1':
            return {
              'font-size': '${textTheme.titleLarge?.fontSize ?? 22}px',
              'font-weight': 'bold',
              'color': _colorToHex(colorScheme.onSurface),
              'line-height': '1.3',
              'margin': '16px 0 12px 0',
            };
          case 'h2':
            return {
              'font-size': '${textTheme.titleMedium?.fontSize ?? 16}px',
              'font-weight': 'bold',
              'color': _colorToHex(colorScheme.onSurface),
              'line-height': '1.3',
              'margin': '14px 0 10px 0',
            };
          case 'h3':
            return {
              'font-size': '${textTheme.bodyLarge?.fontSize ?? 16}px',
              'font-weight': 'bold',
              'color': _colorToHex(colorScheme.onSurface),
              'line-height': '1.3',
              'margin': '12px 0 8px 0',
            };
          case 'h4':
          case 'h5':
          case 'h6':
            return {
              'font-size': '${textTheme.bodyMedium?.fontSize ?? 14}px',
              'font-weight': element.localName == 'h4' ? 'bold' : '600',
              'color': _colorToHex(colorScheme.onSurface),
              'line-height': '1.3',
              'margin': '10px 0 8px 0',
            };
          case 'p':
            return {
              'margin': '0 0 12px 0',
              'line-height': '1.6',
            };
          case 'a':
            return {
              'color': _colorToHex(colorScheme.primary),
              'text-decoration': 'underline',
            };
          case 'code':
            return {
              'font-family': 'monospace',
              'font-size': '${(textTheme.bodySmall?.fontSize ?? 12)}px',
              'background-color': _colorToHex(colorScheme.surfaceContainerHighest),
              'color': _colorToHex(colorScheme.tertiary),
              'padding': '2px 4px',
              'border-radius': '4px',
            };
          case 'pre':
            return {
              'font-family': 'monospace',
              'font-size': '${textTheme.bodySmall?.fontSize ?? 12}px',
              'background-color': _colorToHex(colorScheme.surfaceContainerHighest),
              'padding': '12px',
              'margin': '8px 0',
              'border': '1px solid ${_colorToHex(colorScheme.outline.withValues(alpha: 0.2))}',
              'border-radius': '8px',
              'overflow': 'auto',
            };
          case 'blockquote':
            return {
              'color': _colorToHex(colorScheme.onSurface.withValues(alpha: 0.7)),
              'font-style': 'italic',
              'border-left': '4px solid ${_colorToHex(colorScheme.primary.withValues(alpha: 0.5))}',
              'padding-left': '12px',
              'margin': '8px 0',
            };
          case 'ul':
          case 'ol':
            return {
              'margin': '8px 0',
              'padding-left': '20px',
            };
          case 'li':
            return {
              'margin-bottom': '4px',
            };
          case 'strong':
          case 'b':
            return {
              'font-weight': 'bold',
            };
          case 'em':
          case 'i':
            return {
              'font-style': 'italic',
            };
          case 'hr':
            return {
              'border': 'none',
              'border-top': '1px solid ${_colorToHex(colorScheme.outline.withValues(alpha: 0.3))}',
              'margin': '16px 0',
            };
          case 'img':
            return {
              'margin': '8px 0',
              'max-width': '100%',
              'height': 'auto',
            };
          default:
            return null;
        }
      },
      // 启用功能
      enableCaching: true,
      renderMode: RenderMode.column,
    );
  }
}

