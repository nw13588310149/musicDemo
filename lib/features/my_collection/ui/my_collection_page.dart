import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/my_collection_controller.dart';
import '../state/my_collection_state.dart';

class MyCollectionPage extends ConsumerWidget {
  const MyCollectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myCollectionControllerProvider);
    final controller = ref.read(myCollectionControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(16)),
          ),
          padding: EdgeInsets.fromLTRB(ui(18), ui(18), ui(18), ui(18)),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: ui(10),
                  runSpacing: ui(10),
                  children: state.tabs.map((item) {
                    final active = item.type == state.activeType;
                    return InkWell(
                      borderRadius: BorderRadius.circular(ui(12)),
                      onTap: () => controller.selectType(item.type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(18),
                          vertical: ui(10),
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : const Color(0xFFF4F6FD),
                          borderRadius: BorderRadius.circular(ui(12)),
                          boxShadow: active
                              ? const [
                                  BoxShadow(
                                    color: Color(0x16000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: ui(14),
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: active
                                ? const Color(0xFF16141F)
                                : const Color(0xFF757B8C),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: ui(18)),
              Expanded(
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : state.items.isEmpty
                    ? const _CollectionEmpty()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isVideo = state.activeType == 6;
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: isVideo
                                      ? ui(220)
                                      : ui(220),
                                  mainAxisExtent: isVideo ? ui(184) : ui(102),
                                  mainAxisSpacing: ui(14),
                                  crossAxisSpacing: ui(14),
                                ),
                            itemCount: state.items.length,
                            itemBuilder: (context, index) {
                              final item = state.items[index];
                              if (item.isVideo) {
                                return _VideoCollectionCard(
                                  item: item,
                                  onShare: () => _openShare(context, ref, item),
                                  onRemove: () =>
                                      _removeItem(context, ref, item),
                                );
                              }
                              return _CourseCollectionCard(
                                item: item,
                                paletteIndex: index,
                                onShare: () => _openShare(context, ref, item),
                                onRemove: () => _removeItem(context, ref, item),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        if (state.busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x22000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (state.shareTarget != null)
          Positioned.fill(
            child: _ShareSheet(
              state: state,
              onClose: controller.closeShare,
              onToggle: controller.toggleShareClass,
              onSend: () async {
                final message = await controller.sendShare();
                if (context.mounted) {
                  _showMessage(context, message ?? '分享成功');
                }
              },
            ),
          ),
      ],
    );
  }

  Future<void> _openShare(
    BuildContext context,
    WidgetRef ref,
    CollectionEntry item,
  ) async {
    final message = await ref
        .read(myCollectionControllerProvider.notifier)
        .openShare(item);
    if (context.mounted && message != null) {
      _showMessage(context, message);
    }
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    CollectionEntry item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消收藏'),
        content: Text('确定将“${item.title}”从收藏中移除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final message = await ref
        .read(myCollectionControllerProvider.notifier)
        .removeFavorite(item);
    if (context.mounted) {
      _showMessage(context, message ?? '已取消收藏');
    }
  }

  void _showMessage(BuildContext context, String message) {
    AppToast.show(context, message);
  }
}

class _CourseCollectionCard extends StatelessWidget {
  const _CourseCollectionCard({
    required this.item,
    required this.paletteIndex,
    required this.onShare,
    required this.onRemove,
  });

  final CollectionEntry item;
  final int paletteIndex;
  final VoidCallback onShare;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final accent =
        kCollectionAccentPalette[paletteIndex %
            kCollectionAccentPalette.length];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(ui(14)),
      ),
      padding: EdgeInsets.all(ui(10)),
      child: Row(
        children: [
          Container(
            width: ui(54),
            height: ui(68),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ui(10)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accent, accent.withValues(alpha: 0.72)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: ui(10),
                  top: ui(10),
                  right: ui(10),
                  child: Text(
                    item.type == 3 ? '听\n写\n单\n音' : '第\n一\n课',
                    style: TextStyle(
                      fontSize: ui(9),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8B5CFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(15),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF151320),
                  ),
                ),
                SizedBox(height: ui(6)),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: const Color(0xFFA0A6B7),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        minimumSize: Size(ui(58), ui(30)),
                        backgroundColor: const Color(0xFF121021),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ui(10)),
                        ),
                      ),
                      child: Text('去学习', style: TextStyle(fontSize: ui(12))),
                    ),
                    const Spacer(),
                    _MiniActionButton(
                      icon: Icons.share_outlined,
                      onTap: onShare,
                    ),
                    SizedBox(width: ui(6)),
                    _MiniActionButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: onRemove,
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
}

class _VideoCollectionCard extends StatelessWidget {
  const _VideoCollectionCard({
    required this.item,
    required this.onShare,
    required this.onRemove,
  });

  final CollectionEntry item;
  final VoidCallback onShare;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final avatarImage = _buildAvatarImage(item.avatarUrl);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(ui(16)),
                topRight: Radius.circular(ui(16)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildVideoCover(item.coverUrl),
                  Positioned(
                    right: ui(10),
                    bottom: ui(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui(8),
                        vertical: ui(4),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(ui(999)),
                      ),
                      child: Text(
                        item.durationText,
                        style: TextStyle(fontSize: ui(11), color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(ui(10), ui(8), ui(10), ui(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(15),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF171A20),
                  ),
                ),
                SizedBox(height: ui(6)),
                Row(
                  children: [
                    CircleAvatar(
                      radius: ui(10),
                      backgroundColor: const Color(0xFFE5EAF7),
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              _leadingCharacter(item.authorName),
                              style: TextStyle(fontSize: ui(10)),
                            )
                          : null,
                    ),
                    SizedBox(width: ui(6)),
                    Expanded(
                      child: Text(
                        item.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(12),
                          color: const Color(0xFF71798C),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.bar_chart_rounded,
                      size: ui(14),
                      color: const Color(0xFF9BA3B7),
                    ),
                    SizedBox(width: ui(2)),
                    Text(
                      item.metricText,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: const Color(0xFF9BA3B7),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ui(8)),
                Row(
                  children: [
                    _MiniActionButton(
                      icon: Icons.share_outlined,
                      onTap: onShare,
                    ),
                    SizedBox(width: ui(8)),
                    _MiniActionButton(
                      icon: Icons.delete_outline_rounded,
                      onTap: onRemove,
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
}

Widget _buildVideoCover(String rawUrl) {
  final resolvedUrl = _resolveRemoteUrl(rawUrl);
  if (resolvedUrl == null) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF30204D), Color(0xFFB8702A)],
        ),
      ),
    );
  }
  return Image.network(
    resolvedUrl,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF30204D), Color(0xFFB8702A)],
        ),
      ),
    ),
  );
}

