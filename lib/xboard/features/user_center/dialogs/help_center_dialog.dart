import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart' show XBoardSDK;
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// 帮助中心对话框 — 知识库文章列表 + 详情
class HelpCenterDialog extends StatefulWidget {
  const HelpCenterDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const HelpCenterDialog(),
    );
  }

  @override
  State<HelpCenterDialog> createState() => _HelpCenterDialogState();
}

class _HelpCenterDialogState extends State<HelpCenterDialog> {
  bool _isLoading = true;
  String? _error;
  List<_KnowledgeCategory> _categories = [];
  _KnowledgeArticle? _selectedArticle;
  bool _isLoadingDetail = false;
  String? _searchQuery;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles({String? keyword}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final httpService = XBoardSDK.instance.httpService;
      // 构建请求参数
      final params = <String, String>{
        'language': 'zh-CN',
      };
      if (keyword != null && keyword.isNotEmpty) {
        params['keyword'] = keyword;
      }
      final query = params.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final url = '/api/v1/user/knowledge/fetch${query.isNotEmpty ? '?$query' : ''}';
      final response = await httpService.getRequest(url);
      final data = response['data'];

      final categories = <_KnowledgeCategory>[];
      if (data is Map<String, dynamic>) {
        // 后端 groupBy('category') 返回 { "分类名": [{article}, ...], ... }
        for (final entry in data.entries) {
          final categoryName = entry.key;
          final articles = <_KnowledgeArticle>[];
          if (entry.value is List) {
            for (final item in entry.value as List) {
              if (item is Map<String, dynamic>) {
                articles.add(_KnowledgeArticle.fromJson(item));
              }
            }
          }
          if (articles.isNotEmpty) {
            categories.add(_KnowledgeCategory(
              name: categoryName,
              articles: articles,
            ));
          }
        }
      } else if (data is List) {
        // 兼容：万一返回的是 List 格式
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            categories.add(_KnowledgeCategory.fromJson(item));
          }
        }
      }
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败，请检查网络后重试';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadArticleDetail(int id) async {
    setState(() => _isLoadingDetail = true);
    try {
      final httpService = XBoardSDK.instance.httpService;
      final response =
          await httpService.getRequest('/api/v1/user/knowledge/fetch?id=$id');
      final data = response['data'];
      if (data is Map<String, dynamic> && mounted) {
        setState(() {
          _selectedArticle = _KnowledgeArticle(
            id: data['id'] as int? ?? id,
            title: data['title'] as String? ?? '',
            category: data['category'] as String? ?? '',
            body: data['body'] as String? ?? '',
            updatedAt: data['updated_at'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    (data['updated_at'] as int) * 1000)
                : null,
          );
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加载文章失败')),
        );
      }
    }
  }

  void _goBack() {
    setState(() => _selectedArticle = null);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    final dialogWidth = (screenSize.width * 0.55).clamp(420.0, 700.0);
    final dialogHeight = (screenSize.height * 0.72).clamp(400.0, 620.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? colorScheme.surfaceContainerLow : Colors.white,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // ── 标题栏
            _buildHeader(colorScheme, textTheme, isDark),
            // ── 内容区
            Expanded(
              child: _selectedArticle != null
                  ? _buildArticleDetail(colorScheme, textTheme, isDark)
                  : _buildArticleList(colorScheme, textTheme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      ColorScheme colorScheme, TextTheme textTheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_selectedArticle != null) ...[
            IconButton(
              onPressed: _goBack,
              icon: Icon(Icons.arrow_back_rounded,
                  size: 20, color: colorScheme.onSurface),
              style: IconButton.styleFrom(
                backgroundColor:
                    colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              tooltip: '返回列表',
            ),
            const SizedBox(width: 10),
          ] else ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.shade300,
                    Colors.orange.shade600,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.help_outline_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              _selectedArticle != null ? _selectedArticle!.title : '帮助中心',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded,
                size: 20, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleList(
      ColorScheme colorScheme, TextTheme textTheme, bool isDark) {
    return Column(
      children: [
        // ── 搜索栏
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索帮助文章...',
              hintStyle: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 20,
                  color:
                      colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              suffixIcon: _searchQuery != null && _searchQuery!.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = null);
                        _loadArticles();
                      },
                      icon: Icon(Icons.clear_rounded,
                          size: 18, color: colorScheme.onSurfaceVariant),
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
            style: textTheme.bodyMedium,
            onSubmitted: (value) {
              setState(() => _searchQuery = value);
              _loadArticles(keyword: value);
            },
          ),
        ),
        // ── 列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorView(colorScheme, textTheme)
                  : _categories.isEmpty
                      ? _buildEmptyView(colorScheme, textTheme)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            return _buildCategorySection(
                                _categories[index], colorScheme, textTheme,
                                isDark);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(_KnowledgeCategory category,
      ColorScheme colorScheme, TextTheme textTheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分类标题
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category.name,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        // 文章列表
        ...category.articles.map((article) => _buildArticleTile(
            article, colorScheme, textTheme, isDark)),
      ],
    );
  }

  Widget _buildArticleTile(_KnowledgeArticle article,
      ColorScheme colorScheme, TextTheme textTheme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _loadArticleDetail(article.id),
          borderRadius: BorderRadius.circular(12),
          hoverColor:
              colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.03),
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.article_outlined,
                    size: 18,
                    color: colorScheme.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    article.title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArticleDetail(
      ColorScheme colorScheme, TextTheme textTheme, bool isDark) {
    if (_isLoadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }

    final article = _selectedArticle!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 元信息
          if (article.category.isNotEmpty || article.updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (article.category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article.category,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (article.updatedAt != null)
                    Text(
                      '更新于 ${_formatDate(article.updatedAt!)}',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
          // 正文（Markdown→HTML→渲染）
          _buildHtmlBody(article.body, colorScheme, textTheme, isDark),
        ],
      ),
    );
  }

  /// 将混合内容（Markdown + HTML）转为纯 HTML，再用 HtmlWidget 渲染
  Widget _buildHtmlBody(String body, ColorScheme colorScheme,
      TextTheme textTheme, bool isDark) {
    // 先用 markdown 包将 Markdown 语法转为 HTML
    // inlineSyntaxes 保留内嵌 HTML 原样通过
    final htmlContent = md.markdownToHtml(
      body,
      extensionSet: md.ExtensionSet.gitHubWeb,
      inlineOnly: false,
    );

    // 用 CSS 包裹一层，限制图片最大宽度
    final styledHtml = '''
<style>
  img { max-width: 280px; height: auto; border-radius: 8px; margin: 6px 0; }
  p { margin: 0 0 10px 0; line-height: 1.6; }
  h1, h2, h3, h4, h5, h6 { margin: 14px 0 8px 0; }
  hr { border: none; border-top: 1px solid rgba(128,128,128,0.2); margin: 12px 0; }
  a { color: ${_colorToHex(colorScheme.primary)}; }
  blockquote { border-left: 3px solid ${_colorToHex(colorScheme.primary)}; padding-left: 10px; margin: 8px 0; color: rgba(0,0,0,0.6); }
  code { background: rgba(128,128,128,0.1); padding: 1px 4px; border-radius: 3px; font-size: 0.9em; }
  pre { background: rgba(128,128,128,0.08); padding: 10px; border-radius: 6px; overflow: auto; }
</style>
$htmlContent
''';

    return HtmlWidget(
      styledHtml,
      onTapUrl: (url) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return true;
      },
      textStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
        height: 1.6,
      ),
    );
  }

  static String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).substring(2)}';
  }

  Widget _buildErrorView(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            _error ?? '加载失败',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _loadArticles(keyword: _searchQuery),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            _searchQuery != null && _searchQuery!.isNotEmpty
                ? '未找到相关文章'
                : '暂无帮助文章',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ── 数据模型

class _KnowledgeCategory {
  final String name;
  final List<_KnowledgeArticle> articles;

  const _KnowledgeCategory({required this.name, required this.articles});

  factory _KnowledgeCategory.fromJson(Map<String, dynamic> json) {
    final name = json['category'] as String? ?? '未分类';
    final items = json['articles'] as List<dynamic>? ?? [];
    return _KnowledgeCategory(
      name: name,
      articles: items
          .whereType<Map<String, dynamic>>()
          .map((e) => _KnowledgeArticle.fromJson(e))
          .toList(),
    );
  }
}

class _KnowledgeArticle {
  final int id;
  final String title;
  final String category;
  final String body;
  final DateTime? updatedAt;

  const _KnowledgeArticle({
    required this.id,
    required this.title,
    this.category = '',
    this.body = '',
    this.updatedAt,
  });

  factory _KnowledgeArticle.fromJson(Map<String, dynamic> json) {
    return _KnowledgeArticle(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      body: json['body'] as String? ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['updated_at'] as int) * 1000)
          : null,
    );
  }
}
