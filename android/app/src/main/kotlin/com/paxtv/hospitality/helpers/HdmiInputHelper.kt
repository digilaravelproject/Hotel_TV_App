package com.paxtv.hospitality.helpers

import android.content.Context
import android.content.Intent
import android.media.tv.TvInputInfo
import android.media.tv.TvInputManager
import android.net.Uri
import android.widget.Toast
import com.paxtv.hospitality.ExternalLaunchTracker
import io.flutter.plugin.common.MethodChannel
import java.io.File

class HdmiInputHelper(private val context: Context) {

    private var tvInputCallback: TvInputManager.TvInputCallback? = null
    private var lastLaunchHdmiTime: Long = 0

    fun setupTvInputCallback(tvControlChannel: MethodChannel) {
        try {
            val tvInputManager = context.getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager ?: return
            tvInputCallback?.let {
                try { tvInputManager.unregisterCallback(it) } catch (_: Exception) {}
            }

            tvInputCallback = object : TvInputManager.TvInputCallback() {
                override fun onInputStateChanged(inputId: String, state: Int) {
                    android.util.Log.i("HotelTV", "📺 [TvInputCallback] InputStateChanged: $inputId -> state: $state")
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        try {
                            tvControlChannel.invokeMethod("onTvInputStateChanged", mapOf("inputId" to inputId, "state" to state))
                        } catch (_: Exception) {}
                    }
                }
                override fun onInputAdded(inputId: String) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        try {
                            tvControlChannel.invokeMethod("onTvInputStateChanged", mapOf("inputId" to inputId, "event" to "added"))
                        } catch (_: Exception) {}
                    }
                }
                override fun onInputRemoved(inputId: String) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        try {
                            tvControlChannel.invokeMethod("onTvInputStateChanged", mapOf("inputId" to inputId, "event" to "removed"))
                        } catch (_: Exception) {}
                    }
                }
            }
            tvInputManager.registerCallback(tvInputCallback!!, android.os.Handler(android.os.Looper.getMainLooper()))
        } catch (e: Exception) {
            android.util.Log.w("HotelTV", "⚠️ Error setting up TvInputCallback: ${e.message}")
        }
    }

    fun isHardwareHdmiInput(input: TvInputInfo): Boolean {
        val idLower = input.id.lowercase()
        if (idLower.contains("tuner") ||
            idLower.contains("composite") ||
            idLower.contains("component") ||
            idLower.contains("vga") ||
            idLower.contains("dvi") ||
            idLower.contains("google.android.videos") ||
            idLower.contains("livetv") ||
            idLower.contains("zee5") ||
            idLower.contains("play.movies") ||
            idLower.contains("netflix") ||
            idLower.contains("preview")) {
            return false
        }
        return input.type == TvInputInfo.TYPE_HDMI ||
               input.isPassthroughInput ||
               idLower.contains("hdmi")
    }

    private fun isValidDeviceName(name: String?): Boolean {
        if (name.isNullOrBlank()) return false
        val trimmed = name.trim()
        val lower = trimmed.lowercase()
        if (lower.startsWith("hdmi") || 
            lower == "tv" || 
            lower.startsWith("com.") || 
            lower.contains("hw") || 
            lower.contains("/") ||
            lower.contains("google play") ||
            lower.contains("shop")) {
            return false
        }
        return trimmed.length >= 2
    }

    fun getCecDeviceNameForInput(input: TvInputInfo, portNumber: Int): String? {
        try {
            val getHdmiDeviceInfoMethod = input.javaClass.getMethod("getHdmiDeviceInfo")
            val hdmiDeviceInfo = getHdmiDeviceInfoMethod.invoke(input)
            if (hdmiDeviceInfo != null) {
                val getDisplayNameMethod = hdmiDeviceInfo.javaClass.getMethod("getDisplayName")
                val name = getDisplayNameMethod.invoke(hdmiDeviceInfo)?.toString()?.trim()
                if (isValidDeviceName(name)) {
                    return name
                }
            }
        } catch (_: Exception) {}

        try {
            val hdmiControlManager = context.getSystemService("hdmi_control")
            if (hdmiControlManager != null) {
                val listMethods = listOf("getConnectedDevicesList", "getAllDeviceInfo", "getDeviceList")
                for (methodName in listMethods) {
                    try {
                        val method = hdmiControlManager.javaClass.getMethod(methodName)
                        val list = method.invoke(hdmiControlManager) as? List<*>
                        if (list != null) {
                            for (item in list) {
                                if (item == null) continue
                                val portId = try {
                                    item.javaClass.getMethod("getPortId").invoke(item) as? Int ?: -1
                                } catch (_: Exception) { -1 }

                                if (portId == portNumber || portNumber <= 0) {
                                    val name = try {
                                        item.javaClass.getMethod("getDisplayName").invoke(item)?.toString()?.trim()
                                    } catch (_: Exception) { null }
                                    if (isValidDeviceName(name)) {
                                        return name
                                    }
                                }
                            }
                        }
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}

        return null
    }

    fun getHdmiModels(): List<Map<String, String>> {
        val inputsList = mutableListOf<Map<String, String>>()
        try {
            val tvInputManager = context.getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager
            if (tvInputManager != null) {
                val inputList = tvInputManager.tvInputList.filter { isHardwareHdmiInput(it) }
                val sortedList = inputList.sortedBy { it.id }
                var hdmiIndex = 1

                for (input in sortedList) {
                    val id = input.id
                    val portNum = hdmiIndex
                    val portName = "HDMI $portNum"
                    hdmiIndex++

                    val inputState = try {
                        tvInputManager.getInputState(id)
                    } catch (_: Exception) {
                        TvInputManager.INPUT_STATE_DISCONNECTED
                    }

                    val cecName = getCecDeviceNameForInput(input, portNum)
                    val hasSignal = (inputState == TvInputManager.INPUT_STATE_CONNECTED) || (!cecName.isNullOrBlank())
                    val isConnected = hasSignal || (inputState == TvInputManager.INPUT_STATE_CONNECTED_STANDBY)

                    val statusString = when {
                        hasSignal -> "ACTIVE"
                        isConnected -> "STANDBY"
                        else -> "DISCONNECTED"
                    }

                    val deviceName = if (!cecName.isNullOrBlank()) {
                        cecName
                    } else if (hasSignal) {
                        "Active HDMI ($portName)"
                    } else if (isConnected) {
                        "Standby Device"
                    } else {
                        ""
                    }

                    inputsList.add(mapOf(
                        "id" to id,
                        "label" to portName,
                        "name" to deviceName,
                        "deviceName" to deviceName,
                        "portName" to portName,
                        "model" to id,
                        "value" to id,
                        "type" to "HDMI",
                        "isConnected" to isConnected.toString(),
                        "hasSignal" to hasSignal.toString(),
                        "status" to statusString,
                        "state" to inputState.toString()
                    ))
                }
            }
        } catch (e: Exception) {
            android.util.Log.w("HotelTV", "⚠️ Error getting HDMI inputs: ${e.message}")
        }
        return inputsList
    }

    fun launchHdmi(port: String): Boolean {
        ExternalLaunchTracker.notifyExternalLaunch()
        val now = System.currentTimeMillis()
        if (now - lastLaunchHdmiTime < 2000) {
            return true
        }
        lastLaunchHdmiTime = now

        return try {
            val tvInputManager = context.getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager
            val allInputs = tvInputManager?.tvInputList ?: emptyList()
            val hdmiInputs = allInputs.filter { isHardwareHdmiInput(it) }.sortedBy { it.id }
            var resolvedId: String? = null
            var displayName = port.trim()

            val exactMatch = allInputs.firstOrNull { it.id.equals(port.trim(), ignoreCase = true) }
            if (exactMatch != null) {
                resolvedId = exactMatch.id
            }

            if (resolvedId == null) {
                val hwMatch = Regex("HW([0-9]+)", RegexOption.IGNORE_CASE).find(port)
                if (hwMatch != null) {
                    val hwNum = hwMatch.groupValues[1]
                    val match = allInputs.firstOrNull { it.id.contains("HW$hwNum", ignoreCase = true) }
                    if (match != null) resolvedId = match.id
                }
            }

            if (resolvedId == null) {
                val hdmiNumMatch = Regex("HDMI\\s*([1-9])", RegexOption.IGNORE_CASE).find(port)
                val seqIndex = hdmiNumMatch?.groupValues?.get(1)?.toIntOrNull()
                if (seqIndex != null && seqIndex in 1..hdmiInputs.size) {
                    resolvedId = hdmiInputs[seqIndex - 1].id
                    displayName = "HDMI $seqIndex"
                }
            }

            if (resolvedId == null || allInputs.none { it.id == resolvedId }) {
                resolvedId = hdmiInputs.firstOrNull()?.id ?: allInputs.firstOrNull()?.id
            }

            val finalTargetId = resolvedId
            if (finalTargetId.isNullOrBlank()) {
                Toast.makeText(context, "No TV inputs available", Toast.LENGTH_SHORT).show()
                return false
            }

            Toast.makeText(context, "Opening $displayName...", Toast.LENGTH_SHORT).show()

            val targetUri: Uri = try {
                android.media.tv.TvContract.buildChannelUriForPassthroughInput(finalTargetId)
            } catch (_: Exception) {
                Uri.parse("content://android.media.tv/passthrough/${Uri.encode(finalTargetId)}")
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = targetUri
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Toast.makeText(context, "Cannot open TV input", Toast.LENGTH_SHORT).show()
            false
        }
    }
}
