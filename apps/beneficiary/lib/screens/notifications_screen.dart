import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_design_system.dart';
import '../l10n/app_localizations.dart';
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
    final loc = AppLocalizations.of(context)!;
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
            _error = result.errorMessage ?? loc.notificationsErrorFallback;
            _notifications = [];
          }
        });
      }
    } catch (e) {
      // Was showing the raw exception text ('Error: $e') directly to the
      // user — could surface something like "SocketException: Failed
      // host lookup", not appropriate for this audience. Logged for
      // developers instead; the user gets a plain, friendly message.
      debugPrint('NotificationsScreen._load failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = loc.notificationsErrorGeneric;
          _notifications = [];
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.getNotifications(page: _page, limit: 30);
      if (!mounted) return;

      // FIX: previously checked `result != null`, but getNotifications
      // returns a non-nullable result (see _load's use of
      // result.success above) — that check was always true, so a
      // failed paginated request silently fell through without ever
      // setting _hasMore = false. That meant the scroll listener kept
      // calling _loadMore() again on every further scroll, repeatedly
      // hitting the same failing endpoint. Now mirrors _load()'s
      // success check.
      if (result.success) {
        setState(() {
          _isLoading = false;
          _notifications!.addAll(result.notifications);
          _hasMore = _notifications!.length < result.total;
          _page++;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.notificationsLoadMoreError)),
          );
        }
      }
    } catch (e) {
      debugPrint('NotificationsScreen._loadMore failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.notificationsLoadMoreError)));
      }
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
    HapticFeedback.mediumImpact();
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
        return AppDesignSystem.interactiveBlue;
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
    final loc = AppLocalizations.of(context)!;

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
              // Was unstyled (ambient default TextStyle) — every other
              // screen's error text goes through AppDesignSystem.
              Text(
                _error!,
                style: AppDesignSystem.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Was a completely unstyled bare ElevatedButton — no
              // AppDesignSystem style, no explicit touch-target height.
              SizedBox(
                height: AppDesignSystem.touchTargetMin,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _load();
                  },
                  style: AppDesignSystem.primaryButton,
                  child: Text(loc.notificationsRetryButton),
                ),
              ),
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
              child: SizedBox(
                // Was default TextButton sizing (unset height) — under
                // this system's 56dp touch-target floor.
                height: AppDesignSystem.touchTargetMin,
                child: TextButton.icon(
                  onPressed: _markAllRead,
                  icon: const Icon(
                    Icons.done_all,
                    size: 18,
                    color: AppDesignSystem.interactiveBlue,
                  ),
                  label: Text(
                    loc.notificationsMarkAllRead,
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: AppDesignSystem.interactiveBlue,
                      fontWeight: FontWeight.w600,
                    ),
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
                ? _buildEmpty(loc)
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
                      return _buildTile(list[i], loc);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(AppLocalizations loc) {
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
                  color: AppDesignSystem.textHint,
                ),
                const SizedBox(height: AppDesignSystem.spaceSM),
                Text(
                  loc.notificationsEmptyTitle,
                  style: AppDesignSystem.bodyMedium,
                ),
                const SizedBox(height: AppDesignSystem.spaceXS),
                Text(
                  loc.notificationsEmptySubtitle,
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: AppDesignSystem.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(AppNotification n, AppLocalizations loc) {
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
            : Border.all(
                color: AppDesignSystem.interactiveBlue.withOpacity(0.3),
              ),
      ),
      child: Semantics(
        // The unread state was only conveyed visually (bold text +
        // background tint + dot) — none of that reaches a screen
        // reader without an explicit label.
        label: n.isRead ? n.title : '${n.title}. Unread.',
        button: true,
        child: InkWell(
          borderRadius: AppDesignSystem.cardRadius,
          onTap: () {
            HapticFeedback.selectionClick();
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
                          color: AppDesignSystem.textHint,
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
                      color: AppDesignSystem.interactiveBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(AppNotification n) {
    final formatted = DateFormat(
      'MMMM d, yyyy  •  h:mm a', // was 'â€¢' — mojibake fix
    ).format(n.sentAt);

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
