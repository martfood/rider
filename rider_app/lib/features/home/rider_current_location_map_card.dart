import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import '../../core/services/rider_location_service.dart';

class RiderCurrentLocationMapCard extends StatefulWidget {
  final GeoPoint? riderLocation;
  final bool isOnline;

  const RiderCurrentLocationMapCard({
    super.key,
    required this.riderLocation,
    required this.isOnline,
  });

  @override
  State<RiderCurrentLocationMapCard> createState() =>
      _RiderCurrentLocationMapCardState();
}

class _RiderCurrentLocationMapCardState
    extends State<RiderCurrentLocationMapCard>
    with SingleTickerProviderStateMixin {
  String _addressText = 'Detecting current address...';
  bool _isLoadingAddress = false;
  int _currentZoom = 16;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _reverseGeocode();
  }

  @override
  void didUpdateWidget(covariant RiderCurrentLocationMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.riderLocation != null &&
        (oldWidget.riderLocation == null ||
            oldWidget.riderLocation!.latitude !=
                widget.riderLocation!.latitude ||
            oldWidget.riderLocation!.longitude !=
                widget.riderLocation!.longitude)) {
      _reverseGeocode();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode() async {
    final loc = widget.riderLocation;
    if (loc == null) {
      if (mounted) {
        setState(() {
          _addressText = 'Location unavailable (Turn on GPS)';
        });
      }
      return;
    }

    setState(() => _isLoadingAddress = true);

    try {
      const apiKey = "AIzaSyDUSy4tm9GTFNOCZZ5UXjGnEnPnFl1u2hI";
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${loc.latitude},${loc.longitude}&key=$apiKey',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final formatted = results[0]['formatted_address'] as String?;
          if (formatted != null && formatted.isNotEmpty && mounted) {
            setState(() {
              _addressText = formatted;
              _isLoadingAddress = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _addressText =
            'Lat: ${loc.latitude.toStringAsFixed(4)}°, Lng: ${loc.longitude.toStringAsFixed(4)}°';
        _isLoadingAddress = false;
      });
    }
  }

  String _getStaticMapUrl(double lat, double lng, int zoom, bool isDark) {
    const apiKey = "AIzaSyDUSy4tm9GTFNOCZZ5UXjGnEnPnFl1u2hI";
    final styleParam = isDark
        ? '&style=element:geometry%7Ccolor:0x212121'
            '&style=element:labels.icon%7Cvisibility:off'
            '&style=element:labels.text.fill%7Ccolor:0x757575'
            '&style=element:labels.text.stroke%7Ccolor:0x212121'
            '&style=feature:road%7Celement:geometry.fill%7Ccolor:0x2c2c2c'
            '&style=feature:road%7Celement:labels.text.fill%7Ccolor:0x8a8a8a'
            '&style=feature:water%7Celement:geometry%7Ccolor:0x171717'
        : '&style=feature:poi%7Cvisibility:off'
            '&style=feature:transit%7Cvisibility:simplified';

    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=$zoom'
        '&size=600x380'
        '&scale=2'
        '&maptype=roadmap'
        '&markers=color:0x803CA2%7Csize:mid%7C$lat,$lng'
        '$styleParam'
        '&key=$apiKey';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = AppTheme.mutedTextColorFor(isDark);
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    final loc = widget.riderLocation;
    final hasLocation = loc != null;
    final lat = hasLocation ? loc.latitude : 6.5244;
    final lng = hasLocation ? loc.longitude : 3.3792;
    final mapImageUrl = _getStaticMapUrl(lat, lng, _currentZoom, isDark);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Title + Live Status Badge + Recenter ─────────────
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: purpleColor.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.mapPin,
                    color: purpleColor,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Live Location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.font(15),
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time pinpoint for dispatch',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.font(AppFontSizes.bodySmall),
                        color: mutedTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Map Container ───────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 195,
              width: double.infinity,
              child: Stack(
                children: [
                  // High-Resolution Google Maps Roadmap
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: mapImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark
                            ? const Color(0xFF1F1F1F)
                            : const Color(0xFFE5E7EB),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: purpleColor,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark
                            ? const Color(0xFF1F1F1F)
                            : const Color(0xFFE5E7EB),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.mapPin,
                                  color: purpleColor, size: 28),
                              const SizedBox(height: 6),
                              Text(
                                'GPS Pinpoint Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Animated Glowing Radar Ring around pinpoint
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: purpleColor.withValues(alpha: 0.18),
                              border: Border.all(
                                color: purpleColor.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Pinpoint Center Marker
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: purpleColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            LucideIcons.bike,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Zoom Controls (Bottom Right)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black87 : Colors.white)
                            .withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              if (_currentZoom < 19) {
                                setState(() => _currentZoom += 1);
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              child: Icon(Icons.add, size: 16),
                            ),
                          ),
                          Container(width: 20, height: 1, color: borderColor),
                          InkWell(
                            onTap: () {
                              if (_currentZoom > 12) {
                                setState(() => _currentZoom -= 1);
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              child: Icon(Icons.remove, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating Enable GPS Button if location missing
                  if (!hasLocation)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            icon: const Icon(LucideIcons.mapPin, size: 16),
                            label: const Text(
                              'Enable GPS Pinpoint',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () async {
                              final granted = await RiderLocationService
                                  .instance
                                  .requestPermission(context);
                              if (granted) {
                                await RiderLocationService.instance
                                    .updateCurrentPosition();
                                _reverseGeocode();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Address Footer Banner ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkBorder.withValues(alpha: 0.35)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    LucideIcons.navigation,
                    size: 14,
                    color: purpleColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exact Pinpoint Address',
                        style: TextStyle(
                          fontSize: AppTypography.font(10),
                          fontWeight: FontWeight.w600,
                          color: mutedTextColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      _isLoadingAddress
                          ? Text(
                              'Locating address...',
                              style: TextStyle(
                                fontSize: AppTypography.font(12),
                                fontStyle: FontStyle.italic,
                                color: mutedTextColor,
                              ),
                            )
                          : Text(
                              _addressText,
                              style: TextStyle(
                                fontSize: AppTypography.font(12),
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                                height: 1.25,
                              ),
                            ),
                    ],
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
