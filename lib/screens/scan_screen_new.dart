import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto/crypto.dart';

// Data model for scan results
class ScanResult {
  final String categoryName;
  final double sizeInBytes;
  final List<FileSystemEntity> files;

  ScanResult({
    required this.categoryName,
    required this.sizeInBytes,
    required this.files,
  });

  // Convert size to readable format
  String get formattedSize {
    if (sizeInBytes < 1024) {
      return '${sizeInBytes.toStringAsFixed(1)} B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

// Message structure for Isolate communication
class ScanMessage {
  final String category;
  final double progress;
  final ScanResult? result;

  ScanMessage({
    required this.category,
    required this.progress,
    this.result,
  });
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  late AnimationController _scanAnimationController;
  late AnimationController _rotateAnimationController;
  late Animation<double> _progressAnimation;
  
  // Current scan progress
  double _scanProgress = 0.0;
  
  // Scan categories with their statuses
  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Junk Files',
      'icon': Icons.delete_outline,
      'status': 'Scanning...',
      'color': Colors.orange,
      'completesAt': 20.0, // Percentage at which this category completes
      'result': '0 B',
      'size': 0.0, // Size in bytes
      'files': <FileSystemEntity>[],
    },
    {
      'name': 'Cache Files',
      'icon': Icons.cached,
      'status': 'Scanning...',
      'color': Colors.purple,
      'completesAt': 40.0,
      'result': '0 B',
      'size': 0.0,
      'files': <FileSystemEntity>[],
    },
    {
      'name': 'Duplicate Files',
      'icon': Icons.file_copy_outlined,
      'status': 'Scanning...',
      'color': Colors.green,
      'completesAt': 60.0,
      'result': '0 B',
      'size': 0.0,
      'files': <FileSystemEntity>[],
    },
    {
      'name': 'Large Files',
      'icon': Icons.insert_drive_file_outlined,
      'status': 'Scanning...',
      'color': Colors.blue,
      'completesAt': 80.0,
      'result': '0 B',
      'size': 0.0,
      'files': <FileSystemEntity>[],
    },
    {
      'name': 'Temporary Files',
      'icon': Icons.access_time,
      'status': 'Scanning...',
      'color': Colors.red,
      'completesAt': 95.0,
      'result': '0 B',
      'size': 0.0,
      'files': <FileSystemEntity>[],
    },
  ];
  
  // Overall scan results
  Map<String, ScanResult> _scanResults = {};
  bool _isScanning = true;
  bool _scanCancelled = false;
  double _totalFoundSizeBytes = 0;
  
  // Isolate for scanning
  Isolate? _scanIsolate;
  ReceivePort? _receivePort;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize scan animation controller (for progress circle)
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Initialize rotation animation controller (for radar effect)
    _rotateAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // Progress animation (starts at 0)
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeOut,
    ));
    
    // Request permissions and start scanning
    _requestPermissionsAndStartScan();
  }
  
  @override
  void dispose() {
    _scanAnimationController.dispose();
    _rotateAnimationController.dispose();
    _cancelScan();
    _receivePort?.close();
    super.dispose();
  }
  
  // Request storage permissions and start scan
  Future<void> _requestPermissionsAndStartScan() async {
    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
    
    // Check if permissions were granted
    if (statuses[Permission.storage]!.isGranted) {
      _startScan();
    } else {
      setState(() {
        _isScanning = false;
        _categories.forEach((category) {
          category['status'] = 'Permission denied';
        });
      });
      
      // Show permission denied dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Storage Permission Required'),
            content: const Text(
              'This app needs storage permissions to scan files. Please grant the permission in app settings.'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to home screen
                },
                child: const Text('Go Back'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
  }
  
  // Start the scan process
  Future<void> _startScan() async {
    // Create a receive port for isolate communication
    _receivePort = ReceivePort();
    
    // Create and spawn the isolate
    _scanIsolate = await Isolate.spawn(
      _scanStorage,
      _receivePort!.sendPort,
    );
    
    // Listen for messages from the isolate
    _receivePort!.listen((message) {
      if (message is ScanMessage) {
        _updateScanProgress(message);
      }
    });
  }
  
  // Cancel the scan
  void _cancelScan() {
    _scanCancelled = true;
    _scanIsolate?.kill(priority: Isolate.immediate);
    _scanIsolate = null;
  }
  
  // Update scan progress based on isolate message
  void _updateScanProgress(ScanMessage message) {
    if (_scanCancelled) return;
    
    setState(() {
      _scanProgress = message.progress;
      
      // Update progress animation
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: _scanProgress / 100,
      ).animate(CurvedAnimation(
        parent: _scanAnimationController,
        curve: Curves.easeOut,
      ));
      
      _scanAnimationController.forward(from: 0);
      
      // Update category status
      for (var category in _categories) {
        if (category['name'] == message.category && message.result != null) {
          category['status'] = 'Completed';
          category['result'] = message.result!.formattedSize;
          category['size'] = message.result!.sizeInBytes;
          category['files'] = message.result!.files;
          
          // Update total size found
          _totalFoundSizeBytes += message.result!.sizeInBytes;
          
          // Store scan result
          _scanResults[message.category] = message.result!;
        }
      }
      
      // Check if scan is complete
      if (_scanProgress >= 100) {
        _isScanning = false;
        _navigateToResultsWithDelay();
      }
    });
  }
  
  // Navigate to results screen after a short delay
  void _navigateToResultsWithDelay() {
    if (!mounted) return;
    
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      Navigator.pushReplacementNamed(
        context, 
        '/results',
        arguments: _scanResults,
      );
    });
  }
  
  // Format total size to readable string
  String get _formattedTotalSize {
    if (_totalFoundSizeBytes < 1024) {
      return '${_totalFoundSizeBytes.toStringAsFixed(1)} B';
    } else if (_totalFoundSizeBytes < 1024 * 1024) {
      return '${(_totalFoundSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else if (_totalFoundSizeBytes < 1024 * 1024 * 1024) {
      return '${(_totalFoundSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(_totalFoundSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Storage Scan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scan progress circle
            Expanded(
              flex: 5,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotating radar effect
                    RotationTransition(
                      turns: _rotateAnimationController,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.blue.withOpacity(0.0),
                              Colors.blue.withOpacity(0.1),
                              Colors.purple.withOpacity(0.3),
                              Colors.purple.withOpacity(0.5),
                              Colors.blue.withOpacity(0.7),
                              Colors.blue.withOpacity(0.0),
                            ],
                            stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),
                    
                    // Progress circle
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                              width: 15,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.transparent,
                                  width: 15,
                                ),
                              ),
                              child: CircularProgressIndicator(
                                value: _progressAnimation.value,
                                strokeWidth: 15,
                                backgroundColor: Colors.grey.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isScanning
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.green,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Percentage text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_scanProgress.toInt()}%',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isScanning ? 'Scanning...' : 'Completed',
                          style: TextStyle(
                            fontSize: 16,
                            color: _isScanning
                                ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)
                                : Colors.green,
                          ),
                        ),
                        if (_totalFoundSizeBytes > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Found: $_formattedTotalSize',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Category list
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'Scanning Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isCompleted = category['status'] == 'Completed';
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? category['color'].withOpacity(0.1)
                                    : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: category['color'].withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    category['icon'],
                                    color: category['color'],
                                  ),
                                ),
                                title: Text(
                                  category['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    category['status'],
                                    key: ValueKey<String>(category['status']),
                                    style: TextStyle(
                                      color: isCompleted
                                          ? Colors.green
                                          : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                                trailing: isCompleted
                                    ? Text(
                                        category['result'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: category['color'],
                                        ),
                                      )
                                    : SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: _scanProgress >= category['completesAt']
                                            ? const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 20,
                                              )
                                            : CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  category['color'],
                                                ),
                                              ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Cancel button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isScanning
                      ? () {
                          _cancelScan();
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                    disabledForegroundColor: Colors.grey.withOpacity(0.5),
                  ),
                  child: const Text(
                    'Cancel Scan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Isolate entry point for scanning storage
void _scanStorage(SendPort sendPort) async {
  // Get application documents directory
  final appDocDir = await getApplicationDocumentsDirectory();
  final appCacheDir = await getTemporaryDirectory();
  
  // For Android, get external storage directory if available
  Directory? externalDir;
  if (Platform.isAndroid) {
    externalDir = await getExternalStorageDirectory();
  }
  
  // Get common directories for scanning
  final List<Directory> dirsToScan = [
    appDocDir,
    appCacheDir,
  ];
  
  if (externalDir != null) {
    dirsToScan.add(externalDir);
    
    // Add common Android media directories if possible
    try {
      final externalPath = externalDir.path;
      final parentPath = externalPath.substring(0, externalPath.lastIndexOf('/Android'));
      
      // Common media directories
      final dcimDir = Directory('$parentPath/DCIM');
      final downloadDir = Directory('$parentPath/Download');
      final picturesDir = Directory('$parentPath/Pictures');
      
      if (await dcimDir.exists()) dirsToScan.add(dcimDir);
      if (await downloadDir.exists()) dirsToScan.add(downloadDir);
      if (await picturesDir.exists()) dirsToScan.add(picturesDir);
    } catch (e) {
      // Ignore directory access errors
    }
  }
  
  // Scan for junk files (first 20%)
  await _scanJunkFiles(sendPort, dirsToScan);
  
  // Scan for cache files (20-40%)
  await _scanCacheFiles(sendPort, dirsToScan);
  
  // Scan for duplicate files (40-60%)
  await _scanDuplicateFiles(sendPort, dirsToScan);
  
  // Scan for large files (60-80%)
  await _scanLargeFiles(sendPort, dirsToScan);
  
  // Scan for temporary files (80-100%)
  await _scanTemporaryFiles(sendPort, dirsToScan);
  
  // Scan complete
  sendPort.send(ScanMessage(category: 'Complete', progress: 100.0));
}

// Scan for junk files (like .tmp, .log files)
Future<void> _scanJunkFiles(SendPort sendPort, List<Directory> dirsToScan) async {
  final junkExtensions = ['.tmp', '.log', '.bak', '.old', '.temp'];
  final junkFiles = <FileSystemEntity>[];
  double totalSize = 0;
  
  for (var dir in dirsToScan) {
    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        // Send progress updates
        sendPort.send(ScanMessage(
          category: 'Junk Files',
          progress: math.min(20.0, junkFiles.length / 10.0),
        ));
        
        if (entity is File) {
          final path = entity.path.toLowerCase();
          if (junkExtensions.any((ext) => path.endsWith(ext))) {
            junkFiles.add(entity);
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
    } catch (e) {
      // Skip directories that can't be accessed
    }
  }
  
  // Send the final result for this category
  sendPort.send(ScanMessage(
    category: 'Junk Files',
    progress: 20.0,
    result: ScanResult(
      categoryName: 'Junk Files',
      sizeInBytes: totalSize,
      files: junkFiles,
    ),
  ));
}

// Scan for cache files
Future<void> _scanCacheFiles(SendPort sendPort, List<Directory> dirsToScan) async {
  final cacheFiles = <FileSystemEntity>[];
  double totalSize = 0;
  
  // Look for cache directories and files
  for (var dir in dirsToScan) {
    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        // Send progress updates
        sendPort.send(ScanMessage(
          category: 'Cache Files',
          progress: 20.0 + math.min(20.0, cacheFiles.length / 10.0),
        ));
        
        if (entity is Directory && entity.path.toLowerCase().contains('cache')) {
          // Found a cache directory - count all files in it
          try {
            await for (var file in entity.list(recursive: true, followLinks: false)) {
              if (file is File) {
                cacheFiles.add(file);
                final stat = await file.stat();
                totalSize += stat.size;
              }
            }
          } catch (e) {
            // Skip directories that can't be accessed
          }
        } else if (entity is File && entity.path.toLowerCase().contains('cache')) {
          // Found a cache file
          cacheFiles.add(entity);
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
    } catch (e) {
      // Skip directories that can't be accessed
    }
  }
  
  // Send the final result for this category
  sendPort.send(ScanMessage(
    category: 'Cache Files',
    progress: 40.0,
    result: ScanResult(
      categoryName: 'Cache Files',
      sizeInBytes: totalSize,
      files: cacheFiles,
    ),
  ));
}

// Scan for duplicate files using hash comparison
Future<void> _scanDuplicateFiles(SendPort sendPort, List<Directory> dirsToScan) async {
  final Map<String, List<File>> fileHashes = {};
  final duplicateFiles = <FileSystemEntity>[];
  double totalSize = 0;
  int filesProcessed = 0;
  
  // Common media and document extensions to scan
  final extensionsToScan = ['.jpg', '.jpeg', '.png', '.mp4', '.mp3', '.pdf', '.doc', '.docx', '.txt'];
  
  // Find media files and hash them
  for (var dir in dirsToScan) {
    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        filesProcessed++;
        
        // Send progress updates
        if (filesProcessed % 10 == 0) {
          sendPort.send(ScanMessage(
            category: 'Duplicate Files',
            progress: 40.0 + math.min(20.0, filesProcessed / 50.0),
          ));
        }
        
        if (entity is File) {
          final path = entity.path.toLowerCase();
          if (extensionsToScan.any((ext) => path.endsWith(ext))) {
            try {
              // For large files, just hash the first 1MB to speed things up
              final stat = await entity.stat();
              if (stat.size > 0) {
                String hash;
                
                if (stat.size > 1024 * 1024) {
                  // For files larger than 1MB, hash just the beginning and end
                  final raf = await entity.open(mode: FileMode.read);
                  final beginBytes = List<int>.filled(512 * 1024, 0);
                  final endBytes = List<int>.filled(512 * 1024, 0);
                  
                  await raf.readInto(beginBytes, 0, 512 * 1024);
                  await raf.setPosition(math.max(0, stat.size - 512 * 1024));
                  await raf.readInto(endBytes, 0, 512 * 1024);
                  await raf.close();
                  
                  final combinedBytes = [...beginBytes, ...endBytes];
                  hash = sha1.convert(combinedBytes).toString();
                } else {
                  // For smaller files, hash the entire content
                  final bytes = await entity.readAsBytes();
                  hash = sha1.convert(bytes).toString();
                }
                
                // Add to hash map
                if (!fileHashes.containsKey(hash)) {
                  fileHashes[hash] = [];
                }
                fileHashes[hash]!.add(entity);
              }
            } catch (e) {
              // Skip files that can't be read
            }
          }
        }
      }
    } catch (e) {
      // Skip directories that can't be accessed
    }
  }
  
  // Find duplicates (files with the same hash)
  fileHashes.forEach((hash, files) {
    if (files.length > 1) {
      // These are duplicates - keep the first one and mark the rest as duplicates
      for (int i = 1; i < files.length; i++) {
        duplicateFiles.add(files[i]);
        try {
          final stat = files[i].statSync();
          totalSize += stat.size;
        } catch (e) {
          // Skip files that can't be accessed
        }
      }
    }
  });
  
  // Send the final result for this category
  sendPort.send(ScanMessage(
    category: 'Duplicate Files',
    progress: 60.0,
    result: ScanResult(
      categoryName: 'Duplicate Files',
      sizeInBytes: totalSize,
      files: duplicateFiles,
    ),
  ));
}

// Scan for large files (> 100MB)
Future<void> _scanLargeFiles(SendPort sendPort, List<Directory> dirsToScan) async {
  final largeFiles = <FileSystemEntity>[];
  double totalSize = 0;
  int filesProcessed = 0;
  
  // Size threshold for large files (100MB)
  final largeFileSizeThreshold = 100 * 1024 * 1024;
  
  for (var dir in dirsToScan) {
    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        filesProcessed++;
        
        // Send progress updates
        if (filesProcessed % 10 == 0) {
          sendPort.send(ScanMessage(
            category: 'Large Files',
            progress: 60.0 + math.min(20.0, filesProcessed / 50.0),
          ));
        }
        
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (stat.size > largeFileSizeThreshold) {
              largeFiles.add(entity);
              totalSize += stat.size;
            }
          } catch (e) {
            // Skip files that can't be accessed
          }
        }
      }
    } catch (e) {
      // Skip directories that can't be accessed
    }
  }
  
  // Send the final result for this category
  sendPort.send(ScanMessage(
    category: 'Large Files',
    progress: 80.0,
    result: ScanResult(
      categoryName: 'Large Files',
      sizeInBytes: totalSize,
      files: largeFiles,
    ),
  ));
}

