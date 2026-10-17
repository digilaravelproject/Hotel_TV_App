import 'dart:convert';
import 'dart:io';
import '../../constants/app_constants.dart';
import '../../utils/logger.dart';
import '../storage/shared_prefs.dart';

class TvTimeService {
  static final Stopwatch _appStopwatch = Stopwatch()..start();

  static const String keyLastServerTimeMs = 'last_calibrated_server_time_ms';
  static const String keyServerTimeOffsetMs = 'server_time_offset_ms';
  static const String keyTargetTimezoneOffsetMin = 'hotel_timezone_offset_minutes';
  static const String keyTimezoneName = 'hotel_timezone_name';

  // Default to Indian Standard Time (IST) UTC+05:30 (330 minutes)
  static const int defaultTimezoneOffsetMinutes = 330;
  static const String defaultTimezoneName = 'Asia/Kolkata';

  /// Records server time obtained from an HTTP header or JSON response body.
  static void recordServerTime(DateTime serverTimeUtc, {int? timezoneOffsetMinutes, String? timezoneName}) {
    try {
      final int serverMs = serverTimeUtc.millisecondsSinceEpoch;
      final int localMs = DateTime.now().millisecondsSinceEpoch;
      final int offsetMs = serverMs - localMs;

      SharedPrefs.setInt(keyLastServerTimeMs, serverMs);
      SharedPrefs.setInt(keyServerTimeOffsetMs, offsetMs);

      if (timezoneOffsetMinutes != null) {
        SharedPrefs.setInt(keyTargetTimezoneOffsetMin, timezoneOffsetMinutes);
      }
      if (timezoneName != null && timezoneName.isNotEmpty) {
        SharedPrefs.setString(keyTimezoneName, timezoneName);
      }

      Logger.i('[TvTimeService] Server time recorded: $serverTimeUtc, offset: ${offsetMs}ms, tzOffset: ${timezoneOffsetMinutes ?? defaultTimezoneOffsetMinutes}m');
    } catch (e) {
      Logger.e('[TvTimeService] Error recording server time: $e');
    }
  }

  /// Parses HTTP Date header or JSON timestamp and records it.
  static void recordFromHttpHeader(String? httpDateHeader) {
    if (httpDateHeader == null || httpDateHeader.trim().isEmpty) return;
    try {
      final serverTime = HttpDate.parse(httpDateHeader.trim());
      recordServerTime(serverTime);
    } catch (_) {
      // Ignore parse failure on malformed headers
    }
  }

