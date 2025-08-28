package com.example.storage_cleaner_app

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.storage_cleaner_app/file_scanner"
    private val EVENT_CHANNEL = "com.example.storage_cleaner_app/file_scanner_progress"
    private lateinit var fileScanner: FileScanner_Fixed
    private var progressEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize the file scanner with fixed implementation
        fileScanner = FileScanner_Fixed(context)
        
        // Set up method channel for file scanning operations
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFiles" -> {
                    fileScanner.scanFiles(result)
                }
                "scanFilesWithProgress" -> {
                    fileScanner.scanFilesWithProgress({ progressUpdate ->
                        progressEventSink?.success(progressUpdate.toString())
                    }, result)
                }
                "cancelScan" -> {
                    fileScanner.cancelScan()
                    result.success(null)
                }
                "getFileSize" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val size = java.io.File(path).length()
                        result.success(size)
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                "formatFileSize" -> {
                    val size = call.argument<Long>("size")
                    if (size != null) {
                        val formattedSize = fileScanner.formatFileSize(size)
                        result.success(formattedSize)
                    } else {
                        result.error("INVALID_SIZE", "Size is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Set up event channel for progress updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressEventSink = events
                }
                
                override fun onCancel(arguments: Any?) {
                    progressEventSink = null
                }
            }
        )
    }
}
