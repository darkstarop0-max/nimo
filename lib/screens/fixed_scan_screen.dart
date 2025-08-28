import 'dart:async';
import 'package:flutter/material.dart';
import 'package:storage_cleaner_app/services/media_store_service.dart';
import '../theme/theme.dart';

class NewScanScreenFixed extends StatefulWidget {
  const NewScanScreenFixed({Key? key}) : super(key: key);

  @override
  _NewScanScreenFixedState createState() => _NewScanScreenFixedState();
}

class _NewScanScreenFixedState extends State<NewScanScreenFixed> with SingleTickerProviderStateMixin {
  // MediaStore Service
  final MediaStoreService _mediaStoreService = MediaStoreService();
  
  // Theme colors
  late Color _primaryColor;
  late Color _secondaryColor;
  late Color _backgroundColor;
  late Color _textColor;
  
  // Animation controllers
  late AnimationController _scanAnimationController;
  late Animation<double> _progressAnimation;
  
  // Subscription for progress updates
  StreamSubscription<ScanProgress>? _progressSubscription;
  
  // Scan state variables
  double _scanProgress = 0.0;
  int _filesScanned = 0;
  int _totalSizeBytes = 0;
  String _currentCategory = "Initializing...";
  bool _isScanning = false;
  bool _isComplete = false;
  bool _hasStarted = false;
  String _scanButtonText = "Start Scan";
  
  // Category data
  final List<Map<String, dynamic>> _categories = [
    {"name": "Junk Files", "icon": Icons.delete_outline, "status": "Waiting", "result": "0 B", "filesCount": 0, "key": "junk"},
    {"name": "Cache Files", "icon": Icons.cached, "status": "Waiting", "result": "0 B", "filesCount": 0, "key": "cache"},
    {"name": "Images", "icon": Icons.image_outlined, "status": "Waiting", "result": "0 B", "filesCount": 0, "key": "images"},
    {"name": "Videos", "icon": Icons.video_file_outlined, "status": "Waiting", "result": "0 B", "filesCount": 0, "key": "videos"},
    {"name": "Audio", "icon": Icons.audio_file_outlined, "status": "Waiting", "result": "0 B", "filesCount": 0, "key": "audio"},
    {"name": "Documents", "icon": Icons.description_outlined, "status": "Waiting", "result": "0 B", "filesCount": 0, "key": "documents"},
    {"name": "Downloads", "icon": Icons.download_outlined, "status": "Waiting", "result": "0 B", "filesCount": 0, "key": "downloads"},
    {"name": "Large Files", "icon": Icons.folder_outlined, "status": "Waiting", "result": "0 B", "filesCount": 0, "key": "large"},
    {"name": "Duplicates", "icon": Icons.copy_outlined, "status": "Waiting", "result": "0 B", "filesCount": 0, "key": "duplicates"},
    {"name": "Temporary", "icon": Icons.timelapse_outlined, "status": "Waiting", "result": "0 B", "filesCount": 0, "key": "temporary"},
  ];
  
  // Results map to store scan results
  Map<String, CategoryResult>? _scanResults;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _scanAnimationController = AnimationController(
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
      
      // Handle scan completion
      if (progress.status == 'complete' && progress.category == 'all') {
        _isScanning = false;
        _isComplete = true;
        _scanButtonText = "View Results";
        _scanAnimationController.stop();
      }
    });
  }
  
  String _getCategoryNameFromKey(String key) {
    final category = _categories.firstWhere(
      (cat) => cat['key'] == key,
      orElse: () => {"name": "Unknown"}
    );
    return category['name'];
  }
  
  void _updateProgressAnimation() {
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: _scanProgress,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeOut,
    ));
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
  
  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _hasStarted = true;
      _scanButtonText = "Cancel Scan";
      
      // Reset category statuses
      for (var category in _categories) {
        category['status'] = 'Waiting';
        category['result'] = '0 B';
        category['filesCount'] = 0;
      }
    });
    
    try {
      // Start the scan
      _scanResults = await _mediaStoreService.scanFiles();
    } catch (e) {
      print('Error during scan: $e');
      setState(() {
        _isScanning = false;
        _scanButtonText = "Retry Scan";
      });
    }
  }
  
  void _cancelScan() {
    _mediaStoreService.cancelScan();
    _progressSubscription?.cancel();
    
    setState(() {
      _isScanning = false;
      _scanButtonText = "Start Scan";
    });
  }
  
  void _handleScanButtonPressed() {
    if (_isComplete) {
      // Navigate to results screen
      Navigator.pushNamed(context, '/results', arguments: _scanResults);
    } else if (_isScanning) {
      _cancelScan();
    } else {
      // Initialize service and start scan
      _initializeService();
    }
  }
  
  @override
  void dispose() {
    _scanAnimationController.dispose();
    _progressSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get theme from context
    final theme = Theme.of(context);
    _primaryColor = theme.colorScheme.primary;
    _secondaryColor = theme.colorScheme.secondary;
    _backgroundColor = theme.colorScheme.background;
    _textColor = theme.colorScheme.onBackground;
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Storage Scan', style: TextStyle(color: _textColor)),
        iconTheme: IconThemeData(color: _primaryColor),
      ),
      body: Column(
        children: [
          // Progress indicator section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Circular progress indicator
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer circle
                        SizedBox(
                          height: 200,
                          width: 200,
                          child: CircularProgressIndicator(
                            value: _hasStarted ? _progressAnimation.value : 0,
                            strokeWidth: 12,
                            backgroundColor: _secondaryColor.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                          ),
                        ),
                        // Center content
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _hasStarted ? '${(_progressAnimation.value * 100).toInt()}%' : '0%',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _hasStarted ? '$_filesScanned files' : '0 files',
                              style: TextStyle(
                                fontSize: 16,
                                color: _textColor.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _hasStarted ? _formatSize(_totalSizeBytes) : '0 B',
                              style: TextStyle(
                                fontSize: 14,
                                color: _textColor.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Current category text
                Text(
                  _isScanning ? 'Scanning $_currentCategory...' : (_isComplete ? 'Scan Complete' : 'Ready to scan'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _textColor,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Scan button
                ElevatedButton(
                  onPressed: _handleScanButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(_scanButtonText),
                ),
              ],
            ),
          ),
          
          // Category list section
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isActive = _currentCategory == category['name'] && _isScanning;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    elevation: isActive ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isActive 
                        ? BorderSide(color: _primaryColor, width: 2)
                        : BorderSide.none,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Icon(
                        category['icon'] as IconData,
                        color: isActive ? _primaryColor : _textColor.withOpacity(0.7),
                        size: 28,
                      ),
                      title: Text(
                        category['name'] as String,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: _textColor,
                        ),
                      ),
                      subtitle: Text(
                        '${category['filesCount']} files • ${category['result']}',
                        style: TextStyle(
                          color: _textColor.withOpacity(0.6),
                        ),
                      ),
                      trailing: _getCategoryStatusIcon(category['status'] as String, isActive),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _getCategoryStatusIcon(String status, bool isActive) {
    switch (status) {
      case 'Complete':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'Scanning':
        return SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
        );
      case 'Waiting':
        return Icon(
          Icons.hourglass_empty,
          color: isActive ? _primaryColor : _textColor.withOpacity(0.4),
        );
      default:
        return Icon(Icons.help_outline, color: _textColor.withOpacity(0.4));
    }
  }
}
