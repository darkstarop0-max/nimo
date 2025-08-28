import 'package:flutter/material.dart';
import 'package:storage_cleaner_app/services/permissions_service.dart';

class PermissionDialog extends StatelessWidget {
  final String permissionType;
  final VoidCallback onRequestPermission;
  final VoidCallback onCancel;
  final bool isPermanentlyDenied;
  
  const PermissionDialog({
    super.key,
    required this.permissionType,
    required this.onRequestPermission,
    required this.onCancel,
    this.isPermanentlyDenied = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: _buildDialogContent(context),
    );
  }
  
  Widget _buildDialogContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            'Storage Permission Required',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Message
          Text(
            'This app needs $permissionType to scan and clean storage.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Buttons
          Row(
            children: [
              // Cancel button
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              
              // Grant button
              Expanded(
                child: ElevatedButton(
                  onPressed: onRequestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(isPermanentlyDenied ? 'Open Settings' : 'Grant'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the permission dialog and handles the request
Future<bool> showPermissionRequestDialog(
  BuildContext context, {
  bool checkPermanentDenial = true,
}) async {
  final permissionsService = PermissionsService();
  
  // If already has permission, return true
  if (await permissionsService.hasStoragePermission()) {
    return true;
  }
  
  // Check if permanently denied
  bool isPermanentlyDenied = false;
  if (checkPermanentDenial) {
    isPermanentlyDenied = await permissionsService.isPermanentlyDenied();
  }
  
  // Get the description of required permissions
  final permissionType = await permissionsService.getRequiredPermissionsDescription();
  
  // Show the dialog
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PermissionDialog(
      permissionType: permissionType,
      isPermanentlyDenied: isPermanentlyDenied,
      onRequestPermission: () async {
        if (isPermanentlyDenied) {
          permissionsService.openSettings();
          Navigator.of(context).pop(false);
        } else {
          final result = await permissionsService.requestStoragePermission();
          Navigator.of(context).pop(result);
        }
      },
      onCancel: () {
        Navigator.of(context).pop(false);
      },
    ),
  ) ?? false;
}
