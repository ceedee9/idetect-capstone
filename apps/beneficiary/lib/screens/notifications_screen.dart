import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_design_system.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onReadChanged;

  const NotificationsScreen({super.key, this.onReadChanged});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _notifications;
  bool _isLoading = true;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
    });

    try {
      final result = await ApiService.getNotifications(page: 1, limit: 30);
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result.success) {
            _notifications = result.notifications;
            _hasMore = _notifications!.length < result.total;
            _page = 2;
          } else {
            _error = result.errorMessage ?? 'Failed to load notifications.';
            _notifications = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
          _notifications = [];
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final result = await ApiService.getNotifications(page: _page, limit: 30);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result != null) {
          _notifications!.addAll(result.notifications);
          _hasMore = _notifications!.length < result.total;
          _page++;
        }
      });
    }
  }

  Future<void> _markRead(String id) async {
    final ok = await ApiService.markNotificationRead(id);
    if (ok && mounted) {
      setState(() {
        final idx = _notifications!.indexWhere((n) => n.id == id);
        if (idx != -1) {
          final old = _notifications![idx];
          _notifications![idx] = AppNotification(
            id: old.id,
            notificationType: old.notificationType,
            title: old.title,
            body: old.body,
            channel: old.channel,
            isRead: true,
            sentAt: old.sentAt,
          );
        }
      });
      widget.onReadChanged?.call();
    }
  }

  Future<void> _markAllRead() async {
    final ok = await ApiService.markAllNotificationsRead();
    if (ok && mounted) {
      setState(() {
        _notifications = _notifications!
            .map(
              (n) => AppNotification(
                id: n.id,
                notificationType: n.notificationType,
                title: n.title,
                body: n.body,
                channel: n.channel,
                isRead: true,
                sentAt: n.sentAt,
              ),
            )
            .toList();
      });
      widget.onReadChanged?.call();
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'verification_approved':
        return Icons.check_circle_outline;
      case 'verification_denied':
        return Icons.cancel_outlined;
      case 'dispute_submitted':
        return Icons.inbox_outlined;
      case 'dispute_acknowledged':
      case 'dispute_escalated':
      case 'dispute_resolved':
        return Icons.gavel;
      case 'flag_confirmed':
        return Icons.flag_outlined;
      case 'id_expiring_soon':
        return Icons.timer_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'verification_approved':
        return AppDesignSystem.statusValid;
      case 'verification_denied':
        return AppDesignSystem.accentRed;
      case 'dispute_submitted':
        return AppDesignSystem.primaryBlue;
      case 'dispute_acknowledged':
        return Colors.orange;
      case 'dispute_escalated':
        return Colors.deepOrange;
      case 'dispute_resolved':
        return AppDesignSystem.secondaryBlue;
      case 'flag_confirmed':
        return AppDesignSystem.accentRed;
      case 'id_expiring_soon':
        return Colors.amber.shade700;
      default:
        return AppDesignSystem.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notifications == null && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppDesignSystem.primaryBlue),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final list = _notifications ?? [];
    final hasUnread = list.any((n) => !n.isRead);

    return Column(
      children: [
        // Mark all read
        if (hasUnread)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _markAllRead,
                icon: const Icon(
                  Icons.done_all,
                  size: 18,
                  color: AppDesignSystem.secondaryBlue,
                ),
                label: Text(
                  'Mark all as read',
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: AppDesignSystem.secondaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppDesignSystem.primaryBlue,
            child: list.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(
                      AppDesignSystem.screenPaddingHorizontal,
                    ),
                    itemCount: list.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == list.length) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppDesignSystem.primaryBlue,
                            ),
                          ),
                        );
                      }
                      return _buildTile(list[i]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    // Must be a scrollable widget so RefreshIndicator can be triggered
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: AppDesignSystem.textTertiary,
                ),
                const SizedBox(height: AppDesignSystem.spaceSM),
                Text('No notifications', style: AppDesignSystem.bodyMedium),
                const SizedBox(height: AppDesignSystem.spaceXS),
                Text(
                  'Pull down to refresh',
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: AppDesignSystem.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(AppNotification n) {
    final timeStr = DateFormat('MMM d, h:mm a').format(n.sentAt);
    final color = _colorForType(n.notificationType);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spaceXS),
      decoration: BoxDecoration(
        color: n.isRead ? Colors.white : const Color(0xFFF1F4FF),
        borderRadius: AppDesignSystem.cardRadius,
        boxShadow: AppDesignSystem.shadowSM,
        border: n.isRead
            ? null
            : Border.all(color: AppDesignSystem.secondaryBlue.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: AppDesignSystem.cardRadius,
        onTap: () {
          if (!n.isRead) _markRead(n.id);
          _showDetail(n);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForType(n.notificationType),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: AppDesignSystem.bodyMedium.copyWith(
                        fontWeight: n.isRead
                            ? FontWeight.w400
                            : FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      style: AppDesignSystem.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: AppDesignSystem.caption.copyWith(
                        color: AppDesignSystem.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!n.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppDesignSystem.secondaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(AppNotification n) {
    final formatted = DateFormat('MMMM d, yyyy  •  h:mm a').format(n.sentAt);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesignSystem.radiusLG),
        ),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppDesignSystem.borderLight,
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusFull,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  _iconForType(n.notificationType),
                  color: _colorForType(n.notificationType),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    n.title,
                    style: AppDesignSystem.heading4.copyWith(
                      color: AppDesignSystem.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(formatted, style: AppDesignSystem.caption),
            const SizedBox(height: 16),
            Text(n.body, style: AppDesignSystem.bodyMedium),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
