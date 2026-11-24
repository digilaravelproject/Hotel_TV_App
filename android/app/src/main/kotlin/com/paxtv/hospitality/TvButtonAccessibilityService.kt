package com.paxtv.hospitality

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Path
import android.graphics.Rect
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo

class TvButtonAccessibilityService : AccessibilityService() {

    private var lastRelaunchTime: Long = 0
    private val TAG = "TvAccessibilityService"

    companion object {
        @Volatile
        var currentForegroundPackage: String? = null
        @Volatile
        var targetRenameName: String? = null
        @Volatile
        var isRenamingActive: Boolean = false
        @Volatile
        var renameLaunchTime: Long = 0L
        @Volatile
        var serviceInstance: TvButtonAccessibilityService? = null
        @Volatile
        var isWatchingLiveTv: Boolean = false
        @Volatile
        var isWaitingForLiveTvSwitch: Boolean = false
        var liveTvSwitchAttempts: Int = 0

        const val MANUAL_WINDOW_MS: Long = 0L // Zero wait - immediate auto-click
        const val WATCHDOG_TIMEOUT_MS: Long = 15_000L // 15s safety net

        fun autoRenameDevice(context: Context, name: String) {
            if (name.isBlank() || isRenamingActive) return
            targetRenameName = name
            isRenamingActive = true
            renameLaunchTime = SystemClock.elapsedRealtime()
            ExternalLaunchTracker.notifyExternalLaunch(WATCHDOG_TIMEOUT_MS)
            try {
                val intent = Intent("android.settings.DEVICE_NAME").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                context.startActivity(intent)
                Log.i("TvAccessibilityService", "🚀 [AutoRename] Launched DEVICE_NAME for target: '$name'. Screen will remain open for at least 60s for manual choice before automated fallback.")
            } catch (e: Exception) {
                Log.w("TvAccessibilityService", "Failed to launch DEVICE_NAME: ${e.message}")
                isRenamingActive = false
            }

            // Safety watchdog: reset if settings screen hangs or is closed
            Handler(Looper.getMainLooper()).postDelayed({
                if (isRenamingActive) {
                    Log.w("TvAccessibilityService", "⏱️ [AutoRename] Watchdog timeout after 85s. Resetting.")
                    isRenamingActive = false
                    serviceInstance?.bringAppToFront()
                }
            }, WATCHDOG_TIMEOUT_MS)
        }
    }

    // Common Android TV system launcher package names
    private val knownLauncherPackages = setOf(
        "com.nes.hometv.dish",
        "com.nes.hometv",
        "com.google.android.tvlauncher",
        "com.google.android.apps.tv.launcherx",
        "com.android.tv.launcher",
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.katniss",
        "com.google.android.apps.mediashell",
        "com.google.android.backdrop",
        "com.smartdevice.livetv",
        "com.amazon.tv.launcher",
        "com.cyanogenmod.trebuchet",
        "com.mstar.tv.tvplayer.ui",
        "com.mediatek.wwtv.tvcenter"
    )

    // Settings packages that must NEVER be misidentified as a Launcher
    private val ignoredSettingsPackages = setOf(
        "com.android.tv.settings",
        "com.google.android.tv.settings",
        "com.android.settings",
        "com.tcl.tv.settings",
        "com.xiaomi.mitv.settings",
        "com.sony.dtv.settings"
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInstance = this
        Log.i(TAG, "✅ TvButtonAccessibilityService connected and ready")
        targetRenameName?.let { name ->
            val cur = try { Settings.Global.getString(contentResolver, "device_name") } catch (_: Exception) { null }
            val prefs = getSharedPreferences("hotel_tv_device_prefs", Context.MODE_PRIVATE)
            val lastAttempted = prefs.getString("last_attempted_rename_target", "") ?: ""
            if (cur != name && lastAttempted != name) {
                prefs.edit().putString("last_attempted_rename_target", name).apply()
                autoRenameDevice(applicationContext, name)
            }
            targetRenameName = null
        }
    }

