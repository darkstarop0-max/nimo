package com.example.storage_cleaner_app

import android.content.ContentResolver
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.*
import kotlin.collections.ArrayList

class FileScanner(private val context: Context) {
    companion object {
        private const val TAG = "FileScanner"
        private const val BATCH_SIZE = 300  // Number of files to process in each batch
    }

    private val contentResolver: ContentResolver = context.contentResolver
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    fun scanFiles(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val scanResults = JSONObject()
                var totalFilesScanned = 0
                var totalSize = 0L
                
                // Categories to scan with their respective query parameters
                val categories = mapOf(
                    "junk" to scanJunkFiles(),
                    "cache" to scanCacheFiles(),
                    "images" to scanMediaFiles(MediaStore.Images.Media.EXTERNAL_CONTENT_URI),
                    "videos" to scanMediaFiles(MediaStore.Video.Media.EXTERNAL_CONTENT_URI),
                    "audio" to scanMediaFiles(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI),
                    "documents" to scanDocumentFiles(),
                    "downloads" to scanDownloadFiles(),
                    "large" to scanLargeFiles(),
                    "duplicates" to scanDuplicateFiles(),
                    "temporary" to scanTemporaryFiles()
                )
                
                // Process each category and update results
                categories.forEach { (category, categoryResult) ->
                    scanResults.put(category, categoryResult.first)
                    totalFilesScanned += categoryResult.second
                    totalSize += categoryResult.third
                }
                
                // Add summary information
                scanResults.put("summary", JSONObject().apply {
                    put("totalFiles", totalFilesScanned)
                    put("totalSize", totalSize)
                })
                
                withContext(Dispatchers.Main) {
                    result.success(scanResults.toString())
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error scanning files", e)
                withContext(Dispatchers.Main) {
                    result.error("SCAN_ERROR", e.message, null)
                }
            }
        }
    }
    
    // Scan files and report progress
    fun scanFilesWithProgress(progressCallback: (JSONObject) -> Unit, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val scanResults = JSONObject()
                var totalFilesScanned = 0
                var totalSize = 0L
                var progressPercent = 0.0
                
                // Define each category with weight (importance percentage of total scan)
                val categoryWeights = mapOf(
                    "junk" to 15.0,
                    "cache" to 15.0,
                    "images" to 10.0,
                    "videos" to 10.0,
                    "audio" to 10.0,
                    "documents" to 10.0,
                    "downloads" to 5.0,
                    "large" to 10.0,
                    "duplicates" to 10.0,
                    "temporary" to 5.0
                )
                
                // Process each category with progress updates
                categoryWeights.entries.forEachIndexed { index, (category, weight) ->
                    // Create progress object for initial category start
                    val progressUpdate = JSONObject().apply {
                        put("category", category)
                        put("progress", progressPercent)
                        put("filesScanned", totalFilesScanned)
                        put("totalSize", totalSize)
                        put("status", "scanning")
                    }
                    progressCallback(progressUpdate)
                    
                    // Different scan based on category
                    val categoryResult = when (category) {
                        "junk" -> scanJunkFiles()
                        "cache" -> scanCacheFiles() 
                        "images" -> scanMediaFiles(MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                        "videos" -> scanMediaFiles(MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
                        "audio" -> scanMediaFiles(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI)
                        "documents" -> scanDocumentFiles()
                        "downloads" -> scanDownloadFiles()
                        "large" -> scanLargeFiles()
                        "duplicates" -> scanDuplicateFiles()
                        "temporary" -> scanTemporaryFiles()
                        else -> Triple(JSONArray(), 0, 0L)
                    }
                    
                    // Add results to overall scan results
                    scanResults.put(category, categoryResult.first)
                    totalFilesScanned += categoryResult.second
                    totalSize += categoryResult.third
                    
                    // Update progress
                    progressPercent += weight
                    
                    // Create progress object for category completion
                    val categoryCompleteUpdate = JSONObject().apply {
                        put("category", category)
                        put("progress", progressPercent)
                        put("filesScanned", totalFilesScanned)
                        put("totalSize", totalSize)
                        put("filesInCategory", categoryResult.second)
                        put("sizeInCategory", categoryResult.third)
                        put("status", "complete")
                    }
                    progressCallback(categoryCompleteUpdate)
                    
                    // Small delay to make UI updates smoother
                    delay(100)
                }
                
                // Add summary information
                scanResults.put("summary", JSONObject().apply {
                    put("totalFiles", totalFilesScanned)
                    put("totalSize", totalSize)
                })
                
                // Final progress update
                val finalUpdate = JSONObject().apply {
                    put("category", "all")
                    put("progress", 100.0)
                    put("filesScanned", totalFilesScanned)
                    put("totalSize", totalSize)
                    put("status", "complete")
                }
                progressCallback(finalUpdate)
                
                withContext(Dispatchers.Main) {
                    result.success(scanResults.toString())
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error scanning files with progress", e)
                withContext(Dispatchers.Main) {
                    result.error("SCAN_ERROR", e.message, null)
                }
            }
        }
    }

    // Scan for junk files (cache, temporary files, etc.)
    private suspend fun scanJunkFiles(): Triple<JSONArray, Int, Long> {
        val results = JSONArray()
        var filesCount = 0
        var totalSize = 0L
        
        // Look for common junk file extensions in external storage
        val junkExtensions = listOf(".tmp", ".temp", ".log", ".old", ".bak", ".part", ".crdownload")
        
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE
        )
        
        var selection = ""
        for (ext in junkExtensions) {
            if (selection.isNotEmpty()) selection += " OR "
            selection += "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?"
        }
        
        val selectionArgs = junkExtensions.map { "%$it" }.toTypedArray()
        
        val uri = MediaStore.Files.getContentUri("external")
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val mimeTypeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            
            var batchCount = 0
            while (cursor.moveToNext()) {
                val fileSize = cursor.getLong(sizeColumn)
                if (fileSize > 0) {
                    val fileInfo = JSONObject().apply {
                        put("id", cursor.getLong(idColumn))
                        put("name", cursor.getString(nameColumn))
                        put("size", fileSize)
                        put("path", cursor.getString(dataColumn))
                        put("date", cursor.getLong(dateColumn) * 1000) // Convert to milliseconds
                        put("mimeType", cursor.getString(mimeTypeColumn) ?: "application/octet-stream")
                        put("category", "junk")
                    }
                    results.put(fileInfo)
                    filesCount++
                    totalSize += fileSize
                }
                
                // Process in batches for smoother progress updates
                batchCount++
                if (batchCount >= BATCH_SIZE) {
                    // Add a small delay to avoid UI freezing
                    delay(10)
                    batchCount = 0
                }
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    // Scan for cache files
    private suspend fun scanCacheFiles(): Triple<JSONArray, Int, Long> {
        val results = JSONArray()
        var filesCount = 0
        var totalSize = 0L
        
        // Query for cache directories
        val cacheFiles = ArrayList<File>()
        
        // External cache directories
        val externalCacheDirs = context.externalCacheDirs
        for (dir in externalCacheDirs) {
            if (dir != null && dir.exists()) {
                cacheFiles.add(dir)
            }
        }
        
        // Process cache files
        cacheFiles.forEach { cacheDir ->
            if (cacheDir.exists()) {
                cacheDir.listFiles()?.forEach { file ->
                    if (file.isFile) {
                        val fileInfo = JSONObject().apply {
                            put("name", file.name)
                            put("size", file.length())
                            put("path", file.absolutePath)
                            put("date", file.lastModified())
                            put("mimeType", "application/octet-stream")
                            put("category", "cache")
                        }
                        results.put(fileInfo)
                        filesCount++
                        totalSize += file.length()
                    }
                }
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    // Scan for media files (images, videos, audio)
    private suspend fun scanMediaFiles(uri: Uri): Triple<JSONArray, Int, Long> {
        val results = JSONArray()
        var filesCount = 0
        var totalSize = 0L
        
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATA,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.MIME_TYPE
        )
        
        // Only get files with a positive size
        val selection = "${MediaStore.MediaColumns.SIZE} > 0"
        
        contentResolver.query(uri, projection, selection, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
            val mimeTypeColumn = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
            
            // Determine category based on URI
            val category = when (uri) {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI -> "images"
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI -> "videos"
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI -> "audio"
                else -> "files"
            }
            
            var batchCount = 0
            while (cursor.moveToNext()) {
                val fileSize = cursor.getLong(sizeColumn)
                if (fileSize > 0) {
                    val fileInfo = JSONObject().apply {
                        put("id", cursor.getLong(idColumn))
                        put("name", cursor.getString(nameColumn))
                        put("size", fileSize)
                        put("path", cursor.getString(dataColumn))
                        put("date", cursor.getLong(dateColumn) * 1000) // Convert to milliseconds
                        put("mimeType", cursor.getString(mimeTypeColumn) ?: "application/octet-stream")
                        put("category", category)
                    }
                    results.put(fileInfo)
                    filesCount++
                    totalSize += fileSize
                }
                
                // Process in batches for smoother progress updates
                batchCount++
                if (batchCount >= BATCH_SIZE) {
                    // Add a small delay to avoid UI freezing
                    delay(10)
                    batchCount = 0
                }
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    // Scan for document files
    private suspend fun scanDocumentFiles(): Triple<JSONArray, Int, Long> {
        val results = JSONArray()
        var filesCount = 0
        var totalSize = 0L
        
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE
        )
        
        // Document extensions
        val docExtensions = listOf(".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt", ".rtf")
        
        var selection = ""
        for (ext in docExtensions) {
            if (selection.isNotEmpty()) selection += " OR "
            selection += "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?"
        }
        
        val selectionArgs = docExtensions.map { "%$it" }.toTypedArray()
        
        val uri = MediaStore.Files.getContentUri("external")
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val mimeTypeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            
            var batchCount = 0
            while (cursor.moveToNext()) {
                val fileSize = cursor.getLong(sizeColumn)
                if (fileSize > 0) {
                    val fileInfo = JSONObject().apply {
                        put("id", cursor.getLong(idColumn))
                        put("name", cursor.getString(nameColumn))
                        put("size", fileSize)
                        put("path", cursor.getString(dataColumn))
                        put("date", cursor.getLong(dateColumn) * 1000) // Convert to milliseconds
                        put("mimeType", cursor.getString(mimeTypeColumn) ?: "application/octet-stream")
                        put("category", "documents")
                    }
                    results.put(fileInfo)
                    filesCount++
                    totalSize += fileSize
                }
                
                // Process in batches for smoother progress updates
                batchCount++
                if (batchCount >= BATCH_SIZE) {
                    // Add a small delay to avoid UI freezing
                    delay(10)
                    batchCount = 0
                }
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    // Scan for files in the Downloads directory
    private suspend fun scanDownloadFiles(): Triple<JSONArray, Int, Long> {
        val results = JSONArray()
        var filesCount = 0
        var totalSize = 0L
        
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE
        )
        
        // For Android Q and above, we can use MediaStore.Downloads
        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Downloads.EXTERNAL_CONTENT_URI
        } else {
            // For older versions, we use a workaround with the Downloads folder path
            MediaStore.Files.getContentUri("external")
        }
        
        val selection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            null // No special selection needed for Downloads URI
        } else {
            // For older versions, we filter by path
            "${MediaStore.Files.FileColumns.DATA} LIKE ?"
        }
        
        val selectionArgs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            null
        } else {
            arrayOf("%/Download/%")
        }
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val mimeTypeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            
            var batchCount = 0
            while (cursor.moveToNext()) {
                val fileSize = cursor.getLong(sizeColumn)
                if (fileSize > 0) {
                    val fileInfo = JSONObject().apply {
                        put("id", cursor.getLong(idColumn))
                        put("name", cursor.getString(nameColumn))
                        put("size", fileSize)
                        put("path", cursor.getString(dataColumn))
                        put("date", cursor.getLong(dateColumn) * 1000) // Convert to milliseconds
                        put("mimeType", cursor.getString(mimeTypeColumn) ?: "application/octet-stream")
                        put("category", "downloads")
                    }
                    results.put(fileInfo)
                    filesCount++
                    totalSize += fileSize
                }
                
                // Process in batches for smoother progress updates
                batchCount++
                if (batchCount >= BATCH_SIZE) {
                    // Add a small delay to avoid UI freezing
                    delay(10)
                    batchCount = 0
                }
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    // Scan for large files (e.g., > 50MB)
    private suspend fun scanLargeFiles(): Triple<JSONArray, Int, Long> {
        val results = JSONArray()
        var filesCount = 0
        var totalSize = 0L
        
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE
        )
        
        // Define large file size threshold (50MB)
        val largeFileSizeThreshold = 50 * 1024 * 1024L
        
        // Query for files larger than the threshold
        val selection = "${MediaStore.Files.FileColumns.SIZE} > ?"
        val selectionArgs = arrayOf(largeFileSizeThreshold.toString())
        
        val uri = MediaStore.Files.getContentUri("external")
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val mimeTypeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            
            var batchCount = 0
            while (cursor.moveToNext()) {
                val fileSize = cursor.getLong(sizeColumn)
                val fileInfo = JSONObject().apply {
                    put("id", cursor.getLong(idColumn))
                    put("name", cursor.getString(nameColumn))
                    put("size", fileSize)
                    put("path", cursor.getString(dataColumn))
                    put("date", cursor.getLong(dateColumn) * 1000) // Convert to milliseconds
                    put("mimeType", cursor.getString(mimeTypeColumn) ?: "application/octet-stream")
                    put("category", "large")
                }
                results.put(fileInfo)
                filesCount++
                totalSize += fileSize
                
                // Process in batches for smoother progress updates
                batchCount++
                if (batchCount >= BATCH_SIZE) {
                    // Add a small delay to avoid UI freezing
                    delay(10)
                    batchCount = 0
                }
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    // Scan for duplicate files (based on size and name)
    private suspend fun scanDuplicateFiles(): Triple<JSONArray, Int, Long> {
        val results = JSONArray()
        var filesCount = 0
        var totalSize = 0L
        
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE
        )
        
        // Exclude very small files (less than 10KB)
        val minFileSize = 10 * 1024L
        val selection = "${MediaStore.Files.FileColumns.SIZE} > ?"
        val selectionArgs = arrayOf(minFileSize.toString())
        
        val uri = MediaStore.Files.getContentUri("external")
        
        // First pass: collect file info for potential duplicates
        val fileMap = mutableMapOf<String, MutableList<JSONObject>>()
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val mimeTypeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            
            var batchCount = 0
            while (cursor.moveToNext()) {
                val fileName = cursor.getString(nameColumn)
                val fileSize = cursor.getLong(sizeColumn)
                
                // Create a key based on file name and size
                val key = "$fileName:$fileSize"
                
                val fileInfo = JSONObject().apply {
                    put("id", cursor.getLong(idColumn))
                    put("name", fileName)
                    put("size", fileSize)
                    put("path", cursor.getString(dataColumn))
                    put("date", cursor.getLong(dateColumn) * 1000) // Convert to milliseconds
                    put("mimeType", cursor.getString(mimeTypeColumn) ?: "application/octet-stream")
                    put("category", "duplicates")
                }
                
                // Add to our map of potential duplicates
                fileMap.getOrPut(key) { mutableListOf() }.add(fileInfo)
                
                // Process in batches for smoother progress updates
                batchCount++
                if (batchCount >= BATCH_SIZE) {
                    // Add a small delay to avoid UI freezing
                    delay(10)
                    batchCount = 0
                }
            }
        }
        
        // Second pass: identify actual duplicates
        for ((_, fileList) in fileMap) {
            if (fileList.size > 1) {
                // These are duplicates
                for (fileInfo in fileList) {
                    results.put(fileInfo)
                    filesCount++
                    totalSize += fileInfo.getLong("size")
                }
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    // Scan for temporary files
    private suspend fun scanTemporaryFiles(): Triple<JSONArray, Int, Long> {
        val results = JSONArray()
        var filesCount = 0
        var totalSize = 0L
        
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
            MediaStore.Files.FileColumns.MIME_TYPE
        )
        
        // Temporary file patterns
        val tempPatterns = listOf(
            "%~%",           // Windows-style temp files
            "%.tmp%",        // .tmp files
            "%.temp%",       // .temp files
            "%thumb%",       // Thumbnails
            "%.bak%",        // Backup files
            "%.old%",        // Old versions
            "%cache%"        // Cache files
        )
        
        var selection = ""
        for (pattern in tempPatterns) {
            if (selection.isNotEmpty()) selection += " OR "
            selection += "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?"
        }
        
        val selectionArgs = tempPatterns.toTypedArray()
        
        val uri = MediaStore.Files.getContentUri("external")
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)
            val mimeTypeColumn = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MIME_TYPE)
            
            var batchCount = 0
            while (cursor.moveToNext()) {
                val fileSize = cursor.getLong(sizeColumn)
                if (fileSize > 0) {
                    val fileInfo = JSONObject().apply {
                        put("id", cursor.getLong(idColumn))
                        put("name", cursor.getString(nameColumn))
                        put("size", fileSize)
                        put("path", cursor.getString(dataColumn))
                        put("date", cursor.getLong(dateColumn) * 1000) // Convert to milliseconds
                        put("mimeType", cursor.getString(mimeTypeColumn) ?: "application/octet-stream")
                        put("category", "temporary")
                    }
                    results.put(fileInfo)
                    filesCount++
                    totalSize += fileSize
                }
                
                // Process in batches for smoother progress updates
                batchCount++
                if (batchCount >= BATCH_SIZE) {
                    // Add a small delay to avoid UI freezing
                    delay(10)
                    batchCount = 0
                }
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    // Helper method to format file size
    fun formatFileSize(size: Long): String {
        if (size <= 0) return "0 B"
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        val digitGroups = (Math.log10(size.toDouble()) / Math.log10(1024.0)).toInt()
        return String.format("%.1f %s", size / Math.pow(1024.0, digitGroups.toDouble()), units[digitGroups])
    }
    
    // Cancel any ongoing scan operations
    fun cancelScan() {
        coroutineScope.coroutineContext.cancelChildren()
    }
}