// Scan for temporary files
Future<void> _scanTemporaryFiles(SendPort sendPort, List<Directory> dirsToScan) async {
  final tempFiles = <FileSystemEntity>[];
  double totalSize = 0;
  int filesProcessed = 0;
  
  // Temporary file patterns
  final tempPatterns = [
    '.temp', '.tmp', '~', '.bak', '.crdownload', '.part',
    'thumbs.db', '.DS_Store', 'desktop.ini'
  ];
  
  for (var dir in dirsToScan) {
    try {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        filesProcessed++;
        
        // Send progress updates
        if (filesProcessed % 10 == 0) {
          sendPort.send(ScanMessage(
            category: 'Temporary Files',
            progress: 80.0 + math.min(15.0, filesProcessed / 50.0),
          ));
        }
        
        if (entity is File) {
          final path = entity.path.toLowerCase();
          if (tempPatterns.any((pattern) => path.contains(pattern))) {
            tempFiles.add(entity);
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
    } catch (e) {
      // Skip directories that can't be accessed
    }
  }
  
  // Send the final result for this category
  sendPort.send(ScanMessage(
    category: 'Temporary Files',
    progress: 95.0,
    result: ScanResult(
      categoryName: 'Temporary Files',
      sizeInBytes: totalSize,
      files: tempFiles,
    ),
  ));
}
