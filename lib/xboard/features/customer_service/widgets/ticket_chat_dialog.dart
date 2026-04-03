import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart';
import 'package:fl_clash/xboard/utils/xboard_notification.dart';
import 'package:intl/intl.dart';

/// 工单聊天弹窗 — 右下角悬浮式客服对话
class TicketChatDialog extends StatefulWidget {
  const TicketChatDialog({super.key});

  /// 从右下角弹出对话框
  static Future<void> show(BuildContext context) async {
    // 检查是否已登录
    final hasToken = await XBoardSDK.instance.hasToken();
    if (!hasToken) {
      if (context.mounted) {
        _showNeedLoginHint(context);
      }
      return;
    }
    
    if (!context.mounted) return;
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    final screenSize = MediaQuery.of(context).size;

    if (isDesktop) {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '关闭客服',
        barrierColor: Colors.black26,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, anim1, anim2) {
          return Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24, bottom: 80),
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 400,
                  height: (screenSize.height * 0.7).clamp(420.0, 640.0),
                  child: const TicketChatDialog(),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, anim1, anim2, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
            child: FadeTransition(opacity: anim1, child: child),
          );
        },
      );
    } else {
      // 移动端：几乎全屏
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '关闭客服',
        barrierColor: Colors.black38,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, anim1, anim2) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: screenSize.width,
                  height: screenSize.height - 60,
                  child: const TicketChatDialog(),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, anim1, anim2, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
            child: child,
          );
        },
      );
    }
  }

  /// 未登录时提示需要登录才能使用在线客服
  static void _showNeedLoginHint(BuildContext context) {
    XBoardNotification.showError('请先登录后再使用在线客服');
  }

  @override
  State<TicketChatDialog> createState() => _TicketChatDialogState();
}

class _TicketChatDialogState extends State<TicketChatDialog> {
  // ---- 数据 ----
  List<TicketModel> _tickets = [];
  TicketDetailModel? _currentTicket;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingImage = false;
  String? _error;

  // 本地待发送消息（乐观更新）
  final List<TicketMessageModel> _pendingMessages = [];

  // ---- 视图 ----
  bool _showHistory = false;

  // ---- 控制器 ----
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ======================== 数据加载 ========================

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tickets = await XBoardSDK.instance.ticket.getTickets();
      // 按更新时间降序排列
      tickets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // 自动打开最近的活跃工单 (status == 0 为处理中)
      TicketDetailModel? activeDetail;
      final activeTicket = tickets.where((t) => t.status == 0).firstOrNull;
      if (activeTicket != null) {
        try {
          activeDetail =
              await XBoardSDK.instance.ticket.getTicket(activeTicket.id);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _tickets = tickets;
          _currentTicket = activeDetail;
          _isLoading = false;
        });
        _startPolling();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载工单失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openTicket(int id) async {
    setState(() {
      _isLoading = true;
      _showHistory = false;
    });
    try {
      final detail = await XBoardSDK.instance.ticket.getTicket(id);
      if (mounted) {
        setState(() {
          _currentTicket = detail;
          _isLoading = false;
        });
        _startPolling();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshCurrentTicket();
    });
  }

  Future<void> _refreshCurrentTicket() async {
    if (_currentTicket == null) return;
    try {
      final detail =
          await XBoardSDK.instance.ticket.getTicket(_currentTicket!.id);
      if (mounted) {
        final oldCount = _currentTicket!.messages.length;
        // 服务端消息已包含之前发送的，清除本地待发送
        _pendingMessages.clear();
        setState(() => _currentTicket = detail);
        if (detail.messages.length > oldCount) {
          _scrollToBottom();
        }
      }
    } catch (_) {}
  }

