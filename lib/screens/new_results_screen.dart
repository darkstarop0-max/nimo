import 'dart:io';

import 'package:flutter/material.dart';
import '../services/media_store_service.dart';

class NewResultsScreen extends StatefulWidget {
  const NewResultsScreen({super.key});

  @override
  State<NewResultsScreen> createState() => _NewResultsScreenState();
}

class _NewResultsScreenState extends State<NewResultsScreen> with TickerProviderStateMixin {
  // Selected categories for cleaning
  final Map<String, bool> _selectedCategories = {};
  int _totalSelectedSize = 0;
  int _totalSelectedFiles = 0;
  
  // Tab controller for category tabs
  late TabController _tabController;
  
  // Animation controller for cleanup button
  late AnimationController _cleanButtonController;
  late Animation<double> _cleanButtonAnimation;
  
  // Category details
  final List<Map<String, dynamic>> _categoryDetails = [
    {
      'key': 'junk',
      'name': 'Junk Files',
      'icon': Icons.delete_outline,
      'color': Colors.orange,
      'description': 'Temporary files left by the system and apps',
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
  
  @override
  void initState() {
    super.initState();
    
    // Initialize tab controller
    _tabController = TabController(
      length: _categoryDetails.length,
      vsync: this,
    );
    
    // Initialize clean button animation
    _cleanButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _cleanButtonAnimation = CurvedAnimation(
      parent: _cleanButtonController,
      curve: Curves.easeInOut,
    );
    
    // Listen for tab changes
    _tabController.addListener(_handleTabChange);
  }
  
  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      // Update state if needed
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _cleanButtonController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Get scan results from arguments
    final scanResults = ModalRoute.of(context)?.settings.arguments as Map<String, CategoryResult>? ?? {};
    
    // If no scan results, show empty state
    if (scanResults.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan Results'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('No scan results available'),
        ),
      );
    }

    // Calculate total size and initialize selected categories if not done yet
    int totalSizeBytes = 0;
    int totalFiles = 0;
    
    if (_selectedCategories.isEmpty) {
      for (var entry in scanResults.entries) {
        final result = entry.value;
        totalSizeBytes += result.totalSize;
        totalFiles += result.files.length;
        _selectedCategories[entry.key] = true; // By default, select all categories
      }
      _totalSelectedSize = totalSizeBytes;
      _totalSelectedFiles = totalFiles;
    }
    
