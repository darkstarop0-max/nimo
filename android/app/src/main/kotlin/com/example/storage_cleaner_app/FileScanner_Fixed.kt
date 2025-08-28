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
    private var isActive = true
    
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
        // Reset the active flag
        isActive = true
        
        coroutineScope.launch(Dispatchers.IO) {
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
                    // Skip if scan was cancelled
                    if (!isActive) {
                        return@forEachIndexed
                    }
                    
                    // Create progress object for initial category start
                    val progressUpdate = JSONObject().apply {
                        put("category", category)
                        put("progress", progressPercent)
                        put("filesScanned", totalFilesScanned)
                        put("totalSize", totalSize)
                        put("status", "scanning")
                    }
                    
                    // Send progress update on the main thread
                    withContext(Dispatchers.Main) {
                        progressCallback(progressUpdate)
                    }
                    
                    // Different scan based on category - runs on IO thread
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
                    
                    // Skip if scan was cancelled
                    if (!isActive) {
                        return@forEachIndexed
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
                    
                    // Send progress update on the main thread
                    withContext(Dispatchers.Main) {
                        progressCallback(categoryCompleteUpdate)
                    }
                    
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
                
                // Send final update on the main thread
                withContext(Dispatchers.Main) {
                    progressCallback(finalUpdate)
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

    // Cancel the current scan
    fun cancelScan() {
        isActive = false
    }
    
    // Format file size for display
    fun formatFileSize(size: Long): String {
        if (size < 1024) {
            return "$size B"
        } else if (size < 1024 * 1024) {
            val kilobytes = size / 1024.0
            return String.format("%.1f KB", kilobytes)
        } else if (size < 1024 * 1024 * 1024) {
            val megabytes = size / (1024.0 * 1024.0)
            return String.format("%.1f MB", megabytes)
        } else {
            val gigabytes = size / (1024.0 * 1024.0 * 1024.0)
            return String.format("%.1f GB", gigabytes)
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
        
        contentResolver.query(
            MediaStore.Files.getContentUri("external"),
            projection,
            selection,
            selectionArgs,
            null
        )?.use { cursor ->
            processCursorInBatches(cursor, "junk") { jsonArray, count, size ->
                results.putAll(jsonArray)
                filesCount += count
                totalSize += size
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    // Process a cursor in batches to avoid memory issues
    private suspend fun processCursorInBatches(
        cursor: Cursor,
        category: String,
        onBatchProcessed: (JSONArray, Int, Long) -> Unit
    ) {
        val idColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns._ID)
        val nameColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.DISPLAY_NAME)
        val sizeColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.SIZE)
        val dataColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.DATA)
        val dateColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.DATE_MODIFIED)
        val mimeTypeColumn = cursor.getColumnIndex(MediaStore.Files.FileColumns.MIME_TYPE)
        
        var currentBatch = JSONArray()
        var batchCount = 0
        var batchSize = 0L
        
        while (cursor.moveToNext() && isActive) {
            val id = if (idColumn != -1) cursor.getLong(idColumn) else null
            val name = if (nameColumn != -1) cursor.getString(nameColumn) else "Unknown"
            val size = if (sizeColumn != -1) cursor.getLong(sizeColumn) else 0
            val path = if (dataColumn != -1) cursor.getString(dataColumn) else ""
            val date = if (dateColumn != -1) cursor.getLong(dateColumn) * 1000 else System.currentTimeMillis()
            val mimeType = if (mimeTypeColumn != -1) cursor.getString(mimeTypeColumn) ?: "application/octet-stream" else "application/octet-stream"
            
            // Skip files with size 0 or invalid paths
            if (size > 0 && path.isNotEmpty()) {
                val fileObject = JSONObject().apply {
                    id?.let { put("id", it) }
                    put("name", name)
                    put("path", path)
                    put("size", size)
                    put("date", date)
                    put("mimeType", mimeType)
                    put("category", category)
                }
                
                currentBatch.put(fileObject)
                batchCount++
                batchSize += size
                
                if (batchCount >= BATCH_SIZE) {
                    onBatchProcessed(currentBatch, batchCount, batchSize)
                    currentBatch = JSONArray()
                    batchCount = 0
                    batchSize = 0
                    
                    // Small yield to allow other coroutines to run
                    yield()
                }
            }
        }
        
        // Process remaining files in the batch
        if (batchCount > 0) {
            onBatchProcessed(currentBatch, batchCount, batchSize)
        }
    }
    
    // Implementation of other scanning methods
    // These would follow a similar pattern to scanJunkFiles
    
    private suspend fun scanCacheFiles(): Triple<JSONArray, Int, Long> {
        val results = JSONArray()
        var filesCount = 0
        var totalSize = 0L
        
        // Cache files can be found in specific directories
        val externalCacheDir = context.externalCacheDir
        if (externalCacheDir != null && externalCacheDir.exists()) {
            traverseDirectory(externalCacheDir, "cache") { jsonArray, count, size ->
                results.putAll(jsonArray)
                filesCount += count
                totalSize += size
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    private suspend fun scanMediaFiles(contentUri: Uri): Triple<JSONArray, Int, Long> {
        val results = JSONArray()
        var filesCount = 0
        var totalSize = 0L
        
        val category = when (contentUri) {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI -> "images"
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI -> "videos"
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI -> "audio"
            else -> "other"
        }
        
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATA,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.MIME_TYPE
        )
        
        contentResolver.query(
            contentUri,
            projection,
            null,
            null,
            null
        )?.use { cursor ->
            processCursorInBatches(cursor, category) { jsonArray, count, size ->
                results.putAll(jsonArray)
                filesCount += count
                totalSize += size
            }
        }
        
        return Triple(results, filesCount, totalSize)
    }
    
    // Placeholder for remaining methods - would need to be implemented fully
    private suspend fun scanDocumentFiles(): Triple<JSONArray, Int, Long> = Triple(JSONArray(), 0, 0L)
    private suspend fun scanDownloadFiles(): Triple<JSONArray, Int, Long> = Triple(JSONArray(), 0, 0L)
    private suspend fun scanLargeFiles(): Triple<JSONArray, Int, Long> = Triple(JSONArray(), 0, 0L)
    private suspend fun scanDuplicateFiles(): Triple<JSONArray, Int, Long> = Triple(JSONArray(), 0, 0L)
    private suspend fun scanTemporaryFiles(): Triple<JSONArray, Int, Long> = Triple(JSONArray(), 0, 0L)
    
    // Recursive directory traversal with batching
    private suspend fun traverseDirectory(
        directory: File,
        category: String,
        onBatchProcessed: (JSONArray, Int, Long) -> Unit
    ) {
        if (!isActive) return
        
        val files = directory.listFiles() ?: return
        
        var currentBatch = JSONArray()
        var batchCount = 0
        var batchSize = 0L
        
        for (file in files) {
            if (!isActive) break
            
            if (file.isDirectory) {
                traverseDirectory(file, category, onBatchProcessed)
            } else {
                val size = file.length()
                
                if (size > 0) {
                    val fileObject = JSONObject().apply {
                        put("name", file.name)
                        put("path", file.absolutePath)
                        put("size", size)
                        put("date", file.lastModified())
                        put("mimeType", getMimeType(file.name))
                        put("category", category)
                    }
                    
                    currentBatch.put(fileObject)
                    batchCount++
                    batchSize += size
                    
                    if (batchCount >= BATCH_SIZE) {
                        onBatchProcessed(currentBatch, batchCount, batchSize)
                        currentBatch = JSONArray()
                        batchCount = 0
                        batchSize = 0
                        
                        yield()
                    }
                }
            }
        }
        
        if (batchCount > 0) {
            onBatchProcessed(currentBatch, batchCount, batchSize)
        }
    }
    
    private fun getMimeType(fileName: String): String {
        val extension = fileName.substringAfterLast('.', "").toLowerCase(Locale.ROOT)
        return when (extension) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "mp4" -> "video/mp4"
            "mp3" -> "audio/mp3"
            "pdf" -> "application/pdf"
            "doc", "docx" -> "application/msword"
            "xls", "xlsx" -> "application/vnd.ms-excel"
            "txt" -> "text/plain"
            else -> "application/octet-stream"
        }
    }
}
