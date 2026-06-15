import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../services/baidu_geo_service.dart';

/// iOS / Android：静态百度地图底图 + 落点，避免 WKWebView Referer 白名单问题。
class BaiduMapView extends StatefulWidget {
  const BaiduMapView({
    super.key,
    required this.lat,
    required this.lng,
    this.label,
    this.zoom = 17,
    this.onAddressResolved,
    this.borderRadius,
  });

  final double? lat;
  final double? lng;
  final String? label;
  final int zoom;
  final ValueChanged<String>? onAddressResolved;
  final BorderRadius? borderRadius;

  @override
  State<BaiduMapView> createState() => _BaiduMapViewState();
}

class _BaiduMapViewState extends State<BaiduMapView> {
  String? _lastGeocodeKey;

  @override
  void initState() {
    super.initState();
    _maybeGeocode();
  }

  @override
  void didUpdateWidget(covariant BaiduMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) {
      _maybeGeocode();
    }
  }

  Future<void> _maybeGeocode() async {
    final lat = widget.lat;
    final lng = widget.lng;
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return;

    final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    if (_lastGeocodeKey == key) return;
    _lastGeocodeKey = key;

    final address = await BaiduGeoService.reverseGeocode(lat: lat, lng: lng);
    if (!mounted || address == null || address.isEmpty) return;
    widget.onAddressResolved?.call(address);
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.lat;
    final lng = widget.lng;
    final hasPoint =
        lat != null && lng != null && lat.isFinite && lng.isFinite;
    final radius = widget.borderRadius;

    Widget child;
    if (!hasPoint) {
      child = const ColoredBox(
        color: Color(0xFFEFF3FC),
        child: Center(
          child: Text(
            '暂无定位',
            style: TextStyle(color: Color(0xFFB6B5BB), fontSize: 13),
          ),
        ),
      );
    } else {
      final pointLat = lat;
      final pointLng = lng;
      child = LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth.ceil()
              : 800;
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight.ceil()
              : 600;
          return FutureBuilder<Uint8List?>(
            key: ValueKey(
              '${pointLat.toStringAsFixed(5)},${pointLng.toStringAsFixed(5)},'
              '$width,$height,${widget.zoom}',
            ),
            future: BaiduGeoService.fetchStaticMapImage(
              lat: pointLat,
              lng: pointLng,
              width: width,
              height: height,
              zoom: widget.zoom,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const ColoredBox(
                  color: Color(0xFFEFF3FC),
                  child: Center(child: AppLoadingIndicator()),
                );
              }
              final bytes = snapshot.data;
              if (bytes != null) {
                return Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                );
              }
              return ColoredBox(
                color: const Color(0xFFEFF3FC),
                child: Center(
                  child: Text(
                    '地图加载失败\n${pointLat.toStringAsFixed(5)}, ${pointLng.toStringAsFixed(5)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB6B5BB),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    if (radius == null) return child;
    return ClipRRect(borderRadius: radius, child: child);
  }
}
