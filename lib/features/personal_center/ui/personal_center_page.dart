import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../shell/state/shell_controller.dart';
import '../state/personal_center_controller.dart';
import '../state/personal_center_state.dart';

/// 与 1.0 `pages/PersonalCenter/index.vue` 中 `APP_PROMO_URL` 一致。
const _kAppPromoUrl = 'https://apps.apple.com/cn/app/音乐之路/id6504698046';

class PersonalCenterPage extends ConsumerStatefulWidget {
  const PersonalCenterPage({super.key});

  @override
  ConsumerState<PersonalCenterPage> createState() => _PersonalCenterPageState();
}

class _PersonalCenterPageState extends ConsumerState<PersonalCenterPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personalCenterControllerProvider);
    final controller = ref.read(personalCenterControllerProvider.notifier);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: controller.refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHero(
              state: state,
              controller: controller,
              onEditProfile: () =>
                  Navigator.pushNamed(context, RoutePaths.info),
            ),
            const SizedBox(height: 16),
            _ActionListCard(
              checkStatusEnabled: state.checkStatusEnabled,
              onQr: () => _onMyQr(context, controller, state),
              onRecommend: () => _onRecommend(context),
              onFeedback: () => Navigator.pushNamed(context, RoutePaths.fankui),
              onService: () => Navigator.pushNamed(context, RoutePaths.email),
              onRedeem: state.checkStatusEnabled
                  ? () => _onRedeem(context, controller)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMyQr(
    BuildContext context,
    PersonalCenterController controller,
    PersonalCenterState state,
  ) async {
    final result = await controller.fetchQrImageUrl();
    if (!context.mounted) {
      return;
    }
    if (result.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => _QrCodeDialog(
        nickname: state.user['nickname']?.toString() ?? '用户',
        roleLabel: _roleLabel(state.user['role']?.toString()),
        mobile: state.user['mobile']?.toString() ?? '',
        imageUrl: result.url!,
      ),
    );
  }

  void _onRecommend(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('复制推广链接'),
              onTap: () async {
                await Clipboard.setData(
                  const ClipboardData(text: _kAppPromoUrl),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('链接已复制，快去发给好友吧')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRedeem(
    BuildContext context,
    PersonalCenterController controller,
  ) async {
    final codeController = TextEditingController();
    String? err;
    try {
      err = await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('VIP 兑换'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              hintText: '请输入兑换码',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, codeController.text),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } finally {
      codeController.dispose();
    }
    if (!context.mounted || err == null) {
      return;
    }
    final msg = await controller.redeemVip(err);
    if (!context.mounted) {
      return;
    }
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else {
      await ref.read(shellControllerProvider.notifier).refreshUserAndSchool();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('兑换成功')));
    }
  }
}

String _roleLabel(String? role) {
  switch (role) {
    case 'teacher':
      return '老师';
    case 'student':
      return '学生';
    default:
      return '游客';
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.state,
    required this.controller,
    required this.onEditProfile,
  });

  final PersonalCenterState state;
  final PersonalCenterController controller;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final days = controller.vipDaysRemaining();
    final showAnnualBadge =
        state.checkStatusEnabled && days != null && days >= 1;
    final pkg0 = state.vipPackages.isNotEmpty ? state.vipPackages[0] : null;
    final pkg1 = state.vipPackages.length > 1 ? state.vipPackages[1] : null;

    final nick = state.user['nickname']?.toString().trim() ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final headerH = w * 240.0 / 970.0;
        final minContentH = state.checkStatusEnabled ? 248.0 : 132.0;
        final stackH = math.max(headerH, minContentH);

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: stackH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  height: headerH,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        AppAssets.infoBg,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              const Color(0xFFFAF8FD).withValues(alpha: 0.88),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: headerH,
                  right: 0,
                  bottom: 0,
                  child: const ColoredBox(color: Color(0xFFFAF8FD)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Avatar(url: state.user['headUrl']?.toString()),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      fit: FlexFit.loose,
                                      child: Text(
                                        nick.isNotEmpty ? nick : '未命名',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF0B081A),
                                          fontFamily: 'PingFang SC',
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: onEditProfile,
                                      behavior: HitTestBehavior.opaque,
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: ClipRect(
                                          child: Image.asset(
                                            AppAssets.infoPencilLine,
                                            width: 16,
                                            height: 16,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (showAnnualBadge) ...[
                                      const SizedBox(width: 8),
                                      const _AnnualVipBadge(),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  state.user['mobile']?.toString() ?? '',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF6D6B75),
                                    fontFamily: 'PingFang SC',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (state.checkStatusEnabled) const Spacer(),
                      if (state.checkStatusEnabled)
                        Row(
                          children: [
                            Expanded(
                              child: _VipPriceCard(
                                annualLayout: true,
                                title: pkg0?.name ?? '年卡365天',
                                subtitle: pkg0?.description ?? '每月仅需116.5元',
                                price: pkg0?.price ?? '1,398',
                                trailingLabel: days != null && days > 3
                                    ? '已开通'
                                    : null,
                                showPrice: days == null || days <= 3,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _VipPriceCard(
                                annualLayout: false,
                                title: pkg1?.name ?? '3天体验卡',
                                subtitle: pkg1?.description ?? '每天仅需6.6元',
                                price: pkg1?.price ?? '198',
                                trailingLabel: days != null && days >= 1
                                    ? '已开通'
                                    : null,
                                showPrice: days == null || days < 1,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _WalletPointsCard(
                                wallet: state.walletText,
                                points: state.pointsText,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim() ?? '';
    final network =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    const ring = 2.0;
    const total = 88.0;
    final inner = total - 2 * ring;
    final fallback = Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFE7ECFA), Color(0xFFD9E1F6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 44,
        color: Color(0xFF7E879C),
      ),
    );
    return SizedBox(
      width: total,
      height: total,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          Center(
            child: ClipOval(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: SizedBox(
                width: inner,
                height: inner,
                child: network
                    ? Image.network(
                        trimmed,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) => fallback,
                      )
                    : fallback,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「年卡会员」角标（设计稿绝对布局：73×22 渐变条 + 左侧 24×24 装饰 + 文案位置）。
class _AnnualVipBadge extends StatelessWidget {
  const _AnnualVipBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 7,
            top: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB864FA), Color(0xFF8741FF)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(21),
                  bottomRight: Radius.circular(21),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: const Color(0xFF9B6EFA), width: 1),
              ),
              child: const SizedBox(width: 73, height: 22),
            ),
          ),
          Positioned(
            left: -2,
            top: 0,
            child: SizedBox(width: 24, height: 24, child: _VipBadgeIcon()),
          ),
          const Positioned(
            left: 24,
            top: 4,
            child: Text(
              '年卡会员',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Alibaba PuHuiTi 2.0',
                fontWeight: FontWeight.w700,
                height: 16 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 设计稿左侧多层效果用 `vip.png` 一图近似。
class _VipBadgeIcon extends StatelessWidget {
  const _VipBadgeIcon();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.infoVip,
      fit: BoxFit.contain,
      alignment: Alignment.center,
    );
  }
}

class _VipPriceCard extends StatelessWidget {
  const _VipPriceCard({
    required this.annualLayout,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.showPrice,
    this.trailingLabel,
  });

  final bool annualLayout;
  final String title;
  final String subtitle;
  final String price;
  final bool showPrice;
  final String? trailingLabel;

  static final LinearGradient _annualGradient = LinearGradient(
    transform: GradientRotation(146 * math.pi / 180),
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: const [
      Color(0xFFE8DCFF),
      Color(0xFFF8F5FF),
      Color(0xFFE8DCFF),
      Color(0xFFE8DCFF),
      Color(0xFFEBE1FF),
      Color(0xFFD7C3FF),
    ],
    stops: const [0.0, 0.25, 0.38, 0.60, 0.69, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    if (annualLayout) {
      final priceText = price.startsWith('¥') || price.startsWith('\u00a5')
          ? price
          : '¥$price';
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 100,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: _annualGradient,
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF170333),
                            fontFamily: 'Alimama ShuHeiTi',
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF6D6B75),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showPrice)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        priceText,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF170333),
                          fontFamily: 'Barlow',
                          height: 1,
                        ),
                      ),
                    ),
                  if (!showPrice && trailingLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8741FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          trailingLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.72), Colors.white],
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF170333),
                  fontFamily: 'PingFang SC',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6D6B75),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ),
          if (showPrice)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  price.startsWith('¥') || price.startsWith('\u00a5')
                      ? price
                      : '¥$price',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF170333),
                    fontFamily: 'Barlow',
                  ),
                ),
              ),
            ),
          if (!showPrice && trailingLabel != null)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8741FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trailingLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WalletPointsCard extends StatelessWidget {
  const _WalletPointsCard({required this.wallet, required this.points});

  final String wallet;
  final String points;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.72), Colors.white],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  wallet,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8741FF),
                    fontFamily: 'Barlow',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '我的钱包',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6D6B75),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: const Color(0xFFE6E8EB)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  points,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8741FF),
                    fontFamily: 'Barlow',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '我的积分',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6D6B75),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionListCard extends StatelessWidget {
  const _ActionListCard({
    required this.checkStatusEnabled,
    required this.onQr,
    required this.onRecommend,
    required this.onFeedback,
    required this.onService,
    this.onRedeem,
  });

  final bool checkStatusEnabled;
  final VoidCallback onQr;
  final VoidCallback onRecommend;
  final VoidCallback onFeedback;
  final VoidCallback onService;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ActionTile(
            iconAsset: AppAssets.infoIconQr,
            label: '我的二维码',
            onTap: onQr,
            showDivider: true,
          ),
          if (checkStatusEnabled)
            _ActionTile(
              iconAsset: AppAssets.infoIconRecommend,
              label: '推荐音乐之路给好友',
              onTap: onRecommend,
              showDivider: true,
            ),
          _ActionTile(
            iconAsset: AppAssets.infoIconFeedback,
            label: '意见反馈',
            onTap: onFeedback,
            showDivider: true,
          ),
          _ActionTile(
            iconAsset: AppAssets.infoIconService,
            label: '联系客服',
            onTap: onService,
            showDivider: checkStatusEnabled && onRedeem != null,
          ),
          if (checkStatusEnabled && onRedeem != null)
            _ActionTile(
              iconAsset: AppAssets.infoIconRedeem,
              label: '兑换中心',
              onTap: onRedeem!,
              showDivider: false,
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    required this.showDivider,
  });

  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Image.asset(
                      iconAsset,
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 22 / 14,
                          color: Color(0xFF0B081A),
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ),
                    Image.asset(
                      AppAssets.infoChevron,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
            if (showDivider)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE6E8EB)),
          ],
        ),
      ),
    );
  }
}

class _QrCodeDialog extends StatelessWidget {
  const _QrCodeDialog({
    required this.nickname,
    required this.roleLabel,
    required this.mobile,
    required this.imageUrl,
  });

  final String nickname;
  final String roleLabel;
  final String mobile;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final network =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    return AlertDialog(
      title: Text('$nickname的二维码'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCF7F0),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                '身份: $roleLabel',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '手机号: $mobile',
              style: const TextStyle(color: Color(0xFF888888)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 220,
              child: network
                  ? Image.network(imageUrl, fit: BoxFit.contain)
                  : const Icon(Icons.error_outline),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () {}, child: const Text('保存到相册（即将支持）')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
