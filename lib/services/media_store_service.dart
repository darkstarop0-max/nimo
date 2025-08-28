import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

// File model to represent file information
class FileInfo {
  final int? id;
  final String name;
  final String path;
  final int size;
  final DateTime date;
  final String mimeType;
  final String category;
  bool isSelected;

  FileInfo({
    this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.date,
    required this.mimeType,
    required this.category,
    this.isSelected = false,
  });

  // Convert file size to human-readable format
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      size: json['size'],
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      mimeType: json['mimeType'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'size': size,
      'date': date.millisecondsSinceEpoch,
      'mimeType': mimeType,
      'category': category,
    };
  }
}

// Model for scan progress updates
class ScanProgress {
  final String category;
  final double progress;
  final int filesScanned;
  final int totalSize;
  final int? filesInCategory;
  final int? sizeInCategory;
  final String status;

  ScanProgress({
    required this.category,
    required this.progress,
    required this.filesScanned,
    required this.totalSize,
    this.filesInCategory,
    this.sizeInCategory,
    required this.status,
  });

  factory ScanProgress.fromJson(Map<String, dynamic> json) {
    return ScanProgress(
      category: json['category'],
      progress: json['progress'],
      filesScanned: json['filesScanned'],
      totalSize: json['totalSize'],
      filesInCategory: json['filesInCategory'],
      sizeInCategory: json['sizeInCategory'],
      status: json['status'],
    );
  }
}

// Category result model
class CategoryResult {
  final String category;
  final List<FileInfo> files;
  final int totalSize;

  CategoryResult({
    required this.category,
    required this.files,
    required this.totalSize,
  });
}

// Service to handle file scanning
class MediaStoreService {
  static final MediaStoreService _instance = MediaStoreService._internal();
  
  factory MediaStoreService() => _instance;
  
  MediaStoreService._internal();

  // Method channel for communication with native code
  static const MethodChannel _channel = MethodChannel('com.example.storage_cleaner_app/file_scanner');
  
  // Event channel for progress updates
  static const EventChannel _eventChannel = EventChannel('com.example.storage_cleaner_app/file_scanner_progress');
  
  // Stream controller for progress updates
  final _progressController = StreamController<ScanProgress>.broadcast();
  Stream<ScanProgress> get progressStream => _progressController.stream;
  
  // Flag to track if a scan is in progress
  bool _isScanning = false;
  bool get isScanning => _isScanning;
  
  // Initialize the service and setup event listeners
  Future<void> initialize() async {
    // Listen to progress updates from the native side
    _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      final Map<String, dynamic> progressData = json.decode(event);
      final progress = ScanProgress.fromJson(progressData);
      _progressController.add(progress);
    }, onError: (dynamic error) {
      print('Error receiving progress updates: $error');
    });
  }
  
  // Start scanning files
  Future<Map<String, CategoryResult>> scanFiles() async {
    if (_isScanning) {
      throw Exception('A scan is already in progress');
    }
    
    _isScanning = true;
    
    try {
      // Call the native method to start scanning
      final String result = await _channel.invokeMethod('scanFilesWithProgress');
      final Map<String, dynamic> scanData = json.decode(result);
      
      // Process the scan results
      final Map<String, CategoryResult> categoryResults = {};
      
      scanData.forEach((key, value) {
        if (key != 'summary') {
          final List<dynamic> filesList = value;
          final List<FileInfo> files = filesList
              .map((fileJson) => FileInfo.fromJson(Map<String, dynamic>.from(fileJson)))
              .toList();
          
          final int totalSize = files.fold(0, (sum, file) => sum + file.size);
          
          categoryResults[key] = CategoryResult(
            category: key,
            files: files,
            totalSize: totalSize,
          );
        }
      });
      
      return categoryResults;
    } catch (e) {
      print('Error scanning files: $e');
      throw Exception('Failed to scan files: $e');
    } finally {
      _isScanning = false;
    }
  }
  
  // Cancel the current scan
  Future<void> cancelScan() async {
    if (_isScanning) {
      await _channel.invokeMethod('cancelScan');
      _isScanning = false;
    }
  }
  
  // Get file size for a specific file
  Future<int> getFileSize(String path) async {
    try {
      final int size = await _channel.invokeMethod('getFileSize', {'path': path});
      return size;
    } catch (e) {
      print('Error getting file size: $e');
      return 0;
    }
  }
  
  // Format file size using native code
  Future<String> formatFileSize(int size) async {
    try {
      final String formattedSize = await _channel.invokeMethod('formatFileSize', {'size': size});
      return formattedSize;
    } catch (e) {
      print('Error formatting file size: $e');
      return '0 B';
    }
  }
  
  // Dispose resources
  void dispose() {
    _progressController.close();
  }
}
