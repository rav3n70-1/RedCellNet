package com.example.red_cell_net

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.redcellnet.lifepulse/native_bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canCheckBiometrics" -> {
                        val bm = BiometricManager.from(this)
                        val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or
                                BiometricManager.Authenticators.BIOMETRIC_WEAK or
                                BiometricManager.Authenticators.DEVICE_CREDENTIAL
                        val canAuth = bm.canAuthenticate(authenticators) == BiometricManager.BIOMETRIC_SUCCESS
                        result.success(canAuth)
                    }

                    "authenticateBiometric" -> {
                        val reason = call.argument<String>("reason")
                            ?: "Unlock RedCellNet LifePulse with Face or Fingerprint"
                        showBiometricPrompt(reason, result)
                    }

                    "updateHomeWidget" -> {
                        val prefs = getSharedPreferences(
                            RedCellNetWidgetProvider.PREFS_NAME,
                            Context.MODE_PRIVATE
                        )
                        prefs.edit().apply {
                            putString("donor_name", call.argument<String>("donorName") ?: "RedCellNet Lifesaver")
                            putString("donor_id", call.argument<String>("donorId") ?: "")
                            putString("blood_type", call.argument<String>("bloodType") ?: "?")
                            putBoolean("is_verified", call.argument<Boolean>("isVerified") ?: false)
                            putString("verification_status", call.argument<String>("verificationStatus") ?: "pending")
                            putString("eligibility_text", call.argument<String>("eligibilityText") ?: "Ready to Save Lives")
                            putBoolean("is_eligible", call.argument<Boolean>("isEligible") ?: true)
                            putString("stats_text", call.argument<String>("statsText") ?: "Tap to Open")
                            apply()
                        }
                        RedCellNetWidgetProvider.updateAllWidgets(this)
                        result.success(true)
                    }

                    "requestPinHomeWidget" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        val provider = ComponentName(this, RedCellNetWidgetProvider::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.isRequestPinAppWidgetSupported) {
                            val pinned = manager.requestPinAppWidget(provider, null, null)
                            result.success(pinned)
                        } else {
                            RedCellNetWidgetProvider.updateAllWidgets(this)
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun showBiometricPrompt(reason: String, result: MethodChannel.Result) {
        val executor = ContextCompat.getMainExecutor(this)
        var completed = false

        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                super.onAuthenticationSucceeded(authResult)
                if (!completed) {
                    completed = true
                    result.success(true)
                }
            }

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                super.onAuthenticationError(errorCode, errString)
                if (!completed) {
                    completed = true
                    result.success(false)
                }
            }
        }

        val prompt = BiometricPrompt(this, executor, callback)
        val authenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.BIOMETRIC_WEAK or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("RedCellNet Biometric Security")
            .setSubtitle(reason)
            .setAllowedAuthenticators(authenticators)
            .build()

        prompt.authenticate(promptInfo)
    }
}
