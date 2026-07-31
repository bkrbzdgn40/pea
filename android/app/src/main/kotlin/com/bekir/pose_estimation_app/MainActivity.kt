package com.bekir.pose_estimation_app

import android.content.pm.ActivityInfo
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.OrientationEventListener
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val orientationHandler = Handler(Looper.getMainLooper())
    private var orientationListener: OrientationEventListener? = null
    private var pendingOrientation: Int? = null
    private var committedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT

    private val commitPendingOrientation = Runnable {
        val nextOrientation = pendingOrientation ?: return@Runnable
        pendingOrientation = null
        if (nextOrientation == committedOrientation) {
            return@Runnable
        }

        committedOrientation = nextOrientation
        requestedOrientation = nextOrientation
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestedOrientation = committedOrientation
        orientationListener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                handlePhysicalOrientation(orientation)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        requestedOrientation = committedOrientation
        orientationListener?.let { listener ->
            if (listener.canDetectOrientation()) {
                listener.enable()
            }
        }
    }

    override fun onPause() {
        orientationListener?.disable()
        clearPendingOrientation()
        super.onPause()
    }

    override fun onDestroy() {
        orientationListener?.disable()
        orientationListener = null
        clearPendingOrientation()
        super.onDestroy()
    }

    private fun handlePhysicalOrientation(orientation: Int) {
        val nextOrientation = resolveAllowedOrientation(orientation)
        if (nextOrientation == null || nextOrientation == committedOrientation) {
            clearPendingOrientation()
            return
        }

        if (pendingOrientation == nextOrientation) {
            return
        }

        pendingOrientation = nextOrientation
        orientationHandler.removeCallbacks(commitPendingOrientation)
        orientationHandler.postDelayed(
            commitPendingOrientation,
            ORIENTATION_STABILITY_DELAY_MS,
        )
    }

    private fun clearPendingOrientation() {
        pendingOrientation = null
        orientationHandler.removeCallbacks(commitPendingOrientation)
    }

    private fun resolveAllowedOrientation(orientation: Int): Int? {
        if (orientation == OrientationEventListener.ORIENTATION_UNKNOWN) {
            return null
        }

        return when {
            circularDistance(orientation, PORTRAIT_UP_DEGREES) <=
                ORIENTATION_TARGET_TOLERANCE_DEGREES ->
                ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            circularDistance(orientation, LANDSCAPE_LEFT_DEGREES) <=
                ORIENTATION_TARGET_TOLERANCE_DEGREES ->
                ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            else -> null
        }
    }

    private fun circularDistance(first: Int, second: Int): Int {
        val directDistance = kotlin.math.abs(first - second)
        return minOf(directDistance, FULL_ROTATION_DEGREES - directDistance)
    }

    private companion object {
        const val PORTRAIT_UP_DEGREES = 0
        const val LANDSCAPE_LEFT_DEGREES = 270
        const val FULL_ROTATION_DEGREES = 360
        const val ORIENTATION_TARGET_TOLERANCE_DEGREES = 24
        const val ORIENTATION_STABILITY_DELAY_MS = 650L
    }
}
