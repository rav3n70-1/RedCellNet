package com.example.red_cell_net

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

class RedCellNetCompactWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateCompactWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAllCompactWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, RedCellNetCompactWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids != null && ids.isNotEmpty()) {
                for (id in ids) {
                    updateCompactWidget(context, manager, id)
                }
            }
        }

        fun updateCompactWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(
                RedCellNetWidgetProvider.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            val bloodType = prefs.getString("blood_type", "?") ?: "?"
            val isEligible = prefs.getBoolean("is_eligible", true)
            val isVerified = prefs.getBoolean("is_verified", false)
            val verificationStatus = prefs.getString("verification_status", "pending") ?: "pending"

            val views = RemoteViews(context.packageName, R.layout.redcellnet_compact_widget)
            views.setTextViewText(
                R.id.compact_widget_blood_type,
                if (bloodType.isBlank()) "?" else bloodType
            )
            views.setTextViewText(
                R.id.compact_widget_status,
                if (isEligible) "● READY" else "⏳ COOLDOWN"
            )
            views.setTextColor(
                R.id.compact_widget_status,
                if (isEligible) Color.parseColor("#34D399") else Color.parseColor("#FBBF24")
            )

            val verifiedResolved = isVerified || verificationStatus.lowercase().contains("verified")
            views.setTextViewText(
                R.id.compact_widget_verified,
                if (verifiedResolved) "✓ Verified" else "Pending"
            )
            views.setTextColor(
                R.id.compact_widget_verified,
                if (verifiedResolved) Color.parseColor("#34D399") else Color.parseColor("#FBBF24")
            )

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                300,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.compact_widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

