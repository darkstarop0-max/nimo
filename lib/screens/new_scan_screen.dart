import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/media_store_service.dart';
import '../services/permissions_service.dart';

class NewScanScreen extends StatefulWidget {
  const NewScanScreen({super.key});

  @override
  State<NewScanScreen> createState() => _NewScanScreenState();
}

class _NewScanScreenState extends State<NewScanScreen> with TickerProviderStateMixin {
  // Services
  final MediaStoreService _mediaStoreService = MediaStoreService();
  final PermissionsService _permissionsService = PermissionsService();
  
  // Animation controllers
  late AnimationController _scanAnimationController;
  late Animation<double> _progressAnimation;
  
  // Progress subscription
  StreamSubscription<ScanProgress>? _progressSubscription;
  
  // Scan state
  bool _isScanning = false;
  bool _scanComplete = false;
  String _currentCategory = '';
  double _scanProgress = 0.0;
  int _filesScanned = 0;
  int _totalSizeBytes = 0;
  bool _hasStarted = false;
  String _scanButtonText = "Start Scan";
  
  // Category progress tracking
  final Map<String, Map<String, dynamic>> _categoryProgress = {
    'junk': {'progress': 0.0, 'filesCount': 0, 'size': 0, 'status': 'Pending'},
    'cache': {'progress': 0.0, 'filesCount': 0, 'size': 0, 'status': 'Pending'},
    'images': {'progress': 0.0, 'filesCount': 0, 'size': 0, 'status': 'Pending'},
    'videos': {'progress': 0.0, 'filesCount': 0, 'size': 0, 'status': 'Pending'},
    'audio': {'progress': 0.0, 'filesCount': 0, 'size': 0, 'status': 'Pending'},
    'documents': {'progress': 0.0, 'filesCount': 0, 'size': 0, 'status': 'Pending'},
    'downloads': {'progress': 0.0, 'filesCount': 0, 'size': 0, 'status': 'Pending'},
  };
  
  // Category details
  final List<Map<String, dynamic>> _categories = [
    {
      'key': 'junk',
      'name': 'Junk Files',
      'icon': Icons.delete_outline,
      'color': Colors.orange,
      'description': 'Temporary files left by the system and apps',
      'status': 'Waiting', 
      'result': '0 B', 
      'filesCount': 0
    },
    {
      'key': 'cache',
      'name': 'Cache Files',
      'icon': Icons.cached,
      'color': Colors.purple,
      'description': 'App cache that can be safely removed',
    },
    {
      'key': 'images',
      'name': 'Images',
      'icon': Icons.image_outlined,
      'color': Colors.blue,
      'description': 'Photos and images stored on your device',
    },
    {
      'key': 'videos',
      'name': 'Videos',
      'icon': Icons.videocam_outlined,
      'color': Colors.red,
      'description': 'Video files consuming space',
    },
    {
      'key': 'audio',
      'name': 'Audio',
      'icon': Icons.audiotrack_outlined,
      'color': Colors.green,
      'description': 'Music and audio files on your device',
    },
    {
      'key': 'documents',
      'name': 'Documents',
      'icon': Icons.description_outlined,
      'color': Colors.teal,
      'description': 'Document files like PDFs, DOCs, etc.',
    },
    {
      'key': 'downloads',
      'name': 'Downloads',
      'icon': Icons.download_outlined,
      'color': Colors.amber,
      'description': 'Files in your Downloads folder',
    },
    {
      'key': 'large',
      'name': 'Large Files',
      'icon': Icons.insert_drive_file_outlined,
      'color': Colors.indigo,
      'description': 'Files larger than 50MB',
    },
    {
      'key': 'duplicates',
      'name': 'Duplicates',
      'icon': Icons.file_copy_outlined,
      'color': Colors.deepPurple,
      'description': 'Duplicate files wasting space',
    },
    {
      'key': 'temporary',
      'name': 'Temporary Files',
      'icon': Icons.access_time,
      'color': Colors.pink,
      'description': 'Temporary files that can be cleaned',
    },
  ];
  // Results of the scan
  Map<String, CategoryResult> _scanResults = {};
  
  // Subscription to progress updates
  StreamSubscription<ScanProgress>? _progressSubscription;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for the scan animation
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // Initialize the MediaStore service
    _initMediaStoreService();
    