  /// Extracts server time and timezone from API response map if available.
  static void recordFromApiResponse(Map<String, dynamic>? dataMap) {
    if (dataMap == null) return;
    try {
      // 1. Check for server_time or timestamp
      final dynamic rawTime = dataMap['server_time'] ??
          dataMap['serverTime'] ??
          dataMap['timestamp'] ??
          (dataMap['data'] is Map ? dataMap['data']['server_time'] : null);
      if (rawTime != null) {
        DateTime? parsedTime;
        if (rawTime is int) {
          parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTime, isUtc: true);
        } else if (rawTime is String) {
          parsedTime = DateTime.tryParse(rawTime)?.toUtc();
        }
        if (parsedTime != null) {
          // 2. Check for timezone
          final dynamic tz = dataMap['timezone'] ??
              (dataMap['hotel'] is Map ? dataMap['hotel']['timezone'] : null) ??
              (dataMap['data'] is Map && dataMap['data']['hotel'] is Map ? dataMap['data']['hotel']['timezone'] : null);
          int? tzOffsetMin;
          String? tzName;
          if (tz is String) {
            tzName = tz;
            if (tz.contains('+') || tz.contains('-')) {
              final parts = tz.replaceAll('+', '').split(':');
              if (parts.isNotEmpty) {
                final h = int.tryParse(parts[0]) ?? 5;
                final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 30) : 0;
                tzOffsetMin = (h * 60 + m) * (tz.startsWith('-') ? -1 : 1);
              }
            } else if (tz.toLowerCase().contains('kolkata') || tz.toLowerCase().contains('calcutta')) {
              tzOffsetMin = 330;
            }
          }
          recordServerTime(parsedTime, timezoneOffsetMinutes: tzOffsetMin, timezoneName: tzName);
        }
      }
    } catch (e) {
      Logger.e('[TvTimeService] Error parsing time from response: $e');
    }
  }

  /// Initializes time service state from local storage on app startup
  static void initFromStorage() {
    try {
      final rawLogin = SharedPrefs.getString(AppConstants.tvLoginDataKey);
      if (rawLogin != null && rawLogin.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(rawLogin);
        recordFromApiResponse(data);

        // Fallback: Check hotel active plan purchase_date or demo_expires_at
        if (SharedPrefs.getInt(keyLastServerTimeMs) == null) {
          final hotelMap = data['hotel'] ?? (data['data'] is Map ? data['data']['hotel'] : null);
          final activePlan = hotelMap is Map ? hotelMap['active_plan'] : null;
          final purchaseDateStr = activePlan is Map ? activePlan['purchase_date']?.toString() : null;
          if (purchaseDateStr != null) {
            final dt = DateTime.tryParse(purchaseDateStr);
            if (dt != null) {
              SharedPrefs.setInt(keyLastServerTimeMs, dt.toUtc().millisecondsSinceEpoch);
            }
          }
        }
      }
    } catch (e) {
      Logger.w('[TvTimeService] initFromStorage warning: $e');
    }
  }

  /// Returns the target hotel timezone offset in minutes (defaults to +330 for IST).
  static int getTargetTimezoneOffsetMinutes() {
    return SharedPrefs.getInt(keyTargetTimezoneOffsetMin) ?? defaultTimezoneOffsetMinutes;
  }

  /// Returns current calculated, drift-compensated wall-clock time for the hotel.
  static DateTime getCalibratedNow() {
    final now = DateTime.now();
    final int? lastServerMs = SharedPrefs.getInt(keyLastServerTimeMs);
    final int offsetMs = SharedPrefs.getInt(keyServerTimeOffsetMs) ?? 0;
    final int targetTzMin = getTargetTimezoneOffsetMinutes();

    int effectiveUtcMs;

    // Detect if device clock has reset (e.g. Year < 2025 or time jumped before last known server time)
    if (now.year < 2025 || (lastServerMs != null && now.millisecondsSinceEpoch < (lastServerMs - 60000))) {
      // Device RTC has reset! Use last known server time + monotonic app running time
      final base = lastServerMs ?? DateTime(2026, 10, 14, 12, 0).millisecondsSinceEpoch;
      effectiveUtcMs = base + _appStopwatch.elapsedMilliseconds;
    } else {
      // Device clock is ticking normally: apply recorded network offset
      effectiveUtcMs = now.toUtc().millisecondsSinceEpoch + offsetMs;
    }

    // Convert to hotel timezone (targetTzMin)
    return DateTime.fromMillisecondsSinceEpoch(
      effectiveUtcMs + (targetTzMin * 60 * 1000),
      isUtc: true,
    );
  }

  /// Generates self-contained JavaScript snippet to patch WebView clock & greeting
  static String generateJsClockSyncPatch() {
    final int offsetMs = SharedPrefs.getInt(keyServerTimeOffsetMs) ?? 0;
    final int? lastServerMs = SharedPrefs.getInt(keyLastServerTimeMs);
    final int targetTzMin = getTargetTimezoneOffsetMinutes();
    final int currentElapsed = _appStopwatch.elapsedMilliseconds;
    final int nowYear = DateTime.now().year;
    final bool isClockReset = nowYear < 2025 || (lastServerMs != null && DateTime.now().millisecondsSinceEpoch < lastServerMs);

    return '''
      (function() {
        try {
          window.__tvClockConfig = {
            offsetMs: $offsetMs,
            targetTzMin: $targetTzMin,
            lastServerMs: ${lastServerMs ?? 'null'},
            clientElapsedMs: $currentElapsed,
            isClockReset: $isClockReset,
            initLocalMs: Date.now()
          };

          window.__getCalibratedDate = function() {
            var cfg = window.__tvClockConfig || {};
            var localNow = Date.now();
            var targetMs;

            if (cfg.isClockReset && cfg.lastServerMs) {
              var timeSinceInit = localNow - cfg.initLocalMs;
              targetMs = cfg.lastServerMs + cfg.clientElapsedMs + timeSinceInit;
            } else {
              targetMs = localNow + (cfg.offsetMs || 0);
            }

            // Adjust for device timezone vs hotel target timezone
            var deviceOffsetMin = -new Date().getTimezoneOffset();
            var targetOffsetMin = (cfg.targetTzMin !== undefined) ? cfg.targetTzMin : 330;
            var diffMs = (targetOffsetMin - deviceOffsetMin) * 60 * 1000;

            return new Date(targetMs + diffMs);
          };

          // Patch Alpine.js home page clock & greeting immediately
          var patchAlpineClock = function() {
            document.querySelectorAll('[x-data]').forEach(function(el) {
              var stack = el._x_dataStack;
              if (!stack) return;
              for (var i = 0; i < stack.length; i++) {
                var obj = stack[i];
                if (!obj) continue;

                // 1. Override updateClock
                if (typeof obj.updateClock === 'function' && !obj._clockPatched) {
                  obj._clockPatched = true;
                  obj.updateClock = function() {
                    try {
                      var now = window.__getCalibratedDate();
                      var hours = now.getHours();
                      var minutes = String(now.getMinutes()).padStart(2, "0");
                      var ampm = hours >= 12 ? "PM" : "AM";
                      hours = hours % 12 || 12;
                      this.timeStr = String(hours).padStart(2, "0") + ":" + minutes + " " + ampm;

                      var dayKeys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
                      var monthKeys = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
                      var defaultDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                      var defaultMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                      var dKey = dayKeys[now.getDay()];
                      var mKey = monthKeys[now.getMonth()];
                      var dayStr = (typeof this.t === 'function')
                        ? this.t("days_short." + dKey, this.t("days." + dKey, defaultDays[now.getDay()]))
                        : defaultDays[now.getDay()];
                      var monthStr = (typeof this.t === 'function')
                        ? this.t("months." + mKey, defaultMonths[now.getMonth()])
                        : defaultMonths[now.getMonth()];
                      this.dateStr = dayStr + ", " + monthStr + " " + now.getDate();
                    } catch(e) {
                      console.warn("[TVClockPatch] error in updateClock:", e);
                    }
                  };
                  obj.updateClock();
                }

                // 2. Override updateGreeting
                if (typeof obj.updateGreeting === 'function' && !obj._greetingPatched) {
                  obj._greetingPatched = true;
                  obj.updateGreeting = function() {
                    try {
                      var now = window.__getCalibratedDate();
                      var h = now.getHours();
                      var timeKey = h >= 4 && h < 12 ? "morning" : h >= 12 && h < 17 ? "afternoon" : h >= 17 && h < 22 ? "evening" : "night";
                      var defaultGreeting = h >= 4 && h < 12 ? "Good Morning" : h >= 12 && h < 17 ? "Good Afternoon" : h >= 17 && h < 22 ? "Good Evening" : "Good Night";
                      var timeGreeting = (typeof this.t === 'function') ? this.t("greetings." + timeKey, defaultGreeting) : defaultGreeting;
                      var guestName = "Guest";
                      if (this.hotelData && this.hotelData.guest_info) {
                        guestName = typeof this.hotelData.guest_info === "string" 
                          ? this.hotelData.guest_info.trim() 
                          : (this.hotelData.guest_info.name || this.hotelData.guest_info.guest_name || "Guest");
                      }
                      this.greetingStr = timeGreeting + ", " + guestName;
                    } catch(e) {}
                  };
                  obj.updateGreeting();
                }
              }
            });
          };

          patchAlpineClock();
          document.addEventListener('alpine:initialized', patchAlpineClock);
          setInterval(patchAlpineClock, 500);
        } catch(e) {
          console.error('[TVClockPatch] Initialization error:', e);
        }
      })();
    ''';
  }
}
