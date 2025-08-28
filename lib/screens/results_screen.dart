import 'dart:io';

import 'package:flutter/material.dart';
import 'package:storage_cleaner_app/screens/scan_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  // Selected categories for cleaning
  final Map<String, bool> _selectedCategories = {};
  double _totalSelectedSize = 0.0;
  
  @override
  Widget build(BuildContext context) {
    // Get scan results from arguments
    final scanResults = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    
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
    double totalSizeBytes = 0.0;
    if (_selectedCategories.isEmpty) {
      for (var entry in scanResults.entries) {
        if (entry.value is ScanResult) {
          final result = entry.value as ScanResult;
          totalSizeBytes += result.sizeInBytes;
          _selectedCategories[entry.key] = true; // By default, select all categories
        }
      }
      _totalSelectedSize = totalSizeBytes;
    }
    
    // Format total size
    final totalSizeFormatted = _formatSize(totalSizeBytes);
    final selectedSizeFormatted = _formatSize(_totalSelectedSize);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan Results',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with total size found
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Potential Space to Clean',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    totalSizeFormatted,
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selected: $selectedSizeFormatted',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
            // Category list with checkboxes
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: scanResults.length,
                itemBuilder: (context, index) {
                  final entry = scanResults.entries.elementAt(index);
                  if (entry.value is! ScanResult) return const SizedBox.shrink();
                  
                  final result = entry.value as ScanResult;
                  final isSelected = _selectedCategories[entry.key] ?? false;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategories[entry.key] = value ?? false;
                          _recalculateTotalSelectedSize(scanResults);
                        });
                      },
                      title: Text(
                        result.categoryName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${result.files.length} items',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                      ),
                      secondary: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            result.formattedSize,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            _getCategoryTypeIcon(result.categoryName),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      activeColor: Theme.of(context).colorScheme.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Clean button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _totalSelectedSize > 0
                    ? () => _cleanSelectedFiles(scanResults)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cleaning_services, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Clean $_selectedCategories Items',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Get category type icon or emoji
  String _getCategoryTypeIcon(String categoryName) {
    switch (categoryName) {
      case 'Junk Files':
        return '🗑️ Junk';
      case 'Cache Files':
        return '📦 Cache';
      case 'Duplicate Files':
        return '🔄 Duplicates';
      case 'Large Files':
        return '📁 Large';
      case 'Temporary Files':
        return '⏱️ Temporary';
      default:
        return '📋 Files';
    }
  }
  
  // Format size to human-readable string
  String _formatSize(double bytes) {
    if (bytes < 1024) {
      return '${bytes.toStringAsFixed(1)} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
  
  // Recalculate total selected size
  void _recalculateTotalSelectedSize(Map<String, dynamic> scanResults) {
    double totalSelected = 0.0;
    
    for (var entry in scanResults.entries) {
      if (entry.value is ScanResult && (_selectedCategories[entry.key] ?? false)) {
        totalSelected += (entry.value as ScanResult).sizeInBytes;
      }
    }
    
    _totalSelectedSize = totalSelected;
  }
  
  // Clean selected files
  void _cleanSelectedFiles(Map<String, dynamic> scanResults) async {
    // Show loading dialog
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
    
    // Simulate cleaning process
    await Future.delayed(const Duration(seconds: 2));
    
    // In a real app, you would delete the files here
    // For this demo, we'll just simulate successful cleaning
    
    // Navigate to success screen
    if (mounted) {
      Navigator.pop(context); // Close dialog
      Navigator.pushReplacementNamed(
        context,
        '/cleaner_success',
        arguments: {
          'cleanedSize': _totalSelectedSize,
          'itemsCount': _countSelectedItems(scanResults),
        },
      );
    }
  }
  
  // Count total selected items
  int _countSelectedItems(Map<String, dynamic> scanResults) {
    int count = 0;
    
    for (var entry in scanResults.entries) {
      if (entry.value is ScanResult && (_selectedCategories[entry.key] ?? false)) {
        count += (entry.value as ScanResult).files.length;
      }
    }
    
    return count;
  }
}
