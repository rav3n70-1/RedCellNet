package com.example.red_cell_net

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

class RedCellNetWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val PREFS_NAME = "rcn_widget_prefs"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)

            val passComponent = ComponentName(context, RedCellNetWidgetProvider::class.java)
            val passIds = manager.getAppWidgetIds(passComponent)
            if (passIds != null && passIds.isNotEmpty()) {
                for (id in passIds) {
                    updateAppWidget(context, manager, id)
                }
            }

            RedCellNetEmergencyWidgetProvider.updateAllEmergencyWidgets(context)
            RedCellNetCompactWidgetProvider.updateAllCompactWidgets(context)
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val donorName = prefs.getString("donor_name", "RedCellNet Lifesaver") ?: "RedCellNet Lifesaver"
            val donorId = prefs.getString("donor_id", "") ?: ""
            val bloodType = prefs.getString("blood_type", "?") ?: "?"
            val isVerified = prefs.getBoolean("is_verified", false)
            val verificationStatus = prefs.getString("verification_status", "pending") ?: "pending"
            val eligibilityText = prefs.getString("eligibility_text", "Ready to Save Lives") ?: "Ready to Save Lives"
            val isEligible = prefs.getBoolean("is_eligible", true)
            val statsText = prefs.getString("stats_text", "Tap to open RedCellNet") ?: "Tap to open RedCellNet"

            val views = RemoteViews(context.packageName, R.layout.redcellnet_app_widget)
            val headerLabel = if (donorId.isNotBlank()) {
                "REDCELLNET • $donorId"
            } else {
                "REDCELLNET • DIGITAL PASS"
            }
            views.setTextViewText(R.id.widget_brand_header, headerLabel)
            views.setTextViewText(R.id.widget_donor_name, donorName)
            views.setTextViewText(
                R.id.widget_blood_type,
                if (bloodType.isBlank()) "?" else bloodType
            )

            val isVerifiedResolved = isVerified || verificationStatus.lowercase().contains("verified")
            val verifyLabel = if (isVerifiedResolved) {
                "✓ Verified by RedCellNet"
            } else {
                "⏳ Verification Pending"
            }
            views.setTextViewText(R.id.widget_verification_badge, verifyLabel)
            views.setTextColor(
                R.id.widget_verification_badge,
                if (isVerifiedResolved)
                    Color.parseColor("#34D399")
                else
                    Color.parseColor("#FBBF24")
            )

            views.setProgressBar(
                R.id.widget_readiness_progress,
                100,
                if (isEligible) 100 else 55,
                false
            )

            views.setTextViewText(R.id.widget_eligibility_status, eligibilityText)
            views.setTextColor(
                R.id.widget_eligibility_status,
                if (isEligible) Color.parseColor("#34D399") else Color.parseColor("#FBBF24")
            )
            views.setTextViewText(R.id.widget_stats_summary, statsText)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                100,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
