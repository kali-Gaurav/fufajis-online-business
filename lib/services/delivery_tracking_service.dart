import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fleet_service.dart';
import 'package:flutter/foundation.dart';

class DeliveryTrackingService {
  static final DeliveryTrackingService _instance = DeliveryTrackingService._internal();
  factory DeliveryTrackingService() => _instance;
  DeliveryTrackingService._internal();

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'delivery_tracking',
        initialNotificationTitle: 'Delivery Tracking Active',
        initialNotificationContent: 'Updating your location to the customer',
        foregroundServiceType: AndroidForegroundType.location,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    await Firebase.initializeApp();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    service.on('startTracking').listen((event) {
      final String? deliveryId = event?['deliveryId'];
      if (deliveryId != null) {
        _startTrackingLocation(service, deliveryId);
      }
    });
  }

  static void _startTrackingLocation(ServiceInstance service, String deliveryId) {
    Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (service is AndroidServiceInstance) {
        if (!(await service.isForegroundService())) {
          timer.cancel();
          return;
        }
      }

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final FleetService fleetService = FleetService();
        await fleetService.updateDeliveryLocation(
          deliveryId: deliveryId,
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          heading: position.heading,
        );

        // Auto-mark "Arrived" if within 100 meters
        final deliveryDoc = await FirebaseFirestore.instance.collection('deliveries').doc(deliveryId).get();
        if (deliveryDoc.exists) {
          final data = deliveryDoc.data()!;
          if (data['status'] == 'on_the_way') {
            final dest = data['destinationLocation'] as GeoPoint;
            final double distance = Geolocator.distanceBetween(
              position.latitude, position.longitude,
              dest.latitude, dest.longitude
            );
            if (distance < 100) {
              await fleetService.markArrived(deliveryId);
            }
          }
        }

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Delivery Active",
            content: "Last updated: ${DateTime.now().hour}:${DateTime.now().minute}",
          );
        }
      } catch (e) {
        debugPrint("Error in background tracking: $e");
      }
    });
  }

  void startTracking(String deliveryId) {
    final service = FlutterBackgroundService();
    service.startService();
    service.invoke('startTracking', {'deliveryId': deliveryId});
  }

  void stopTracking() {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}
