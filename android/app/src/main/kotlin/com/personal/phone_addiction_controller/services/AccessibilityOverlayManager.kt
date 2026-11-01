package com.personal.phone_addiction_controller.services

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.personal.phone_addiction_controller.MainActivity

/**
 * Manages the non-intrusive Accessibility Overlay displayed over blocked applications.
 *
 * Uses [WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY], which allows an active
 * AccessibilityService to safely cover a blocked application without requiring
 * SYSTEM_ALERT_WINDOW permission, without launching MainActivity, and without
 * hijacking the native Samsung One UI launcher.
 */
class AccessibilityOverlayManager(private val service: AccessibilityService) {

    private val windowManager: WindowManager =
        service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var overlayView: View? = null
    private var currentBlockedPackage: String? = null

    companion object {
        private const val TAG = "A11yOverlay"
    }

    /**
     * Displays or updates the blocking overlay over the target application.
     */
    fun showOverlay(packageName: String, appName: String) {
        mainHandler.post {
            try {
                if (overlayView != null && currentBlockedPackage == packageName) {
                    // Overlay is already present for this package
                    return@post
                }

                // If overlay exists for a different package, remove it first
                hideOverlayInternal()

                currentBlockedPackage = packageName
                val view = createOverlayLayout(packageName, appName)
                overlayView = view

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.CENTER
                }

                windowManager.addView(view, params)
                Log.d(TAG, "Blocking overlay shown for $appName ($packageName)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to show blocking overlay", e)
            }
        }
    }

    /**
     * Safely dismisses the blocking overlay when an allowed application or Home becomes foreground.
     */
    fun hideOverlay() {
        mainHandler.post {
            hideOverlayInternal()
        }
    }

    private fun hideOverlayInternal() {
        overlayView?.let {
            try {
                windowManager.removeView(it)
                Log.d(TAG, "Blocking overlay dismissed for $currentBlockedPackage")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to remove blocking overlay view", e)
            }
        }
        overlayView = null
        currentBlockedPackage = null
    }

    /**
     * Programmatically constructs the modern, clean blocking UI card.
     */
    private fun createOverlayLayout(packageName: String, appName: String): View {
        val density = service.resources.displayMetrics.density

        fun dp(value: Int): Int = (value * density).toInt()

        // Root container: Full-screen semi-transparent dimmed backdrop
        val root = FrameLayout(service).apply {
            setBackgroundColor(Color.parseColor("#E60B0F19")) // 90% opacity deep slate
            isClickable = true
            isFocusable = true
            isFocusableInTouchMode = true
        }

        // Card Container: Elevated white card
        val card = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(28), dp(32), dp(28), dp(28))

            val cardBg = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp(24).toFloat()
            }
            background = cardBg
            elevation = dp(16).toFloat()
        }

        val cardParams = FrameLayout.LayoutParams(
            dp(320),
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }

        // 1. Icon Badge (Red Shield / Lock)
        val icon = ImageView(service).apply {
            setImageResource(android.R.drawable.ic_lock_lock)
            setColorFilter(Color.parseColor("#EF4444")) // Coral Red
            val iconSize = dp(48)
            layoutParams = LinearLayout.LayoutParams(iconSize, iconSize).apply {
                bottomMargin = dp(16)
            }
        }
        card.addView(icon)

        // 2. Title
        val title = TextView(service).apply {
            text = "Blocked during Focus Mode"
            textSize = 20f
            setTextColor(Color.parseColor("#0F172A")) // Dark Navy
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
        }
        card.addView(title)

        // 3. Subtitle / Description
        val subtitle = TextView(service).apply {
            text = "$appName is paused under active Focus limits."
            textSize = 14f
            setTextColor(Color.parseColor("#64748B")) // Slate Muted
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(24)
            }
        }
        card.addView(subtitle)

        // 4. Primary Button: Return to Home
        val btnHome = Button(service).apply {
            text = "Return to Home"
            setTextColor(Color.WHITE)
            textSize = 15f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            isAllCaps = false

            val btnBg = GradientDrawable().apply {
                setColor(Color.parseColor("#EF4444")) // Coral Red
                cornerRadius = dp(14).toFloat()
            }
            background = btnBg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(48)
            ).apply {
                bottomMargin = dp(10)
            }

            setOnClickListener {
                service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                hideOverlayInternal()
            }
        }
        card.addView(btnHome)

        // 5. Secondary Button: Admin Unlock / Emergency
        val btnAdmin = TextView(service).apply {
            text = "Emergency / Admin Unlock"
            setTextColor(Color.parseColor("#64748B"))
            textSize = 13f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(dp(8), dp(8), dp(8), dp(8))
            isClickable = true

            setOnClickListener {
                hideOverlayInternal()
                val intent = Intent(service, MainActivity::class.java).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    )
                    putExtra("open_emergency_override", true)
                }
                service.startActivity(intent)
            }
        }
        card.addView(btnAdmin)

        root.addView(card, cardParams)

        // Intercept Back button key event on overlay
        root.setOnKeyListener { _, keyCode, event ->
            if (keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP) {
                service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                hideOverlayInternal()
                true
            } else {
                false
            }
        }

        return root
    }
}