ImageProvider<Object>? _buildAvatarImage(String rawUrl) {
  final resolvedUrl = _resolveRemoteUrl(rawUrl);
  if (resolvedUrl == null) {
    return null;
  }
  return NetworkImage(resolvedUrl);
}

String? _resolveRemoteUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty || value.toLowerCase() == 'string') {
    return null;
  }
  final resolved = MediaUrl.resolve(value);
  return resolved.isEmpty ? null : resolved;
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(10)),
      child: Container(
        width: ui(30),
        height: ui(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(10)),
          border: Border.all(color: const Color(0xFFE8ECF7)),
        ),
        child: Icon(icon, size: ui(16), color: const Color(0xFF5D6476)),
      ),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    required this.state,
    required this.onClose,
    required this.onToggle,
    required this.onSend,
  });

  final MyCollectionState state;
  final VoidCallback onClose;
  final ValueChanged<int> onToggle;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ColoredBox(
      color: const Color(0x66000000),
      child: Center(
        child: Container(
          width: ui(420),
          padding: EdgeInsets.all(ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '分享到班级',
                    style: TextStyle(
                      fontSize: ui(20),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              SizedBox(height: ui(6)),
              Text(
                state.shareTarget?.title ?? '',
                style: TextStyle(
                  fontSize: ui(14),
                  color: const Color(0xFF7D8396),
                ),
              ),
              SizedBox(height: ui(16)),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: ui(260)),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.shareClasses.length,
                  separatorBuilder: (context, index) => SizedBox(height: ui(8)),
                  itemBuilder: (context, index) {
                    final item = state.shareClasses[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(ui(12)),
                      onTap: () => onToggle(item.id),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(14),
                          vertical: ui(12),
                        ),
                        decoration: BoxDecoration(
                          color: item.selected
                              ? const Color(0xFFF1ECFF)
                              : const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(ui(12)),
                          border: Border.all(
                            color: item.selected
                                ? const Color(0xFF8B5CFF)
                                : const Color(0xFFE7EBF7),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.groups_rounded),
                            SizedBox(width: ui(10)),
                            Expanded(child: Text(item.name)),
                            Icon(
                              item.selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: item.selected
                                  ? const Color(0xFF8B5CFF)
                                  : const Color(0xFFA0A6B7),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ui(18)),
              SizedBox(
                width: double.infinity,
                height: ui(44),
                child: FilledButton(
                  onPressed: onSend,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CFF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('发送'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _leadingCharacter(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.substring(0, 1);
}

class _CollectionEmpty extends StatelessWidget {
  const _CollectionEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(92),
            height: ui(92),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FD),
              borderRadius: BorderRadius.circular(ui(24)),
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: ui(44),
              color: const Color(0xFF8B5CFF),
            ),
          ),
          SizedBox(height: ui(18)),
          Text(
            '收藏夹还是空的',
            style: TextStyle(
              fontSize: ui(22),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF171A20),
            ),
          ),
          SizedBox(height: ui(8)),
          Text(
            '去挑一些常用课程、视频或资料收藏起来吧。',
            style: TextStyle(fontSize: ui(14), color: const Color(0xFF9097AA)),
          ),
        ],
      ),
    );
  }
}
