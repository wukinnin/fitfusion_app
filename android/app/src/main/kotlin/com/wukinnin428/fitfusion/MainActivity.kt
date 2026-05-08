package com.wukinnin428.fitfusion

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Handler
import android.os.Looper
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "fitfusion/mediapipe_pose"
    private val poseDetectionTimeoutMs = 1200L
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var poseLandmarker: PoseLandmarker? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBitmapWidth: Int = 0
    private var pendingBitmapHeight: Int = 0
    private var pendingCallToken: Long = 0
    private var lastTimestampMs: Long = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "processFrame" -> processFrame(call, result)
                "close" -> closeLandmarker(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun processFrame(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.success(emptyList<List<Map<String, Any>>>())
            return
        }

        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val rotation = call.argument<Int>("rotation") ?: 0
        val planes = call.argument<List<ByteArray>>("planes")
        val bytesPerRow = call.argument<List<Int>>("bytesPerRow")
        val bytesPerPixel = call.argument<List<Int>>("bytesPerPixel")

        if (width == null ||
            height == null ||
            planes == null ||
            bytesPerRow == null ||
            bytesPerPixel == null ||
            planes.size < 3 ||
            bytesPerRow.size < 3 ||
            bytesPerPixel.size < 3
        ) {
            result.error("InvalidFrame", "Missing camera frame metadata.", null)
            return
        }

        pendingResult = result
        val callToken = ++pendingCallToken
        mainHandler.postDelayed({
            if (pendingResult === result && pendingCallToken == callToken) {
                finishPendingWithError(
                    "MediaPipeTimeout",
                    "Pose detection timed out before MediaPipe returned a result."
                )
            }
        }, poseDetectionTimeoutMs)
        executor.execute {
            try {
                val landmarker = ensurePoseLandmarker()
                val bitmap = yuv420ToBitmap(
                    width,
                    height,
                    planes,
                    bytesPerRow,
                    bytesPerPixel
                )
                val rotatedBitmap = rotateBitmap(bitmap, rotation)
                pendingBitmapWidth = rotatedBitmap.width
                pendingBitmapHeight = rotatedBitmap.height
                val mpImage = BitmapImageBuilder(rotatedBitmap).build()
                val timestamp = nextTimestampMs()
                landmarker.detectAsync(mpImage, timestamp)
            } catch (error: Throwable) {
                finishPendingWithError("MediaPipeError", error.toString())
            }
        }
    }

    private fun ensurePoseLandmarker(): PoseLandmarker {
        val existing = poseLandmarker
        if (existing != null) return existing

        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("pose_landmarker_lite.task")
            .build()
        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumPoses(2)
            // Lowered from 0.5 so the second body — typically partially
            // occluded or at the edge of the frame in multiplayer — is not
            // rejected by the native detector before it reaches Dart.
            .setMinPoseDetectionConfidence(0.3f)
            .setMinPosePresenceConfidence(0.3f)
            .setMinTrackingConfidence(0.3f)
            .setResultListener(this::onPoseResult)
            .setErrorListener { error -> finishPendingWithError("MediaPipeError", error.toString()) }
            .build()

        val created = PoseLandmarker.createFromOptions(this, options)
        poseLandmarker = created
        return created
    }

    private fun onPoseResult(result: PoseLandmarkerResult, unusedImage: Any) {
        val poses = result.landmarks().map { pose ->
            pose.mapIndexed { index, landmark ->
                mapOf(
                    "type" to index,
                    "x" to (landmark.x() * pendingBitmapWidth),
                    "y" to (landmark.y() * pendingBitmapHeight),
                    "z" to landmark.z(),
                    "likelihood" to landmark.visibility().orElse(landmark.presence().orElse(0.0f))
                )
            }
        }
        finishPendingSuccess(poses)
    }

    private fun finishPendingSuccess(value: Any) {
        val result = pendingResult ?: return
        pendingResult = null
        mainHandler.post { result.success(value) }
    }

    private fun finishPendingWithError(code: String, message: String) {
        val result = pendingResult ?: return
        pendingResult = null
        mainHandler.post { result.error(code, message, null) }
    }

    private fun nextTimestampMs(): Long {
        val now = System.currentTimeMillis()
        lastTimestampMs = if (now > lastTimestampMs) now else lastTimestampMs + 1
        return lastTimestampMs
    }

    private fun yuv420ToBitmap(
        width: Int,
        height: Int,
        planes: List<ByteArray>,
        bytesPerRow: List<Int>,
        bytesPerPixel: List<Int>
    ): Bitmap {
        val nv21 = ByteArray(width * height + width * height / 2)
        var offset = 0

        val yPlane = planes[0]
        val yRowStride = bytesPerRow[0]
        for (row in 0 until height) {
            System.arraycopy(yPlane, row * yRowStride, nv21, offset, width)
            offset += width
        }

        val uPlane = planes[1]
        val vPlane = planes[2]
        val uRowStride = bytesPerRow[1]
        val vRowStride = bytesPerRow[2]
        val uPixelStride = bytesPerPixel[1].coerceAtLeast(1)
        val vPixelStride = bytesPerPixel[2].coerceAtLeast(1)

        for (row in 0 until height / 2) {
            for (col in 0 until width / 2) {
                val vIndex = row * vRowStride + col * vPixelStride
                val uIndex = row * uRowStride + col * uPixelStride
                nv21[offset++] = vPlane[vIndex]
                nv21[offset++] = uPlane[uIndex]
            }
        }

        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val jpeg = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 80, jpeg)
        return BitmapFactory.decodeByteArray(jpeg.toByteArray(), 0, jpeg.size())
    }

    private fun rotateBitmap(bitmap: Bitmap, rotation: Int): Bitmap {
        val normalizedRotation = ((rotation % 360) + 360) % 360
        if (normalizedRotation == 0) return bitmap
        val matrix = Matrix().apply { postRotate(normalizedRotation.toFloat()) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun closeLandmarker(result: MethodChannel.Result) {
        executor.execute {
            poseLandmarker?.close()
            poseLandmarker = null
            mainHandler.post { result.success(null) }
        }
    }

    override fun onDestroy() {
        poseLandmarker?.close()
        executor.shutdown()
        super.onDestroy()
    }
}