    override fun onDestroy() {
        serviceInstance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val pkg = event.packageName?.toString()
        if (!pkg.isNullOrBlank()) {
            currentForegroundPackage = pkg
        }

        // Auto-pilot TV device renaming when Settings is open
        if (isRenamingActive) {
            handleAutoRenameFlow()
        }

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = pkg ?: return

            // If renaming is active, give it priority
            if (isRenamingActive && packageName == "com.android.tv.settings") {
                handleAutoRenameFlow()
                return
            }

            // If the package is our own app, do nothing (or reset rename session if user manually returned)
            if (packageName == applicationContext.packageName) {
                if (isRenamingActive && (SystemClock.elapsedRealtime() - renameLaunchTime > 2500)) {
                    Log.i(TAG, "User navigated back to Hotel TV App. Deactivating rename session.")
                    isRenamingActive = false
                }
                return
            }

            // If user or app intentionally opened an external activity (Settings, Wi-Fi, Cast, HDMI), do NOT auto-relaunch
            if (ExternalLaunchTracker.isRecentlyLaunchedExternal()) {
                Log.d(TAG, "Ignoring window change ($packageName) because external activity was launched recently.")
                return
            }

            // Check if the foreground window belongs to a system Home Launcher
            if (isSystemLauncherPackage(packageName)) {
                // If guest is intentionally watching Live TV on DishTV launcher, do NOT kick them out!
                if (isWatchingLiveTv && packageName == "com.nes.hometv.dish") {
                    Log.d(TAG, "Guest is watching Live TV on DishTV. Maintaining Live TV view.")
                    return
                }

                val currentTime = SystemClock.elapsedRealtime()
                // Debounce re-launch to avoid loops (minimum 800ms between auto-relaunches)
                if (currentTime - lastRelaunchTime > 800) {
                    lastRelaunchTime = currentTime
                    Log.i(TAG, "Detected System Default Launcher ($packageName) in foreground. Relaunching Hotel TV App...")
                    bringAppToFront()
                }
            }
        }
    }

    private fun isSystemLauncherPackage(pkgName: String): Boolean {
        // Never treat settings as launcher
        if (ignoredSettingsPackages.contains(pkgName)) {
            return false
        }

        if (knownLauncherPackages.contains(pkgName)) {
            return true
        }
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
            }
            val resolveInfos = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            for (info in resolveInfos) {
                val launcherPkg = info.activityInfo.packageName
                if (launcherPkg != applicationContext.packageName && !ignoredSettingsPackages.contains(launcherPkg) && launcherPkg == pkgName) {
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking launcher package: ${e.message}")
        }
        return false
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private fun getActivePackage(): String? {
        try {
            val rootPkg = rootInActiveWindow?.packageName?.toString()
            if (!rootPkg.isNullOrBlank()) return rootPkg
        } catch (_: Exception) {}

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
            try {
                for (window in windows) {
                    if (window.isFocused || window.isActive) {
                        val p = window.root?.packageName?.toString()
                        if (!p.isNullOrBlank()) return p
                    }
                }
            } catch (_: Exception) {}
        }

        val current = currentForegroundPackage
        if (!current.isNullOrBlank()) return current

        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val running = am?.runningAppProcesses
            val top = running?.firstOrNull { it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND }
            if (top != null && !top.processName.isNullOrBlank()) {
                return top.processName
            }
        } catch (_: Exception) {}

        return null
    }

    private fun isYouTubeOrCastPackage(pkgName: String?): Boolean {
        if (pkgName.isNullOrBlank()) return false
        val pkg = pkgName.lowercase()
        return pkg.contains("youtube") ||
               pkg.contains("mediashell") ||
               pkg.contains("chromecast") ||
               pkg.contains("smarttube") ||
               pkg.contains("airscreen") ||
               pkg.contains("airplay") ||
               pkg.contains("miracast") ||
               pkg.contains("screencast") ||
               pkg.contains("wfd")
    }

    private fun closeYouTubeAndBringAppToFront(pkg: String?) {
        try {
            // 1. Dispatch media pause & stop keys so audio immediately halts
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE))
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_STOP))
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_STOP))
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping media playback: ${e.message}")
        }

        // 2. Perform system GLOBAL_ACTION_HOME so Android OS closes YouTube and takes it off the screen!
        try {
            performGlobalAction(GLOBAL_ACTION_HOME)
        } catch (e: Exception) {
            Log.w(TAG, "Error performing global action home: ${e.message}")
        }

        // 3. Immediately bring Hotel TV App to front
        bringAppToFront()

        // 4. Reset foreground tracking
        currentForegroundPackage = null

        // 5. Multi-stage delayed cleanup:
        // Once OS moves YouTube to background, kill its background processes and re-assert Hotel TV app in front
        mainHandler.postDelayed({
            try {
                val actMan = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                if (!pkg.isNullOrBlank()) {
                    actMan?.killBackgroundProcesses(pkg)
                }
                actMan?.killBackgroundProcesses("com.google.android.youtube.tv")
                actMan?.killBackgroundProcesses("com.google.android.apps.youtube.tv")
                actMan?.killBackgroundProcesses("com.google.android.apps.mediashell")
                actMan?.killBackgroundProcesses("com.google.android.youtube")
            } catch (e: Exception) {
                Log.w(TAG, "Error in delayed killBackgroundProcesses: ${e.message}")
            }
            bringAppToFront()
        }, 150)

        mainHandler.postDelayed({
            bringAppToFront()
        }, 350)
    }

    private fun bringAppToFront() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to bring MainActivity to front: ${e.message}")
        }
    }

    override fun onInterrupt() {
        // Handle interrupt
    }

    private fun isDemoMode(): Boolean {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.is_demo_mode", false)
        } catch (e: Exception) {
            false
        }
    }

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return false

        val keyCode = event.keyCode
        val activePkg = getActivePackage()

        // 0. ABSOLUTE ZERO-MS HARDWARE LOCKDOWN:
        // Drop unwanted system/launcher keys at OS kernel/input pipeline level before any service receives them.
        val isBlockedKey = when (keyCode) {
            KeyEvent.KEYCODE_SETTINGS, 176,   // Settings
            KeyEvent.KEYCODE_GUIDE, 172,      // TV Guide / Channels
            KeyEvent.KEYCODE_ALL_APPS, 284,   // All Apps Menu
            KeyEvent.KEYCODE_APP_SWITCH, 187, // Recent Apps
            KeyEvent.KEYCODE_TV_INPUT, 178,   // Source / Input
            183, 184, 185, 186,               // Colored keys (Red, Green, Yellow, Blue)
            5103, 5104, 5113, 5115, 5116, 5117, 5118, 5119, 5120, 5121, 5122, 5123, 5124, 5125, 5126, 5128, 5129, 5130, 5131 -> true
            else -> false
        }
        if (isBlockedKey) {
            Log.d(TAG, "🚫 [0ms Drop] Blocked key consumed at OS level: keyCode=$keyCode")
            return true // Immediately consume on BOTH ACTION_DOWN and ACTION_UP
        }

        // 1. BACK button handling when in YouTube or Cast receiver:
        // Guest pressed BACK -> Close YouTube/Cast and bring Hotel TV app to front!
        // Works in BOTH Try Demo Mode and Login Mode!
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (isYouTubeOrCastPackage(activePkg)) {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    Log.i(TAG, "Back pressed while in YouTube/Cast ($activePkg). Closing YouTube and returning to Hotel TV...")
                    closeYouTubeAndBringAppToFront(activePkg)
                }
                return true // Consume BACK so YouTube doesn't stay open!
            }
        }

        // 2. HOME or TV button handling:
        if (keyCode == KeyEvent.KEYCODE_HOME || keyCode == KeyEvent.KEYCODE_TV) {
            isWatchingLiveTv = false
            if (isYouTubeOrCastPackage(activePkg)) {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    Log.i(TAG, "Home pressed while in YouTube/Cast ($activePkg). Closing YouTube and returning to Hotel TV...")
                    closeYouTubeAndBringAppToFront(activePkg)
                }
                return true
            }

            // In Demo Mode when already in our app, do not swallow keys (MainActivity handles it)
            if (isDemoMode() && activePkg == applicationContext.packageName) {
                return super.onKeyEvent(event)
            }

            if (event.action == KeyEvent.ACTION_DOWN) {
                bringAppToFront()
            }
            return true // Consume both ACTION_DOWN and ACTION_UP so OS never opens default home
        }

        return super.onKeyEvent(event)
    }

    private var isRenameEditTextSubmitted = false
    private var lastAutoPilotActionTime = 0L

    private fun finishAutoRenameAfterClick() {
        mainHandler.postDelayed({
            val updated = try { Settings.Global.getString(contentResolver, "device_name") } catch (_: Exception) { null }
            Log.i(TAG, "🤖 [AutoRename] Result after auto-click: $updated")
            isRenamingActive = false
            mainHandler.postDelayed({ bringAppToFront() }, 2000)
        }, 1500)
    }

    private fun handleAutoRenameFlow() {
        val root = rootInActiveWindow ?: return
        val pkg = root.packageName?.toString() ?: ""
        if (!pkg.contains("settings", ignoreCase = true)) return

        val targetName = targetRenameName ?: return
        val now = SystemClock.elapsedRealtime()

        // 0. Check if device is ALREADY renamed
        val currentSysName = try {
            Settings.Global.getString(contentResolver, "device_name")
        } catch (_: Exception) { null }
        if (currentSysName != null && (currentSysName.trim().equals(targetName.trim(), ignoreCase = true) ||
            currentSysName.contains(targetName.trim(), ignoreCase = true))) {
            Log.i(TAG, "🎉 [AutoRename] Device already renamed to: $currentSysName. Done!")
            isRenamingActive = false
            mainHandler.postDelayed({ bringAppToFront() }, 500)
            return
        }

        // Automated fallback: debounce 400ms between automated UI actions
        if (now - lastAutoPilotActionTime < 400) return

        // Case 1: Check for EditText FIRST (Screen 3: Custom name input)
        // If EditText is present, do NOT check presets or click anything else!
        val editNode = findEditText(root)
        if (editNode != null) {
            if (!isRenameEditTextSubmitted) {
                lastAutoPilotActionTime = now
                val currentText = editNode.text?.toString() ?: ""
                if (currentText != targetName) {
                    val args = Bundle().apply {
                        putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, targetName)
                    }
                    editNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                    Log.i(TAG, "🤖 [AutoRename] Step 3: Set EditText text to '$targetName'")
                }

                isRenameEditTextSubmitted = true
                mainHandler.postDelayed({
                    submitDeviceName(editNode)
                }, 500)
            }
            return
        }

        // Case 2: Check for Direct Suggested Target Name in Actions
        val exactNodes = root.findAccessibilityNodeInfosByText(targetName)
        for (node in exactNodes) {
            if (node.className?.toString()?.contains("EditText", ignoreCase = true) == true) continue
            val text = node.text?.toString()?.trim() ?: ""
            if (text.equals(targetName, ignoreCase = true)) {
                lastAutoPilotActionTime = now
                clickNode(node)
                Log.i(TAG, "🤖 [AutoRename] Clicked exact matching name: '$text'")
                finishAutoRenameAfterClick()
                return
            }
        }

        // Case 3: Check for "Enter custom name…" / "custom" (Screen 2: When target not in presets)
        val customNodes = root.findAccessibilityNodeInfosByText("custom")
        if (customNodes.isNotEmpty()) {
            for (node in customNodes) {
                val text = node.text?.toString()?.lowercase() ?: ""
                if (text.contains("custom")) {
                    lastAutoPilotActionTime = now
                    clickNode(node)
                    Log.i(TAG, "🤖 [AutoRename] Step 2: Clicked custom name option")
                    return
                }
            }
        }

        // Case 4: Check for "Change" action (Screen 1)
        val changeNodes = root.findAccessibilityNodeInfosByText("Change")
        for (node in changeNodes) {
            val text = node.text?.toString()?.trim() ?: ""
            if (text.equals("Change", ignoreCase = true)) {
                lastAutoPilotActionTime = now
                clickNode(node)
                Log.i(TAG, "🤖 [AutoRename] Step 1: Clicked 'Change'")
                return
            }
        }

        val listNodes = mutableListOf<AccessibilityNodeInfo>()
        findNodesMatching(root, listNodes) { it.isScrollable }
        for (list in listNodes) {
            list.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)
        }
    }

    private fun submitDeviceName(editNode: AccessibilityNodeInfo) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            editNode.performAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id)
        }

        var clickedIme = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                for (window in windows) {
                    val wRoot = window.root ?: continue
                    val doneNodes = mutableListOf<AccessibilityNodeInfo>()
                    findNodesMatching(wRoot, doneNodes) { n ->
                        val desc = n.contentDescription?.toString()?.lowercase() ?: ""
                        val text = n.text?.toString()?.lowercase() ?: ""
                        val id = n.viewIdResourceName?.lowercase() ?: ""
                        if (text.contains("custom") || desc.contains("custom") || id.contains("guidedactions_item_title")) return@findNodesMatching false
                        desc.contains("done") || desc.contains("enter") || desc.contains("go") || desc.contains("ok") ||
                        text.contains("done") || text.equals("ok") || text.contains("save") ||
                        id.contains("enter") || id.contains("done") || id.contains("action_next") || id.contains("ok")
                    }
                    for (dn in doneNodes) {
                        if (clickNode(dn)) {
                            Log.i(TAG, "🤖 [AutoRename] Clicked IME action key: ${dn.contentDescription ?: dn.text}")
                            clickedIme = true
                            break
                        }
                    }
                    if (clickedIme) break
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "IME search: ${e.message}")
        }

        if (!clickedIme) {
            try {
                val activeRoot = rootInActiveWindow
                if (activeRoot != null) {
                    val submitButtons = mutableListOf<AccessibilityNodeInfo>()
                    findNodesMatching(activeRoot, submitButtons) { n ->
                        val text = n.text?.toString()?.trim() ?: ""
                        val desc = n.contentDescription?.toString()?.trim() ?: ""
                        val id = n.viewIdResourceName?.lowercase() ?: ""
                        if (text.contains("custom") || desc.contains("custom")) return@findNodesMatching false
                        text.equals("OK", ignoreCase = true) || text.equals("Done", ignoreCase = true) ||
                        text.equals("Save", ignoreCase = true) || text.equals("Next", ignoreCase = true) ||
                        desc.equals("OK", ignoreCase = true) || desc.equals("Done", ignoreCase = true) ||
                        id.contains("checkmark") || id.contains("confirm")
                    }
                    for (sb in submitButtons) {
                        if (clickNode(sb)) {
                            Log.i(TAG, "🤖 [AutoRename] Clicked Submit button: ${sb.text}")
                            clickedIme = true
                            break
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        if (!clickedIme) {
            val dm = resources.displayMetrics
            val enterX = dm.widthPixels * 0.90f
            val enterY = dm.heightPixels * 0.88f
            dispatchTap(enterX, enterY)
            Log.i(TAG, "🤖 [AutoRename] Dispatched IME tap at fallback: ($enterX, $enterY)")
        }

        mainHandler.postDelayed({
            val updated = try {
                Settings.Global.getString(contentResolver, "device_name")
            } catch (_: Exception) { null }
            Log.i(TAG, "🤖 [AutoRename] Result after submit: Settings.Global device_name = $updated")
            isRenamingActive = false
            isRenameEditTextSubmitted = false
            mainHandler.postDelayed({ bringAppToFront() }, 2000)
        }, 1500)
    }

    private fun clickNode(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        var current: AccessibilityNodeInfo? = node
        while (current != null) {
            if (current.isClickable) {
                return current.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
            current = current.parent
        }
        val rect = Rect()
        node.getBoundsInScreen(rect)
        if (!rect.isEmpty) {
            dispatchTap(rect.centerX().toFloat(), rect.centerY().toFloat())
            return true
        }
        return false
    }

    fun dispatchTap(x: Float, y: Float, onComplete: (() -> Unit)? = null) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val path = Path().apply { moveTo(x, y) }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 60))
                .build()
            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    super.onCompleted(gestureDescription)
                    onComplete?.invoke()
                }
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    super.onCancelled(gestureDescription)
                }
            }, null)
        }
    }

    fun triggerDishTvLiveSwitch() {
        isWatchingLiveTv = true
        isWaitingForLiveTvSwitch = true
        liveTvSwitchAttempts = 0
        mainHandler.removeCallbacks(liveTvSwitchRunnable)
        mainHandler.post(liveTvSwitchRunnable)
    }

    private val liveTvSwitchRunnable = object : Runnable {
        override fun run() {
            if (!isWaitingForLiveTvSwitch) return
            liveTvSwitchAttempts++

            val root = rootInActiveWindow
            val pkg = root?.packageName?.toString() ?: ""

            if (pkg == "com.nes.hometv.dish") {
                var tabClicked = false
                val liveNodes = root.findAccessibilityNodeInfosByText("Live")
                for (node in liveNodes) {
                    val rect = Rect()
                    node.getBoundsInScreen(rect)
                    // Top tab bar is in range Y: 30..250, X: 600..950
                    if (rect.top in 30..250 && rect.left in 600..950) {
                        tabClicked = true
                        clickNode(node)
                        dispatchTap(rect.centerX().toFloat(), rect.centerY().toFloat()) {
                            mainHandler.postDelayed({
                                dispatchTap(rect.centerX().toFloat(), rect.centerY().toFloat())
                            }, 150)
                        }
                        break
                    }
                }

                if (!tabClicked) {
                    // Direct coordinate tap on Live tab center (775f, 102f)
                    dispatchTap(775f, 102f) {
                        mainHandler.postDelayed({
                            dispatchTap(775f, 102f)
                        }, 150)
                    }
                }

                if (liveTvSwitchAttempts >= 4) {
                    isWaitingForLiveTvSwitch = false
                    return
                }
                mainHandler.postDelayed(this, 300)
            } else if (liveTvSwitchAttempts < 15) {
                mainHandler.postDelayed(this, 150)
            } else {
                isWaitingForLiveTvSwitch = false
            }
        }
    }

    private fun findEditText(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (root.className?.toString()?.contains("EditText", ignoreCase = true) == true || root.isEditable) {
            return root
        }
        for (i in 0 until root.childCount) {
            val child = root.getChild(i) ?: continue
            val found = findEditText(child)
            if (found != null) return found
        }
        return null
    }

    private fun findNodesMatching(root: AccessibilityNodeInfo, results: MutableList<AccessibilityNodeInfo>, predicate: (AccessibilityNodeInfo) -> Boolean) {
        if (predicate(root)) {
            results.add(root)
        }
        for (i in 0 until root.childCount) {
            val child = root.getChild(i) ?: continue
            findNodesMatching(child, results, predicate)
        }
    }
}

