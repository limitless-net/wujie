import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_clash/xboard/features/notice/notice.dart';
import '../styles/markdown_styles.dart';
import '../styles/html_styles.dart';

/// 通知内容渲染类型
enum NoticeRenderType {
  /// Markdown 渲染
  markdown,
  /// HTML 渲染
  html,
}

/// 全局配置：选择通知内容的渲染方式
/// 
/// 可选值：
/// - null: 自动检测内容格式（默认，推荐）
/// - NoticeRenderType.markdown: 强制使用 Markdown 渲染
/// - NoticeRenderType.html: 强制使用 HTML 渲染
/// 
/// 设置为 null 时，程序会自动判断内容是 HTML 还是 Markdown
const NoticeRenderType? kNoticeRenderType = null;

class NoticeBanner extends ConsumerStatefulWidget {
  const NoticeBanner({super.key});
  @override
  ConsumerState<NoticeBanner> createState() => _NoticeBannerState();
}
class _NoticeBannerState extends ConsumerState<NoticeBanner>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  Timer? _autoScrollTimer;
  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(noticeProvider.notifier).fetchNotices();
    });
  }
  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }
  void _startAutoScroll(List<String> notices) {
    if (notices.isEmpty) return;
    _autoScrollTimer?.cancel();
    if (notices.length == 1) {
      _slideController.forward();
      return;
    }
    _slideController.forward();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        _slideToNext(notices.length);
      }
    });
  }
  void _slideToNext(int totalCount) {
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % totalCount;
        });
        _slideController.forward();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final noticeState = ref.watch(noticeProvider);
    if (noticeState.isLoading || noticeState.visibleNotices.isEmpty) {
      return const SizedBox.shrink();
    }
    final notices = noticeState.visibleNotices
        .map((notice) => notice.title)
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll(notices);
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark 
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.campaign_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _showNoticeDialog(),
              child: ClipRect(
                  child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    height: 40,
                    alignment: Alignment.centerLeft,
                    child: notices.isEmpty
                        ? const SizedBox.shrink()
                        : MarkdownBody(
                            data: notices[_currentIndex % notices.length],
                            styleSheet: MarkdownStyleSheet(
                              p: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                                overflow: TextOverflow.ellipsis,
                              ),
                              textAlign: WrapAlignment.start,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12), // 右侧间距
        ],
      ),
    );
  }
  void _showNoticeDialog() {
    final noticeState = ref.read(noticeProvider);
    if (noticeState.visibleNotices.isEmpty) return;
    
    // 在打开对话框前移除焦点
    FocusScope.of(context).unfocus();
    
    showDialog(
      context: context,
      builder: (context) => NoticeDetailDialog(
        notices: noticeState.visibleNotices,
        initialIndex: _currentIndex,
        onPageChanged: (index) {
          // 更新当前索引以便外部知道
        },
      ),
    ).then((_) {
      // 对话框关闭后也确保移除焦点
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }
}
class NoticeDetailDialog extends StatefulWidget {
  final List<dynamic> notices; // 使用 Notice 类型的列表
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;
  
  const NoticeDetailDialog({
    super.key,
    required this.notices,
    this.initialIndex = 0,
    this.onPageChanged,
  });
  @override
  State<NoticeDetailDialog> createState() => _NoticeDetailDialogState();
}
class _NoticeDetailDialogState extends State<NoticeDetailDialog> 
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.notices.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // 当对话框关闭时（无论通过什么方式），移除焦点
        if (didPop) {
          Future.microtask(() {
            if (context.mounted) {
              FocusScope.of(context).unfocus();
            }
          });
        }
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenWidth > 600 ? 600 : double.infinity,
            maxHeight: screenHeight * 0.85,
          ),
          decoration: BoxDecoration(
            // 在暗色主题下使用稍亮的背景色以区分弹窗
            color: isDark 
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            // 添加明显的边框
            border: Border.all(
              color: isDark
                  ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: isDark ? 1.5 : 1,
            ),
            boxShadow: [
              // 增强暗色主题下的阴影
              BoxShadow(
                color: isDark 
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: isDark ? 30 : 20,
                spreadRadius: isDark ? 2 : 0,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 40,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: widget.notices.length == 1
                    ? _buildSingleNotice()
                    : _buildMultipleNotices(),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    final currentNotice = widget.notices[_currentIndex];
    final title = currentNotice.title ?? '无标题';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        // 在暗色主题下头部使用更亮的背景色
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainer
            : Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.notices.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.notices.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // 在关闭对话框前移除焦点，避免键盘弹出
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Icon(
                  Icons.close_rounded,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSingleNotice() {
    final notice = widget.notices[0];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: _buildNoticeContent(notice),
    );
  }
  Widget _buildMultipleNotices() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              widget.onPageChanged?.call(index);
            },
            itemCount: widget.notices.length,
            itemBuilder: (context, index) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: _buildNoticeContent(widget.notices[index]),
              );
            },
          ),
        ),
        _buildNavigationBar(),
      ],
    );
  }
  
  Widget _buildNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        // 在暗色主题下底部导航栏使用更亮的背景色
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainer
            : Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            icon: Icons.chevron_left_rounded,
            label: '上一条',
            enabled: _currentIndex > 0,
            onPressed: () => _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
          _buildPageIndicator(),
          _buildNavButton(
            icon: Icons.chevron_right_rounded,
            label: '下一条',
            enabled: _currentIndex < widget.notices.length - 1,
            isReversed: true,
            onPressed: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
    bool isReversed = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: enabled 
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled 
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: isReversed ? [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: enabled 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 20,
                color: enabled 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
            ] : [
              Icon(
                icon,
                size: 20,
                color: enabled 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: enabled 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPageIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        widget.notices.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: index == _currentIndex ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == _currentIndex
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
  Widget _buildNoticeContent(dynamic notice) {
    String formatTime(dynamic timeValue) {
      if (timeValue == null) return '未知时间';
      try {
        DateTime dateTime;
        if (timeValue is int) {
          final timestamp = timeValue > 1000000000000 ? timeValue : timeValue * 1000;
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else if (timeValue is String) {
          dateTime = DateTime.parse(timeValue);
        } else {
          return timeValue.toString();
        }
        return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return timeValue.toString();
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间信息
        if (notice.createdAt != null || notice.updatedAt != null) ...[
          Text(
            formatTime(notice.createdAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // 内容区域 - 根据配置选择渲染方式
        _buildContentWidget(notice),
      ],
    );
  }
  /// 根据配置构建内容Widget（Markdown或HTML）
  Widget _buildContentWidget(dynamic notice) {
    final content = notice.content ?? '暂无内容';
    
    // 如果配置为 null，自动检测内容格式
    final renderType = kNoticeRenderType ?? _detectContentType(content);
    
    switch (renderType) {
      case NoticeRenderType.markdown:
        return _buildMarkdownContent(content);
      case NoticeRenderType.html:
        return _buildHtmlContent(content);
    }
  }
  
  /// 自动检测内容类型
  /// 
  /// 通过检查内容中是否包含 HTML 标签来判断：
  /// - 如果包含常见的 HTML 标签，认为是 HTML
  /// - 否则认为是 Markdown
  NoticeRenderType _detectContentType(String content) {
    // 去除首尾空白
    final trimmedContent = content.trim();
    
    // 如果内容为空，默认使用 Markdown
    if (trimmedContent.isEmpty) {
      return NoticeRenderType.markdown;
    }
    
    // 常见的 HTML 标签模式
    final htmlTagPattern = RegExp(
      r'<(p|div|span|h[1-6]|ul|ol|li|br|hr|strong|em|a|img|table|tr|td|th|blockquote|pre|code)[>\s]',
      caseSensitive: false,
    );
    
    // 如果匹配到 HTML 标签，使用 HTML 渲染
    if (htmlTagPattern.hasMatch(trimmedContent)) {
      return NoticeRenderType.html;
    }
    
    // 默认使用 Markdown 渲染
    return NoticeRenderType.markdown;
  }
  
  /// 构建Markdown内容
  Widget _buildMarkdownContent(String content) {
    return MarkdownBody(
      data: _processMarkdownForDialog(content),
      styleSheet: NoticeMarkdownStyles.getNoticeContentStyle(context),
      onTapLink: (text, href, title) => _handleLinkTap(href),
    );
  }
  
  /// 构建HTML内容
  Widget _buildHtmlContent(String content) {
    return NoticeHtmlStyles.buildNoticeHtml(
      context: context,
      htmlContent: _processHtmlForDialog(content),
      onTapUrl: (url) => _handleLinkTap(url),
    );
  }
  
  String _processMarkdownForDialog(String markdownText) {
    return markdownText.trim();
  }
  
  String _processHtmlForDialog(String htmlText) {
    return htmlText.trim();
  }
  
  /// 处理Markdown/HTML中的链接点击
  void _handleLinkTap(String? href) async {
    if (href == null || href.isEmpty) return;
    
    try {
      final uri = Uri.parse(href);
      
      // 检查是否可以启动该链接
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // 在外部浏览器打开
        );
      } else {
        // 如果无法打开，显示提示
        if (mounted) {
          XBoardNotification.showError('无法打开链接: $href');
        }
      }
    } catch (e) {
      // 处理无效URL或其他错误
      if (mounted) {
        XBoardNotification.showError('链接格式错误: $href');
      }
    }
  }
}