    // Format total size
    final totalSizeFormatted = _formatSize(totalSizeBytes);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Results',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      // Go back to scan screen for a new scan
                      Navigator.pushReplacementNamed(context, '/scan');
                    },
                  ),
                ],
              ),
            ),
            
            // Summary card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cleanup Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Size',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalSizeFormatted,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Files Found',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$totalFiles',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Categories',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${scanResults.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Category tabs
            Container(
              margin: const EdgeInsets.only(top: 16),
              height: 40,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.label,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Theme.of(context).colorScheme.primary,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                tabs: _categoryDetails.map((category) {
                  // Find the category result
                  final categoryResult = scanResults[category['key']];
                  final hasContent = categoryResult != null && categoryResult.files.isNotEmpty;
                  
                  return Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: _tabController.index == _categoryDetails.indexOf(category)
                              ? Colors.transparent
                              : Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(category['icon'], size: 16),
                          const SizedBox(width: 8),
                          Text(category['name']),
                          if (hasContent) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _tabController.index == _categoryDetails.indexOf(category)
                                    ? Colors.white24
                                    : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${categoryResult.files.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _tabController.index == _categoryDetails.indexOf(category)
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            // Category content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _categoryDetails.map((category) {
                  final categoryKey = category['key'];
                  final categoryResult = scanResults[categoryKey];
                  
                  if (categoryResult == null || categoryResult.files.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category['icon'],
                            size: 48,
                            color: Theme.of(context).disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No ${category['name']} found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).disabledColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  // Format category size
                  final categorySizeFormatted = _formatSize(categoryResult.totalSize);
                  
                  return Column(
                    children: [
                      // Category header
                      Padding(
                        padding: const EdgeInsets.all(16.0),
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${categoryResult.files.length} files · $categorySizeFormatted',
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: _selectedCategories[categoryKey] ?? false,
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategories[categoryKey] = value ?? false;
                                  
                                  // Recalculate total selected size
                                  _updateTotalSelectedSize(scanResults);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Files list
                      Expanded(
                        child: ListView.builder(
                          itemCount: categoryResult.files.length,
                          itemBuilder: (context, index) {
                            final file = categoryResult.files[index];
                            
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: category['color'].withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _getFileIcon(file.mimeType),
                              ),
                              title: Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${file.formattedSize} · ${_formatDate(file.date)}',
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Checkbox(
                                value: file.isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    file.isSelected = value ?? false;
                                    
                                    // If at least one file is not selected, the category is not fully selected
                                    if (!file.isSelected) {
                                      _selectedCategories[categoryKey] = false;
                                    } else {
                                      // Check if all files are now selected
                                      final allSelected = categoryResult.files.every((f) => f.isSelected);
                                      if (allSelected) {
                                        _selectedCategories[categoryKey] = true;
                                      }
                                    }
                                    
                                    // Recalculate total selected size
                                    _updateTotalSelectedSize(scanResults);
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  file.isSelected = !file.isSelected;
                                  
                                  // If at least one file is not selected, the category is not fully selected
                                  if (!file.isSelected) {
                                    _selectedCategories[categoryKey] = false;
                                  } else {
                                    // Check if all files are now selected
                                    final allSelected = categoryResult.files.every((f) => f.isSelected);
                                    if (allSelected) {
                                      _selectedCategories[categoryKey] = true;
                                    }
                                  }
                                  
                                  // Recalculate total selected size
                                  _updateTotalSelectedSize(scanResults);
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            
            // Clean button
            AnimatedBuilder(
              animation: _cleanButtonAnimation,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _totalSelectedSize > 0
                        ? () => _cleanSelectedFiles(scanResults)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'Clean ${_formatSize(_totalSelectedSize)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _updateTotalSelectedSize(Map<String, CategoryResult> scanResults) {
    int totalSize = 0;
    int totalFiles = 0;
    
    for (var entry in scanResults.entries) {
      final categoryKey = entry.key;
      final result = entry.value;
      
      if (_selectedCategories[categoryKey] == true) {
        // If the whole category is selected
        totalSize += result.totalSize;
        totalFiles += result.files.length;
        
        // Update all files in the category to be selected
        for (var file in result.files) {
          file.isSelected = true;
        }
      } else {
        // Count individually selected files
        for (var file in result.files) {
          if (file.isSelected) {
            totalSize += file.size;
            totalFiles++;
          }
        }
      }
    }
    
    setState(() {
      _totalSelectedSize = totalSize;
      _totalSelectedFiles = totalFiles;
    });
    
    // Animate the clean button if there are items to clean
    if (totalSize > 0 && !_cleanButtonController.isAnimating) {
      _cleanButtonController.forward(from: 0.0);
    }
  }
  
  Future<void> _cleanSelectedFiles(Map<String, CategoryResult> scanResults) async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cleaning files...'),
          ],
        ),
      ),
    );
    
    try {
      // Process each category
      for (var entry in scanResults.entries) {
        final categoryKey = entry.key;
        final result = entry.value;
        
        if (_selectedCategories[categoryKey] == true) {
          // Clean all files in the category
          for (var file in result.files) {
            await _deleteFile(file.path);
          }
        } else {
          // Clean individually selected files
          for (var file in result.files) {
            if (file.isSelected) {
              await _deleteFile(file.path);
            }
          }
        }
      }
      
      // Close the loading dialog
      if (mounted) {
        Navigator.pop(context);
        
        // Navigate to the success screen
        Navigator.pushReplacementNamed(
          context,
          '/cleaner_success',
          arguments: {
            'totalCleaned': _totalSelectedSize,
            'filesCount': _totalSelectedFiles,
          },
        );
      }
    } catch (e) {
      // Close the loading dialog
      if (mounted) {
        Navigator.pop(context);
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to clean files: $e'),
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
  
  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting file: $e');
      // Continue with other files even if one fails
    }
  }
  
  Widget _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return const Icon(Icons.image, color: Colors.blue);
    } else if (mimeType.startsWith('video/')) {
      return const Icon(Icons.videocam, color: Colors.red);
    } else if (mimeType.startsWith('audio/')) {
      return const Icon(Icons.audiotrack, color: Colors.green);
    } else if (mimeType.contains('pdf')) {
      return const Icon(Icons.picture_as_pdf, color: Colors.red);
    } else if (mimeType.contains('word') || mimeType.contains('doc')) {
      return const Icon(Icons.description, color: Colors.blue);
    } else if (mimeType.contains('excel') || mimeType.contains('sheet')) {
      return const Icon(Icons.table_chart, color: Colors.green);
    } else if (mimeType.contains('powerpoint') || mimeType.contains('presentation')) {
      return const Icon(Icons.slideshow, color: Colors.orange);
    } else if (mimeType.contains('zip') || mimeType.contains('archive')) {
      return const Icon(Icons.archive, color: Colors.amber);
    } else {
      return const Icon(Icons.insert_drive_file, color: Colors.grey);
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
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
