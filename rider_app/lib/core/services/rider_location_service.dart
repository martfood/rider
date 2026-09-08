import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

class RiderLocationService {
  RiderLocationService._();
  static final RiderLocationService instance = RiderLocationService._();

  StreamSubscription<Position>? _positionStreamSub;
  Position? _lastKnownPosition;
  bool _isTracking = false;

  bool get isTracking => _isTracking;
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Verifies and requests location permission. Returns true if granted.
  Future<bool> requestPermission(BuildContext context) async {
    // 1. Check if GPS / Location services are enabled on device
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        await _showLocationServiceDisabledSheet(context);
      }
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
    }

    // 2. Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          _showPermissionDeniedSheet(context, permanentlyDenied: false);
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showPermissionDeniedSheet(context, permanentlyDenied: true);
      }
      return false;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Fast check to verify whether location permissions are currently granted.
  Future<bool> hasPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Alias for hasPermission
  Future<bool> checkPermission() => hasPermission();

  /// Fetches current GPS location immediately and updates Firestore.
  Future<Position?> updateCurrentPosition() async {
    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _lastKnownPosition = position;
      await _syncPositionToFirestore(position);
      return position;
    } catch (e) {
      debugPrint('[RiderLocationService] Error fetching current position: $e');
      return null;
    }
  }

  /// Starts continuous location stream to update Firestore in real time while online.
  Future<void> startLiveTracking() async {
    if (_isTracking) return;

    final hasPerm = await hasPermission();
    if (!hasPerm) return;

    _isTracking = true;

    // First fetch immediate position
    await updateCurrentPosition();

    // Setup high-accuracy real-time stream
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Updates every 10 meters of movement
    );

    _positionStreamSub?.cancel();
    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _lastKnownPosition = position;
        _syncPositionToFirestore(position);
      },
      onError: (error) {
        debugPrint('[RiderLocationService] Stream error: $error');
      },
      cancelOnError: false,
    );
  }

  /// Stops streaming location when rider goes offline.
  void stopLiveTracking() {
    _isTracking = false;
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
  }

  /// Syncs position directly to the rider's Firestore profile and presence documents.
  Future<void> _syncPositionToFirestore(Position position) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final geoPoint = GeoPoint(position.latitude, position.longitude);
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update rider profile
      final riderRef = FirebaseFirestore.instance.collection('riders').doc(uid);
      batch.set(riderRef, {
        'currentLocation': geoPoint,
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Update rider presence
      final presenceRef =
          FirebaseFirestore.instance.collection('rider_presence').doc(uid);
      batch.set(presenceRef, {
        'location': geoPoint,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('[RiderLocationService] Error syncing position to Firestore: $e');
    }
  }

  /// Styled Bottom Sheet when device GPS / Location service is turned OFF
  Future<void> _showLocationServiceDisabledSheet(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedText = AppTheme.mutedTextColorFor(isDark);
    final purple = AppTheme.primaryPurpleFor(isDark);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.hintColorFor(isDark).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 24.h),
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.mapPinOff,
                  color: purple,
                  size: 30.sp,
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                'Device Location is Disabled',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'MartFood Rider requires active GPS location to detect your position, receive nearby delivery dispatches, and guide your pickup routes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  color: mutedText,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(sheetCtx).pop();
                  await Geolocator.openLocationSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: Size(double.infinity, 54.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                child: Text(
                  'Open Location Settings',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: mutedText,
                  minimumSize: Size(double.infinity, 44.h),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Styled Bottom Sheet when location permission is denied or denied permanently
  void _showPermissionDeniedSheet(BuildContext context,
      {required bool permanentlyDenied}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedText = AppTheme.mutedTextColorFor(isDark);
    final purple = AppTheme.primaryPurpleFor(isDark);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.hintColorFor(isDark).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 24.h),
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.navigation,
                  color: purple,
                  size: 30.sp,
                ),
              ),
              SizedBox(height: 18.h),
              Text(
                'Location Permission Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.headlineSmall),
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                permanentlyDenied
                    ? 'Location permission was previously declined. Please grant "Always" or "While Using App" location access in device Settings so you can come online and accept deliveries.'
                    : 'To come online and receive delivery dispatches from nearby restaurants, MartFood Rider needs permission to access your location.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  color: mutedText,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(sheetCtx).pop();
                  if (permanentlyDenied) {
                    await Geolocator.openAppSettings();
                  } else {
                    await Geolocator.requestPermission();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: Size(double.infinity, 54.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                child: Text(
                  permanentlyDenied ? 'Open App Settings' : 'Grant Permission',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: mutedText,
                  minimumSize: Size(double.infinity, 44.h),
                ),
                child: Text(
                  'Dismiss',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
