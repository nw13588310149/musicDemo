import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppAssetGraphic extends StatelessWidget {
  const AppAssetGraphic(
    this.asset, {
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.colorFilter,
    super.key,
  });

  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ColorFilter? colorFilter;

  Widget _buildMissing() {
    return SizedBox(width: width, height: height);
  }

  Widget _buildRaster({required bool allowSvgFallback}) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: allowSvgFallback
          ? (context, error, stackTrace) =>
                _buildVector(allowRasterFallback: false)
          : (context, error, stackTrace) => _buildMissing(),
    );
  }

  Widget _buildVector({required bool allowRasterFallback}) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      colorFilter: colorFilter,
      errorBuilder: allowRasterFallback
          ? (context, error, stackTrace) =>
                _buildRaster(allowSvgFallback: false)
          : (context, error, stackTrace) => _buildMissing(),
    );
  }

  static bool isVectorAsset(String asset) {
    if (asset.endsWith('.svg')) {
      return true;
    }

    if (asset.contains('/shell/nav_v2/') ||
        asset.contains('/shell/topbar_v2/')) {
      return true;
    }

    if (asset.contains('/home/v2/') && !asset.endsWith('/banner_guitar.png')) {
      return true;
    }

    if (asset.contains('/aichat/') &&
        asset.endsWith('.png') &&
        asset.contains('_v2_')) {
      return true;
    }

    const authVectorPngs = <String>{
      'assets/images/auth/v2_bg_shape.png',
      'assets/images/auth/v2_ellipse_big.png',
      'assets/images/auth/v2_ellipse_small.png',
      'assets/images/auth/v2_icon_password.png',
      'assets/images/auth/v2_icon_phone.png',
    };
    return authVectorPngs.contains(asset);
  }

  @override
  Widget build(BuildContext context) {
    if (isVectorAsset(asset)) {
      return _buildVector(allowRasterFallback: true);
    }
    return _buildRaster(allowSvgFallback: true);
  }
}