  // ======================== 操作 ========================

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    // 立即在本地显示发送的消息（乐观更新）
    final pendingMsg = TicketMessageModel(
      id: -DateTime.now().millisecondsSinceEpoch,
      ticketId: _currentTicket?.id ?? 0,
      isMe: true,
      message: text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    setState(() => _pendingMessages.add(pendingMsg));
    _scrollToBottom();

    try {
      if (_currentTicket == null) {
        // 创建新工单
        await XBoardSDK.instance.ticket
            .createTicket('客户咨询', text, 0);
        // 静默加载，不显示 loading
        await _silentReloadTickets();
      } else {
        // 回复已有工单
        await XBoardSDK.instance.ticket
            .replyTicket(_currentTicket!.id, text);
        await _refreshCurrentTicket();
      }
    } catch (e) {
      // 如果是创建新工单时出错，先检查服务器是否实际已创建成功
      // （"Connection closed before full header" 表示服务器可能已处理请求但响应丢失）
      if (_currentTicket == null) {
        try {
          await _silentReloadTickets();
          if (_currentTicket != null) {
            // 服务器已创建成功，只是响应传输中断 → 不显示错误，直接进入聊天
            return;
          }
        } catch (_) {}
      }

      final errorMsg = e is XBoardException ? e.message : '$e';
      XBoardNotification.showError('发送失败: $errorMsg');
      // 图片消息发送失败时不恢复原始 URL 文本（对用户无意义）
      if (!text.startsWith('[图片]')) {
        _textController.text = text;
      }
      // 移除发送失败的本地消息
      setState(() => _pendingMessages.remove(pendingMsg));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// 静默重新加载工单（不显示 loading 动画）
  Future<void> _silentReloadTickets() async {
    try {
      final tickets = await XBoardSDK.instance.ticket.getTickets();
      tickets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      TicketDetailModel? activeDetail;
      final activeTicket = tickets.where((t) => t.status == 0).firstOrNull;
      if (activeTicket != null) {
        try {
          activeDetail =
              await XBoardSDK.instance.ticket.getTicket(activeTicket.id);
        } catch (_) {}
      }

      if (mounted) {
        _pendingMessages.clear();
        setState(() {
          _tickets = tickets;
          _currentTicket = activeDetail;
        });
        _startPolling();
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        XBoardNotification.showError('无法读取图片文件');
        return;
      }

      // 限制文件大小 5MB
      if (bytes.length > 5 * 1024 * 1024) {
        XBoardNotification.showError('图片大小不能超过 5MB');
        return;
      }

      setState(() => _isUploadingImage = true);

      try {
        // 通过 SDK 的 Dio 实例上传图片（走同一条网络通道：代理、SSL、认证）
        final mimeType = _getMimeType(file.name);
        
        // 网络不稳定时自动重试（最多3次）
        Map<String, dynamic>? uploadResult;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            uploadResult = await XBoardSDK.instance.httpService.uploadFile(
              '/api/v1/user/upload/image',
              fieldName: 'file',
              fileBytes: bytes.toList(),
              fileName: file.name,
              mimeType: mimeType,
            );
            break; // 成功则跳出重试循环
          } catch (e) {
            if (attempt == 3) rethrow;
            // 等待后重试
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }

        final imageUrl = uploadResult?['data'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          // 发送图片 URL 作为消息
          _textController.text = '[图片] $imageUrl';
          await _sendMessage();
        } else {
          XBoardNotification.showError('上传成功但未返回图片链接');
        }
      } on XBoardException catch (e) {
        // 统一处理所有 SDK 异常（ApiException、NetworkException 等）
        XBoardNotification.showError('图片上传失败: ${e.message}');
      } catch (e) {
        XBoardNotification.showError('图片上传失败: $e');
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isUploadingImage = false);
      XBoardNotification.showError('选择图片失败: $e');
    }
  }

  Future<void> _closeCurrentTicket() async {
    if (_currentTicket == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭工单'),
        content: const Text('关闭后将无法继续回复此工单，确定要关闭吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确定')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await XBoardSDK.instance.ticket.closeTicket(_currentTicket!.id);
      XBoardNotification.showSuccess('工单已关闭');
      setState(() => _currentTicket = null);
      await _loadTickets();
    } catch (e) {
      XBoardNotification.showError('关闭失败: $e');
    }
  }

  void _startNewConversation() {
    setState(() {
      _currentTicket = null;
      _showHistory = false;
    });
    _textController.clear();
  }

  // ======================== 工具方法 ========================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String? _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('MM/dd HH:mm').format(dt);
  }

  String _ticketStatusText(int status) {
    switch (status) {
      case 0:
        return '处理中';
      case 1:
        return '已关闭';
      default:
        return '未知';
    }
  }