    // Check permissions and start scan
    _checkPermissionsAndStartScan();
  }
  
  @override
  void dispose() {
    _scanAnimationController.dispose();
    _progressSubscription?.cancel();
    _mediaStoreService.dispose();
    super.dispose();
  }
      vsync: this,
      duration: const Duration(milliseconds: 500),
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
    
    // Initialize the MediaStore service
    _initializeService();
  }
  
  Future<void> _initializeService() async {
    // Initialize the MediaStore service
    await _mediaStoreService.initialize();
    
    // Listen for progress updates
    _progressSubscription = _mediaStoreService.progressStream.listen(_handleProgressUpdate);
    
    // Start the scan
    _startScan();
  }
  
  void _handleProgressUpdate(ScanProgress progress) {
    setState(() {
      _scanProgress = progress.progress / 100.0;
      _filesScanned = progress.filesScanned;
      _totalSizeBytes = progress.totalSize;
      _currentCategory = _getCategoryNameFromKey(progress.category);
      
      // Update progress animation
      _updateProgressAnimation();
      
      // Update category statuses
      if (progress.status == 'complete' && progress.category != 'all') {
        // Find the category and update its status
        final categoryKey = progress.category;
        final categoryName = _getCategoryNameFromKey(categoryKey);
        final categoryIndex = _categories.indexWhere((cat) => cat['name'] == categoryName);
        
        if (categoryIndex >= 0) {
          final sizeInBytes = progress.sizeInCategory ?? 0;
          final filesCount = progress.filesInCategory ?? 0;
          
          _categories[categoryIndex]['status'] = 'Complete';
          _categories[categoryIndex]['result'] = _formatSize(sizeInBytes);
          _categories[categoryIndex]['filesCount'] = filesCount;
        }
      }
      
      // Check if scan is complete
      if (progress.status == 'complete' && progress.category == 'all') {
        _scanComplete = true;
        _isScanning = false;
        
        // Cancel any progress timer
        _progressTimer?.cancel();
        
        // Navigate to results screen after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _finishScan();
          }
        });
      }
    });
  }
  
  String _getCategoryNameFromKey(String key) {
    final entry = _categoryToKey.entries.firstWhere(
      (entry) => entry.value == key,
      orElse: () => const MapEntry('Unknown', 'unknown'),
    );
    return entry.key;
  }
  
  void _updateProgressAnimation() {
    // Update the progress animation target
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: _scanProgress,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeOut,
    ));
    
    // Reset and start the animation
    _scanAnimationController.reset();
    _scanAnimationController.forward();
  }
  
  @override
  void dispose() {
    _scanAnimationController.dispose();
    _rotateAnimationController.dispose();
    _progressSubscription?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }
  
  // Start the scan process
  Future<void> _startScan() async {
    // Use MediaStore service to scan files
    try {
      // Start a timer to ensure the progress bar keeps moving
      // even if native scan is slow to report progress
      _startProgressTimer();
      
      // Start the actual scan
      _scanResults = await _mediaStoreService.scanFiles();
      
      // If we get here, the scan completed successfully
      if (mounted && !_scanComplete) {
        setState(() {
          _scanComplete = true;
          _isScanning = false;
          _scanProgress = 1.0;
          _updateProgressAnimation();
        });
        
        // Navigate to results screen after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _finishScan();
          }
        });
      }
    } catch (e) {
      print('Error scanning files: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Scan Error'),
            content: Text('Failed to scan files: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
  
  void _startProgressTimer() {
    // Create a timer that updates progress smoothly
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _scanComplete) {
        timer.cancel();
        return;
      }
      
      setState(() {
        // Increase progress slightly, but not too fast
        if (_scanProgress < 0.95) {
          final increment = 0.001 * (1.0 - _scanProgress); // Slow down as we progress
          _scanProgress += increment;
          _updateProgressAnimation();
        }
      });
    });
  }
  
  void _finishScan() {
    // Navigate to the results screen with scan results
    Navigator.pushReplacementNamed(
      context, 
      '/results',
      arguments: _scanResults,
    );
  }
  
  void _cancelScan() {
    if (_isScanning) {
      _mediaStoreService.cancelScan();
      _progressTimer?.cancel();
      
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        
        // Navigate back to home
        Navigator.pop(context);
      }
    }
  }
  
  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: () async {
        if (_isScanning) {
          _cancelScan();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (_isScanning) {
                          _cancelScan();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Scanning Storage',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _isScanning ? _cancelScan : null,
                      color: _isScanning ? null : Colors.transparent,
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Scanning animation and progress
                    SizedBox(
                      height: screenSize.width * 0.6,
                      width: screenSize.width * 0.6,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating background gradient
                          AnimatedBuilder(
                            animation: _rotateAnimationController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotateAnimationController.value * 2 * math.pi,
                                child: Container(
                                  width: screenSize.width * 0.6,
                                  height: screenSize.width * 0.6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: SweepGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary.withOpacity(0.0),
                                        Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                        Theme.of(context).colorScheme.primary.withOpacity(0.0),
                                      ],
                                      stops: const [0.0, 0.3, 0.6, 1.0],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          // Progress indicator
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return CircularProgressIndicator(
                                value: _progressAnimation.value,
                                strokeWidth: 12,
                                backgroundColor: isDarkMode 
                                    ? Colors.grey[800] 
                                    : Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              );
                            },
                          ),
                          
                          // Lottie animation in the center
                          if (_isScanning)
                            SizedBox(
                              width: screenSize.width * 0.3,
                              height: screenSize.width * 0.3,
                              child: Lottie.asset(
                                'assets/animations/scanning.json',
                                fit: BoxFit.contain,
                              ),
                            )
                          else
                            Icon(
                              Icons.check_circle_outline,
                              size: screenSize.width * 0.3,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Scanning status
                    Text(
                      _isScanning ? 'Scanning $_currentCategory...' : 'Scan Complete',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Files scanned and size
                    Text(
                      '${_filesScanned.toString()} files (${_formatSize(_totalSizeBytes)})',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Scan progress percentage
                    Text(
                      '${(_scanProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              
              // Category results
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            
                            // Determine if this is the currently scanning category
                            final bool isCurrentCategory = _currentCategory == category['name'] && _isScanning;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDarkMode 
                                    ? Colors.grey[850] 
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: isCurrentCategory 
                                    ? Border.all(
                                        color: category['color'],
                                        width: 2,
                                      ) 
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: category['color'].withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      category['icon'],
                                      color: category['color'],
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isCurrentCategory 
                                              ? 'Scanning...' 
                                              : '${category['filesCount']} files, ${category['result']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCurrentCategory)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else if (category['status'] == 'Complete')
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 16,
                                    ),
                                ],
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
              if (_isScanning)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _cancelScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
      ),
    );
  }
}
