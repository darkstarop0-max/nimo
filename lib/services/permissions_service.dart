import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();
  
  factory PermissionsService() => _instance;
  
  PermissionsService._internal();
  
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  
  /// Checks if storage permissions are granted
  Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true; // For desktop or web platforms
    }
    
    // For Android, we need to check different permissions based on SDK version
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 33) {
        // Android 13+ (API 33+)
        return await Permission.photos.isGranted && 
               await Permission.videos.isGranted && 
               await Permission.audio.isGranted;
      } else if (sdkInt >= 30) {
        // Android 11-12 (API 30-32)
        return await Permission.manageExternalStorage.isGranted;
      } else {
        // Android 10 and below
        return await Permission.storage.isGranted;
      }
    }
    
    // For iOS
    if (Platform.isIOS) {
      return await Permission.photos.isGranted && 
             await Permission.storage.isGranted;
    }
    
    return false;
  }
  
  /// Requests storage permissions based on platform and OS version
  /// Returns true if all required permissions are granted
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true; // For desktop or web platforms
    }
    
    // For Android, we need to request different permissions based on SDK version
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 33) {
        // Android 13+ (API 33+)
        Map<Permission, PermissionStatus> statuses = await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();
        
        bool allGranted = statuses.values.every((status) => status.isGranted);
        
        if (allGranted) {
          await _savePermissionStatus(true);
          return true;
        }
        
        return false;
      } else if (sdkInt >= 30) {
        // Android 11-12 (API 30-32)
        final status = await Permission.manageExternalStorage.request();
        
        if (status.isGranted) {
          await _savePermissionStatus(true);
          return true;
        }
        
        return false;
      } else {
        // Android 10 and below
        final status = await Permission.storage.request();
        
        if (status.isGranted) {
          await _savePermissionStatus(true);
          return true;
        }
        
        return false;
      }
    }
    
    // For iOS
    if (Platform.isIOS) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.photos,
        Permission.storage,
      ].request();
      
      bool allGranted = statuses.values.every((status) => status.isGranted);
      
      if (allGranted) {
        await _savePermissionStatus(true);
        return true;
      }
      
      return false;
    }
    
    return false;
  }
  
  /// Check if the permission has been permanently denied
  Future<bool> isPermanentlyDenied() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 33) {
        // Android 13+ (API 33+)
        return await Permission.photos.isPermanentlyDenied || 
               await Permission.videos.isPermanentlyDenied || 
               await Permission.audio.isPermanentlyDenied;
      } else if (sdkInt >= 30) {
        // Android 11-12 (API 30-32)
        return await Permission.manageExternalStorage.isPermanentlyDenied;
      } else {
        // Android 10 and below
        return await Permission.storage.isPermanentlyDenied;
      }
    }
    
    if (Platform.isIOS) {
      return await Permission.photos.isPermanentlyDenied || 
             await Permission.storage.isPermanentlyDenied;
    }
    
    return false;
  }
  
  /// Open app settings page
  void openSettings() {
    openAppSettings();
  }
  
  /// Save permission status to SharedPreferences
  Future<void> _savePermissionStatus(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('storagePermissionsGranted', granted);
  }
  
  /// Get required permissions description based on platform and OS version
  Future<String> getRequiredPermissionsDescription() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 33) {
        return 'access to photos, videos, and audio files';
      } else if (sdkInt >= 30) {
        return 'access to manage all files on your device';
      } else {
        return 'access to storage';
      }
    }
    
    if (Platform.isIOS) {
      return 'access to photos and storage';
    }
    
    return 'access to storage';
  }
}
