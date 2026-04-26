package com.example.havbits

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "atobits/system_settings"
	private var quoteOverlay: View? = null

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		showQuoteOverlayIfNeeded()
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		flutterEngine.renderer.addIsDisplayingFlutterUiListener(
			object : FlutterUiDisplayListener {
				override fun onFlutterUiDisplayed() {
					runOnUiThread { removeQuoteOverlay() }
				}

				override fun onFlutterUiNoLongerDisplayed() {
					// No-op
				}
			},
		)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"openAppNotificationSettings" -> result.success(openAppNotificationSettings())
					"openAppSettings" -> result.success(openAppSettings())
					"openBatteryOptimizationSettings" -> result.success(openBatteryOptimizationSettings())
						"isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
						"requestIgnoreBatteryOptimizations" -> result.success(requestIgnoreBatteryOptimizations())
					"openTtsSettings" -> result.success(openTtsSettings())
					else -> result.notImplemented()
				}
			}
	}

	private fun showQuoteOverlayIfNeeded() {
		if (quoteOverlay != null) return

		val isDark = readFlutterDarkModePreference() ?: isSystemInDarkMode()

		val root = FrameLayout(this)
		root.setBackgroundColor(if (isDark) 0xFF121212.toInt() else 0xFFFFFFFF.toInt())

		val quote = TextView(this)
		quote.text = "\u201CConsistency beats intensity.\u201D"
		quote.setTextColor(if (isDark) 0xFF3B82F6.toInt() else 0xFF0075DE.toInt())
		quote.textSize = 18f
		quote.setLineSpacing(0f, 1.05f)
		quote.gravity = Gravity.CENTER
		quote.setPadding(dp(28), 0, dp(28), 0)
		quote.setTypeface(quote.typeface, android.graphics.Typeface.BOLD)

		root.addView(
			quote,
			FrameLayout.LayoutParams(
				FrameLayout.LayoutParams.MATCH_PARENT,
				FrameLayout.LayoutParams.WRAP_CONTENT,
			).apply {
				gravity = Gravity.CENTER
			},
		)

		addContentView(
			root,
			ViewGroup.LayoutParams(
				ViewGroup.LayoutParams.MATCH_PARENT,
				ViewGroup.LayoutParams.MATCH_PARENT,
			),
		)

		quoteOverlay = root
	}

	private fun readFlutterDarkModePreference(): Boolean? {
		return try {
			val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
			val prefixed = "flutter.dark_mode"
			val raw = "dark_mode"
			when {
				prefs.contains(prefixed) -> prefs.getBoolean(prefixed, false)
				prefs.contains(raw) -> prefs.getBoolean(raw, false)
				else -> null
			}
		} catch (_: Exception) {
			null
		}
	}

	private fun isSystemInDarkMode(): Boolean {
		val mask = resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
		return mask == android.content.res.Configuration.UI_MODE_NIGHT_YES
	}

	private fun removeQuoteOverlay() {
		val overlay = quoteOverlay ?: return
		val parent = overlay.parent
		if (parent is ViewGroup) {
			parent.removeView(overlay)
		}
		quoteOverlay = null
	}

	private fun dp(value: Int): Int {
		return (value * resources.displayMetrics.density).toInt()
	}

	private fun openAppNotificationSettings(): Boolean {
		return try {
			val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
					putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
				}
			} else {
				@Suppress("DEPRECATION")
				Intent("android.settings.APP_NOTIFICATION_SETTINGS").apply {
					putExtra("app_package", packageName)
					putExtra("app_uid", applicationInfo.uid)
				}
			}

			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			startActivity(intent)
			true
		} catch (_: Exception) {
			openAppSettings()
		}
	}

	private fun openAppSettings(): Boolean {
		return try {
			val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
				data = Uri.parse("package:$packageName")
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			}
			startActivity(intent)
			true
		} catch (_: Exception) {
			false
		}
	}

	private fun openBatteryOptimizationSettings(): Boolean {
		return try {
			val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			}
			startActivity(intent)
			true
		} catch (_: Exception) {
			false
		}
	}

	private fun isIgnoringBatteryOptimizations(): Boolean {
		return try {
			if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
			val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
			pm.isIgnoringBatteryOptimizations(packageName)
		} catch (_: Exception) {
			false
		}
	}

	private fun requestIgnoreBatteryOptimizations(): Boolean {
		return try {
			if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
			val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
				data = Uri.parse("package:$packageName")
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			}
			startActivity(intent)
			true
		} catch (_: Exception) {
			false
		}
	}

	private fun openTtsSettings(): Boolean {
		return try {
			val intent = Intent("android.settings.TTS_SETTINGS").apply {
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			}
			startActivity(intent)
			true
		} catch (_: Exception) {
			false
		}
	}
}
