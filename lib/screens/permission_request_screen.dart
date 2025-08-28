import 'dart:io';

import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:storage_cleaner_app/services/permissions_service.dart';

class PermissionRequestScreen extends StatefulWidget {
  const PermissionRequestScreen({super.key});

  @override
  State<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _isLoading = false;
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  int? _androidSdkVersion;
  final PermissionsService _permissionsService = PermissionsService();
  String _permissionType = 'storage access';

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _checkAndroidVersion();
    _permissionType = await _permissionsService.getRequiredPermissionsDescription();
    
    // Check if we already have permissions
    final hasPermission = await _permissionsService.hasStoragePermission();
    if (hasPermission) {
      _navigateToHome();
    }
  }

  Future<void> _checkAndroidVersion() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      setState(() {
        _androidSdkVersion = androidInfo.version.sdkInt;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    // Request permissions using our service
    final permissionsGranted = await _permissionsService.requestStoragePermission();
    
    setState(() {
      _isLoading = false;
    });

    if (permissionsGranted) {
      _navigateToHome();
    } else {
      // Check if permanently denied
      final isPermanentlyDenied = await _permissionsService.isPermanentlyDenied();
      if (isPermanentlyDenied && mounted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: Text(
          'This app needs $_permissionType to scan and clean your device. '
          'Please grant the permission in app settings to continue.'
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _permissionsService.openSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header image
              Icon(
                Icons.folder_open,
                size: screenSize.width * 0.35,
                color: Theme.of(context).colorScheme.primary,
              ),
              
              const SizedBox(height: 40),
              
              // Title
              Text(
                'Storage Access',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              // Explanation text
              Text(
                'S Cleaner needs access to your storage to:',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Benefits
              ..._buildPermissionBenefits(),
              
              const SizedBox(height: 40),
              
              // Android version specific text
              if (_androidSdkVersion != null)
                Text(
                  _getPermissionTypeText(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              
              const SizedBox(height: 16),
              
              // Grant access button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Grant Access',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Privacy reassurance
              Text(
                'Your data privacy is important to us. We only access what\'s needed for cleaning.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPermissionBenefits() {
    final benefits = [
      {
        'icon': Icons.cleaning_services_outlined,
        'title': 'Scan and clean junk files',
      },
      {
        'icon': Icons.file_copy_outlined,
        'title': 'Find and remove duplicate files',
      },
      {
        'icon': Icons.image_outlined,
        'title': 'Identify large media files',
      },
    ];

    return benefits.map((benefit) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                benefit['icon'] as IconData,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                benefit['title'] as String,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _getPermissionTypeText() {
    if (_androidSdkVersion! >= 33) {
      return 'For Android 13+: We\'ll request access to photos, videos, and audio files';
    } else if (_androidSdkVersion! >= 30) {
      return 'For Android 11-12: We\'ll request storage management permission';
    } else {
      return 'For Android 10 and below: We\'ll request storage access permission';
    }
  }
}
