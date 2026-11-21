package com.feiyu.whale_diary

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val channelName = "whale_diary/asr"
    private var channel: MethodChannel? = null
    private var recognizer: Recognizer? = null
    private var record: AudioRecord? = null

    // 模型放在进程级：Activity 重建时不能重新加载第二份（一份就 1~2 GB）
    companion object {
        @Volatile
        private var sharedModel: Model? = null

        @Volatile
        private var sharedPath: String? = null

        @Synchronized
        private fun obtainModel(path: String): Model {
            val current = sharedModel
            if (current != null && sharedPath == path) return current
            // 路径变了或首次加载：先关掉旧的再建新的
            try {
                current?.close()
            } catch (_: Exception) {
            }
            val fresh = Model(path)
            sharedModel = fresh
            sharedPath = path
            return fresh
        }

        @Synchronized
        private fun closeSharedModel() {
            try {
                sharedModel?.close()
            } catch (_: Exception) {
            }
            sharedModel = null
            sharedPath = null
        }
    }

    @Volatile
    private var running = false
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "ensurePermission" -> ensurePermission(result)
                "init" -> initModel(call.argument<String>("path") ?: "", result)
                "start" -> startRecognition(result)
                "stop" -> {
                    running = false
                    result.success(true)
                }
                "release" -> {
                    // 只放掉识别器，模型留着复用（下次进语音页秒开）
                    running = false
                    try {
                        recognizer?.close()
                    } catch (_: Exception) {
                    }
                    recognizer = null
                    result.success(true)
                }
                "releaseAll" -> {
                    running = false
                    try {
                        recognizer?.close()
                    } catch (_: Exception) {
                    }
                    recognizer = null
                    closeSharedModel()
                    result.success(true)
                }
                "unzip" -> unzipTo(
                    call.argument<String>("zipPath") ?: "",
                    call.argument<String>("destDir") ?: "",
                    result
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun ensurePermission(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
        } else {
            pendingPermission = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                1001
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            pendingPermission?.success(
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            pendingPermission = null
        }
    }

    @Synchronized
    private fun initModel(path: String, result: MethodChannel.Result) {
        // 大模型加载要几秒，放到后台线程，别卡 UI
        thread {
            try {
                val model = obtainModel(path)
                // 每次都换一个干净的识别器，避免上一轮的残留状态
                try {
                    recognizer?.close()
                } catch (_: Exception) {
                }
                recognizer = Recognizer(model, 16000.0f)
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("init_failed", e.message, null) }
            }
        }
    }

    private fun startRecognition(result: MethodChannel.Result) {
        val rec = recognizer
        if (rec == null) {
            result.error("no_model", "model not initialized", null)
            return
        }
        running = true
        result.success(true)
        thread {
            val rate = 16000
            val minBuf = AudioRecord.getMinBufferSize(
                rate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val buffer = ByteArray(maxOf(minBuf, 4096))
            val audio = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                rate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                buffer.size * 2
            )
            record = audio
            try {
                audio.startRecording()
                while (running) {
                    val n = audio.read(buffer, 0, buffer.size)
                    if (n > 0) {
                        if (rec.acceptWaveForm(buffer, n)) {
                            val text = parseText(rec.result)
                            if (text.isNotBlank()) {
                                runOnUiThread { channel?.invokeMethod("final", text) }
                            }
                        } else {
                            val text = parseText(rec.partialResult)
                            if (text.isNotBlank()) {
                                runOnUiThread { channel?.invokeMethod("partial", text) }
                            }
                        }
                    }
                }
                val finalText = parseText(rec.finalResult)
                if (finalText.isNotBlank()) {
                    runOnUiThread { channel?.invokeMethod("final", finalText) }
                }
            } catch (e: Exception) {
                runOnUiThread { channel?.invokeMethod("error", e.message ?: "asr error") }
            } finally {
                try {
                    audio.stop()
                } catch (_: Exception) {
                }
                audio.release()
            }
        }
    }

    private fun parseText(json: String): String {
        return try {
            val obj = JSONObject(json)
            obj.optString("text", obj.optString("partial", ""))
        } catch (e: Exception) {
            ""
        }
    }

    private fun unzipTo(zipPath: String, destDir: String, result: MethodChannel.Result) {
        thread {
            try {
                java.util.zip.ZipInputStream(java.io.FileInputStream(zipPath)).use { zis ->
                    var entry = zis.nextEntry
                    while (entry != null) {
                        val outFile = java.io.File(destDir, entry.name)
                        if (entry.isDirectory) {
                            outFile.mkdirs()
                        } else {
                            outFile.parentFile?.mkdirs()
                            java.io.FileOutputStream(outFile).use { fos ->
                                zis.copyTo(fos)
                            }
                        }
                        zis.closeEntry()
                        entry = zis.nextEntry
                    }
                }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("unzip_failed", e.message, null) }
            }
        }
    }
}

