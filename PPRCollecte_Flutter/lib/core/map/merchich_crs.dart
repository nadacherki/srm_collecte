import 'dart:math' as math;
import 'dart:math' show Point;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/basemap_constants.dart';
import '../../models/merchich_point.dart';

/// FlutterMap CRS for EPSG:26191 packages that are already tiled in Merchich.
///
/// At the FlutterMap boundary, LatLng is only a technical carrier:
/// encoded latitude = northing (Y) / [MerchichPoint.flutterLatLngCarrierScale],
/// encoded longitude = easting (X) / [MerchichPoint.flutterLatLngCarrierScale].
class MerchichCrs extends Crs {
  final List<double> resolutions;
  final double originX;
  final double originY;
  @override
  final Projection projection;

  MerchichCrs({
    this.resolutions = BasemapConstants.defaultMerchichResolutions,
    this.originX = BasemapConstants.defaultMerchichOriginX,
    this.originY = BasemapConstants.defaultMerchichOriginY,
    Bounds<double>? bounds,
  })  : projection = MerchichProjection(bounds),
        super(
          code: 'EPSG:26191',
          infinite: bounds == null,
        );

  @override
  double scale(double zoom) {
    final clampedMin = math.max(0, zoom);
    final lastZoom = resolutions.length - 1;
    if (clampedMin >= lastZoom) {
      final lastScale = 1 / resolutions[lastZoom];
      if (resolutions.length == 1) return lastScale;
      final previousScale = 1 / resolutions[lastZoom - 1];
      final overzoomFactor =
          lastScale > previousScale ? lastScale / previousScale : 2.0;
      return lastScale *
          math.pow(overzoomFactor, clampedMin - lastZoom).toDouble();
    }

    final iZoom = clampedMin.floor();
    final baseScale = 1 / resolutions[iZoom];
    if (clampedMin == iZoom) {
      return baseScale;
    }
    final nextScale = 1 / resolutions[iZoom + 1];
    return baseScale + ((nextScale - baseScale) * (clampedMin - iZoom));
  }

  @override
  double zoom(double scale) {
    final scales = resolutions.map((r) => 1 / r).toList(growable: false);
    for (var i = 0; i < scales.length - 1; i++) {
      if (scale >= scales[i] && scale <= scales[i + 1]) {
        final diff = scales[i + 1] - scales[i];
        return i + ((scale - scales[i]) / diff);
      }
    }
    if (scale < scales.first || scales.length == 1) return 0;

    final lastZoom = scales.length - 1;
    final previousScale = scales[lastZoom - 1];
    final lastScale = scales[lastZoom];
    final overzoomFactor =
        lastScale > previousScale ? lastScale / previousScale : 2.0;
    return lastZoom + (math.log(scale / lastScale) / math.log(overzoomFactor));
  }

  @override
  (double, double) transform(double x, double y, double scale) {
    return ((x - originX) * scale, (originY - y) * scale);
  }

  @override
  (double, double) untransform(double x, double y, double scale) {
    return ((x / scale) + originX, originY - (y / scale));
  }

  @override
  (double, double) latLngToXY(LatLng latlng, double scale) {
    final p = MerchichPoint.decodeFlutterLatLng(latlng);
    return transform(p.x, p.y, scale);
  }

  @override
  LatLng pointToLatLng(Point point, double zoom) {
    final (x, y) = untransform(
      point.x.toDouble(),
      point.y.toDouble(),
      scale(zoom),
    );
    return MerchichPoint.encodeFlutterLatLng(x: x, y: y);
  }

  @override
  Bounds<double>? getProjectedBounds(double zoom) {
    final bounds = projection.bounds;
    if (bounds == null) return null;
    final s = scale(zoom);
    final (minX, minY) = transform(bounds.min.x, bounds.max.y, s);
    final (maxX, maxY) = transform(bounds.max.x, bounds.min.y, s);
    return Bounds<double>(
      Point<double>(math.min(minX, maxX), math.min(minY, maxY)),
      Point<double>(math.max(minX, maxX), math.max(minY, maxY)),
    );
  }
}

class MerchichProjection extends Projection {
  const MerchichProjection(super.bounds);

  @override
  (double, double) projectXY(LatLng latlng) {
    final p = MerchichPoint.decodeFlutterLatLng(latlng);
    return (p.x, p.y);
  }

  @override
  LatLng unprojectXY(double x, double y) {
    return MerchichPoint.encodeFlutterLatLng(x: x, y: y);
  }
}
