package com.example.red_cell_net

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class RedCellNetEmergencyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateEmergencyWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAllEmergencyWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, RedCellNetEmergencyWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids != null && ids.isNotEmpty()) {
                for (id in ids) {
                    updateEmergencyWidget(context, manager, id)
                }
            }
        }

        fun updateEmergencyWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(
                RedCellNetWidgetProvider.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            val donorName = prefs.getString("donor_name", "RedCellNet Lifesaver") ?: "RedCellNet Lifesaver"
            val bloodType = prefs.getString("blood_type", "?") ?: "?"
            val isEligible = prefs.getBoolean("is_eligible", true)

            val views = RemoteViews(context.packageName, R.layout.redcellnet_emergency_widget)
            views.setTextViewText(
                R.id.emergency_widget_blood_chip,
                if (bloodType.isBlank()) "SOS" else bloodType
            )
            views.setTextViewText(
                R.id.emergency_widget_headline,
                "Emergency Blood SOS & Radar"
            )
            views.setTextViewText(
                R.id.emergency_widget_subtext,
                if (isEligible) "$donorName • Standby Ready for SOS" else "$donorName • Emergency Hub"
            )

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                200,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.emergency_widget_root, pendingIntent)
            views.setOnClickPendingIntent(R.id.emergency_btn_post_sos, pendingIntent)
            views.setOnClickPendingIntent(R.id.emergency_btn_live_feed, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