  Color _ticketStatusColor(int status, ColorScheme cs) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return cs.outline;
      default:
        return cs.outline;
    }
  }

  // ======================== 构建UI ========================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    return ClipRRect(
      borderRadius: BorderRadius.circular(isDesktop ? 16 : 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(colorScheme),
            Expanded(
              child: _showHistory
                  ? _buildHistoryView(colorScheme)
                  : _buildChatView(colorScheme),
            ),
            if (!_showHistory) _buildInputBar(colorScheme),
          ],
        ),
      ),
    );
  }

  // ---- 头部 ----
  Widget _buildHeader(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.headset_mic, color: cs.onPrimaryContainer, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showHistory
                      ? '工单历史'
                      : (_currentTicket != null
                          ? '#${_currentTicket!.id} ${_currentTicket!.subject}'
                          : '在线客服'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: cs.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_currentTicket != null && !_showHistory)
                  Text(
                    _ticketStatusText(_currentTicket!.status),
                    style: TextStyle(
                      fontSize: 11,
                      color: _ticketStatusColor(
                          _currentTicket!.status, cs),
                    ),
                  ),
              ],
            ),
          ),
          // 工具按钮
          if (_currentTicket != null && !_showHistory)
            _headerButton(
              icon: Icons.close,
              tooltip: '关闭工单',
              onTap: _closeCurrentTicket,
              cs: cs,
            ),
          if (_currentTicket != null && !_showHistory)
            _headerButton(
              icon: Icons.add_comment_outlined,
              tooltip: '新对话',
              onTap: _startNewConversation,
              cs: cs,
            ),
          _headerButton(
            icon: _showHistory ? Icons.chat_bubble_outline : Icons.history,
            tooltip: _showHistory ? '返回对话' : '历史工单',
            onTap: () => setState(() => _showHistory = !_showHistory),
            cs: cs,
          ),
          _headerButton(
            icon: Icons.close,
            tooltip: '关闭窗口',
            onTap: () => Navigator.of(context).pop(),
            cs: cs,
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
        ),
      ),
    );
  }

  // ---- 聊天视图 ----
  Widget _buildChatView(ColorScheme cs) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: cs.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error)),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadTickets, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    // 无活跃工单但有待发送消息 → 显示待发送的消息
    if (_currentTicket == null && _pendingMessages.isNotEmpty) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _pendingMessages.length,
        itemBuilder: (context, index) {
          final msg = _pendingMessages[index];
          return _MessageBubble(
            message: msg.message,
            isMe: true,
            time: _formatTime(msg.createdAt),
            colorScheme: cs,
            isPending: true,
          );
        },
      );
    }

    // 无活跃工单 → 欢迎界面
    if (_currentTicket == null) {
      return _buildWelcomeView(cs);
    }

    // 有工单 → 服务端消息 + 本地待发送消息
    final allMessages = [
      ..._currentTicket!.messages,
      ..._pendingMessages,
    ];
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: allMessages.length,
      itemBuilder: (context, index) {
        final msg = allMessages[index];
        final isPending = index >= _currentTicket!.messages.length;
        return _MessageBubble(
          message: msg.message,
          isMe: msg.isMe,
          time: _formatTime(msg.createdAt),
          colorScheme: cs,
          isPending: isPending,
        );
      },
    );
  }

  // ---- 欢迎视图 ----
  Widget _buildWelcomeView(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.support_agent, size: 56,
                color: cs.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              '欢迎使用在线客服',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '在下方输入您的问题，我们会尽快为您处理',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 历史工单列表 ----
  Widget _buildHistoryView(ColorScheme cs) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tickets.isEmpty) {
      return Center(
        child: Text('暂无工单记录',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final t = _tickets[index];
        return _TicketListItem(
          ticket: t,
          isActive: _currentTicket?.id == t.id,
          statusText: _ticketStatusText(t.status),
          statusColor: _ticketStatusColor(t.status, cs),
          timeText: _formatTime(t.updatedAt),
          colorScheme: cs,
          onTap: () => _openTicket(t.id),
        );
      },
    );
  }

  // ---- 输入栏 ----
  Widget _buildInputBar(ColorScheme cs) {
    final isClosed = _currentTicket != null && _currentTicket!.status == 1;

    if (isClosed) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: cs.outline),
            const SizedBox(width: 6),
            Text('此工单已关闭',
                style: TextStyle(fontSize: 13, color: cs.outline)),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _startNewConversation,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新对话', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 图片上传按钮
            IconButton(
              icon: _isUploadingImage
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : Icon(Icons.image_outlined, color: cs.primary, size: 22),
              onPressed:
                  (_isSending || _isUploadingImage) ? null : _pickAndUploadImage,
              tooltip: '发送图片',
              visualDensity: VisualDensity.compact,
            ),
            // 输入框
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      // Enter 发送，Shift+Enter 换行
                      _sendMessage();
                      return KeyEventResult.handled; // 阻止换行插入
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _currentTicket == null ? '输入问题开始对话...' : '输入回复...',
                      hintStyle: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 发送按钮
            IconButton(
              icon: _isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : Icon(Icons.send_rounded, color: cs.primary, size: 22),
              onPressed: _isSending ? null : _sendMessage,
              tooltip: '发送',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ======================== 子组件 ========================

/// 消息气泡
class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;
  final ColorScheme colorScheme;
  final bool isPending;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.time,
    required this.colorScheme,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = message.startsWith('[图片]') && 
        (message.contains('http') || message.contains('/api/'));
    return Opacity(
      opacity: isPending ? 0.6 : 1.0,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _avatar(false),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: isImage
                      ? _buildImageMessage()
                      : Text(
                          message,
                          style: TextStyle(
                            fontSize: 14,
                            color: isMe
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                          ),
                        ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPending)
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(Icons.access_time,
                            size: 10, color: colorScheme.outline),
                      ),
                    Text(
                      isPending ? '发送中...' : time,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _avatar(true),
        ],
      ),
    ),
    );
  }

  Widget _avatar(bool me) {
    return CircleAvatar(
      radius: 14,
      backgroundColor:
          me ? colorScheme.primary : colorScheme.secondaryContainer,
      child: Icon(
        me ? Icons.person : Icons.support_agent,
        size: 16,
        color:
            me ? colorScheme.onPrimary : colorScheme.onSecondaryContainer,
      ),
    );
  }

  Widget _buildImageMessage() {
    // 后端格式: "[图片] https://xxx/image/abc.jpg\n管理员文字说明"
    // 第一行是图片URL，后续行是caption文字
    final content = message.replaceFirst('[图片] ', '').trim();
    final lines = content.split('\n');
    final url = lines.first.trim();
    final caption = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';

    // 支持完整URL（http/https）和相对路径（/api/v1/guest/upload/image/...）
    final isImageUrl = url.startsWith('http') || url.startsWith('/api/');
    if (!isImageUrl) {
      return Text(message,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurface));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProxiedNetworkImage(url: url, colorScheme: colorScheme),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            style: TextStyle(
              fontSize: 14,
              color: isMe
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}

/// 通过 SDK 的 Dio（代理 + SSL）加载图片
///
/// 使用静态内存缓存，避免 ListView 回收/重建时重复下载。
class _ProxiedNetworkImage extends StatefulWidget {
  final String url;
  final ColorScheme colorScheme;

  const _ProxiedNetworkImage({required this.url, required this.colorScheme});

  /// 图片字节缓存（URL → bytes），整个对话生命周期内有效
  static final Map<String, Uint8List> _cache = {};

  /// 正在下载的请求去重（URL → Future）
  static final Map<String, Future<Uint8List>> _inflight = {};

  @override
  State<_ProxiedNetworkImage> createState() => _ProxiedNetworkImageState();
}

class _ProxiedNetworkImageState extends State<_ProxiedNetworkImage> {
  Uint8List? _imageBytes;
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // 1. 命中内存缓存 → 直接展示，不走网络
    final cached = _ProxiedNetworkImage._cache[widget.url];
    if (cached != null) {
      setState(() {
        _imageBytes = cached;
        _loading = false;
      });
      return;
    }

    try {
      // 2. 复用进行中的同 URL 下载（去重）
      var future = _ProxiedNetworkImage._inflight[widget.url];
      if (future == null) {
        future = XBoardSDK.instance.httpService.downloadBytes(widget.url);
        _ProxiedNetworkImage._inflight[widget.url] = future;
      }

      final bytes = await future;
      _ProxiedNetworkImage._cache[widget.url] = bytes;
      _ProxiedNetworkImage._inflight.remove(widget.url);

      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      _ProxiedNetworkImage._inflight.remove(widget.url);
      if (mounted) {
        setState(() {
          _error = true;
          _errorMsg = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 200,
        height: 120,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error || _imageBytes == null || _imageBytes!.isEmpty) {
      return Container(
        width: 200,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, size: 16, color: widget.colorScheme.error),
                const SizedBox(width: 4),
                Text('图片加载失败',
                    style: TextStyle(fontSize: 12, color: widget.colorScheme.error)),
              ],
            ),
            if (_errorMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_errorMsg,
                    style: TextStyle(fontSize: 10, color: widget.colorScheme.outline),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => _showFullImage(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 300),
          child: Image.memory(
            _imageBytes!,
            width: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  /// 全屏查看图片，支持双指缩放和拖动
  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // 点击背景关闭
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(color: Colors.black87),
            ),
            // 可缩放图片
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  _imageBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // 关闭按钮
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 工单列表项
class _TicketListItem extends StatelessWidget {
  final TicketModel ticket;
  final bool isActive;
  final String statusText;
  final Color statusColor;
  final String timeText;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _TicketListItem({
    required this.ticket,
    required this.isActive,
    required this.statusText,
    required this.statusColor,
    required this.timeText,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                                fontSize: 10, color: statusColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${ticket.id}',
                          style: TextStyle(
                              fontSize: 11, color: colorScheme.outline),
                        ),
                        const Spacer(),
                        Text(
                          timeText,
                          style: TextStyle(
                              fontSize: 11, color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  size: 18, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
