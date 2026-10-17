import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/api_constents.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/widget/tv_focusable.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/widget/custom_base_widget.dart';
import '../../../../core/widget/loading_widget.dart';
import '../../../../core/utils/ui_spacer.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../../../core/services/device/device_info_service.dart';
import '../../../../core/services/network/api_client.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/services/storage/token_manger.dart';
import '../../../../core/services/template/template_manager_service.dart';
import 'app_startup_decider.dart';
import '../widgets/qr_mode_widget.dart';
import '../widgets/manual_mode_widget.dart';
import '../widgets/demo_preview_widget.dart';
import '../../../../res/assets_res.dart';
import '../../../../core/widget/tv_network_status_header.dart';

enum TvLoginTab { qr, manual, demo }

class TvLoginScreen extends StatefulWidget {
  final String? expiredNotice;
  const TvLoginScreen({Key? key, this.expiredNotice}) : super(key: key);

  @override
  State<TvLoginScreen> createState() => _TvLoginScreenState();
}

class _TvLoginScreenState extends State<TvLoginScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController licenseKeyController;
  late final TextEditingController roomNoController;
  bool _isLoading = false;
  bool _isDemoLoading = false;

  late final FocusNode qrTabFocus;
  late final FocusNode manualTabFocus;
  late final FocusNode demoTabFocus;
  late final FocusNode licenseKeyFocus;
  late final FocusNode roomNoFocus;
  late final FocusNode submitFocus;

  // ValueNotifier to track active login tab (QR, Manual, Demo)
  late final ValueNotifier<TvLoginTab> selectedTabNotifier;

  // Pairing state variables
  String _pairCode = '';
  int _remainingSeconds = 180;
  bool _isPairCodeLoading = false;
  String? _pairCodeError;
  Timer? _countdownTimer;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _pairCode = '${100000 + Random().nextInt(900000)}';
    licenseKeyController = TextEditingController();
    roomNoController = TextEditingController();
    qrTabFocus = FocusNode();
    manualTabFocus = FocusNode();
    demoTabFocus = FocusNode();
    licenseKeyFocus = FocusNode();
    roomNoFocus = FocusNode();
    submitFocus = FocusNode();
    selectedTabNotifier = ValueNotifier<TvLoginTab>(TvLoginTab.qr);

    demoTabFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          manualTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // D-Pad navigation: attach onKeyEvent directly to focus nodes
    // Using new API (onKeyEvent + KeyDownEvent) instead of deprecated onKey + RawKeyDownEvent
    licenseKeyFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          roomNoFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          licenseKeyFocus.unfocus();
          manualTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    roomNoFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          licenseKeyFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          submitFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          roomNoFocus.unfocus();
          manualTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    submitFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          roomNoFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          manualTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.expiredNotice != null && widget.expiredNotice!.isNotEmpty) {
        CustomSnackbar.showError(message: widget.expiredNotice!);
      }
      _checkEmmConfig();
      _generatePairCode();
    });
  }

  Future<void> _generatePairCode() async {
    _stopPairingTimers();
    if (!mounted) return;

    // Check if already logged in
    final token = await TokenManager.getToken();
    final hasLoginData = SharedPrefs.containsKey(AppConstants.tvLoginDataKey);
    if (token.isNotEmpty && hasLoginData) {
      Logger.i('[Pairing] Already logged in. Aborting pair code generation and polling.');
      return;
    }
    setState(() {
      _isPairCodeLoading = true;
      _pairCodeError = null;
    });

    try {
      final info = await DeviceInfoService.getFullDeviceInfo(forceRefresh: true);
      final Map<String, dynamic> requestData = {
        'deviceId': info['deviceId'] ?? '',
        'macAddress': info['macAddress'] ?? '',
        'ipAddress': info['ipAddress'] ?? '',
        'model': info['model'] ?? '',
        'brand': info['brand'] ?? '',
        'osVersion': info['osVersion'] ?? '',
      };

      final ApiClient apiClient = ApiClient();
      final response = await apiClient.post(
        ApiConstants.generatePairCodeUri,
        data: requestData,
      );

      if (response.data != null && response.data is Map && response.data['status'] == true) {
        final data = response.data['data'] as Map<String, dynamic>?;
        final code = data?['pair_code']?.toString() ?? '';
        final expiresIn = (data?['expires_in_seconds'] as num?)?.toInt() ?? 180;

        if (mounted) {
          setState(() {
            _pairCode = code;
            _remainingSeconds = expiresIn;
            _isPairCodeLoading = false;
          });
          _startCountdownTimer();
          _startPolling();
        }
      } else {
        String msg = 'Failed to generate pairing code';
        if (response.data is Map && response.data['message'] != null) {
          msg = response.data['message'].toString();
        }
        Logger.w('[Pairing] API pairing failed: $msg. Using fallback code.');
        final fallbackCode = '${100000 + Random().nextInt(900000)}';
        if (mounted) {
          setState(() {
            _pairCode = fallbackCode;
            _remainingSeconds = 180;
            _isPairCodeLoading = false;
            _pairCodeError = null;
          });
          _startCountdownTimer();
          _startPolling();
        }
      }
    } catch (e) {
      Logger.e('Error generating pair code: $e');
      final fallbackCode = '${100000 + Random().nextInt(900000)}';
      if (mounted) {
        setState(() {
          _pairCode = fallbackCode;
          _remainingSeconds = 180;
          _isPairCodeLoading = false;
          _pairCodeError = null;
        });
        _startCountdownTimer();
        _startPolling();
      }
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      } else {
        _stopPairingTimers();
        if (mounted) {
          setState(() {
            _remainingSeconds = 0;
          });
          _generatePairCode();
        }
      }
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkPairStatus();
    });
  }

  Future<void> _checkPairStatus() async {
    if (_pairCode.isEmpty) return;

    try {
      final info = await DeviceInfoService.getFullDeviceInfo(forceRefresh: true);
      final Map<String, dynamic> requestData = {
        'pair_code': _pairCode,
        'deviceId': info['deviceId'] ?? '',
      };

      final ApiClient apiClient = ApiClient();
      final response = await apiClient.post(
        ApiConstants.pairStatusUri,
        data: requestData,
      );

      if (response.data != null && response.data is Map) {
        final state = response.data['state']?.toString();
        final status = response.data['status'];

        if (state == 'expired' || status == false && state != 'pending') {
          _stopPairingTimers();
          _generatePairCode();
        } else if (state == 'paired' || (status == true && response.data['data'] != null && response.data['data']['auth'] != null)) {
          _stopPairingTimers();
          await _handleLoginSuccess(response.data);
        }
      }
    } catch (e) {
      Logger.e('Error checking pair status: $e');
    }
  }

  Future<void> _handleLoginSuccess(dynamic responseData) async {
    if (!mounted) return;
    try {
      final dataMap = responseData['data'] as Map<String, dynamic>?;
      final token = dataMap?['auth']?['token']?.toString() ??
          dataMap?['token']?.toString() ??
          responseData['token']?.toString() ??
          '';

      if (token.isNotEmpty) {
        await TokenManager.saveToken(token);
      }
      // Reset demo mode on successful paid login
      await SharedPrefs.setBool(AppConstants.isDemoModeKey, false);
      await SharedPrefs.remove(AppConstants.demoExpiresAtKey);
      await SharedPrefs.remove(AppConstants.demoDaysLeftKey);
      await SharedPrefs.remove('accessibility_skipped');
      await SharedPrefs.remove('launcher_skipped');

      await SharedPrefs.setString(AppConstants.tvLoginDataKey, jsonEncode(responseData));
      await TemplateManagerService.regenerateDataJson();

      // CustomSnackbar.showSuccess(
      //   message: responseData['message'] ?? 'TV Paired and logged in successfully!',
      // );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppStartupDecider()),
        );
      }
    } catch (e) {
      Logger.e('Error handling login success: $e');
    }
  }

  Future<void> _performDemoLogin() async {
    if (_isDemoLoading) return;
    Logger.i('[Demo] Initiating demo registration & login...');
    setState(() {
      _isDemoLoading = true;
    });

    try {
      final info = await DeviceInfoService.getFullDeviceInfo(forceRefresh: true);
      final Map<String, dynamic> requestData = {
        'deviceId': info['deviceId'] ?? '',
        'macAddress': info['macAddress'] ?? '',
        'room_no': 'DEMO-001',
        'model': info['model'] ?? '',
        'brand': info['brand'] ?? '',
        'osVersion': info['osVersion'] ?? '',
        'ipAddress': info['ipAddress'] ?? '',
        'distributor_code': '',
      };

      final ApiClient apiClient = ApiClient();
      final response = await apiClient.post(
        ApiConstants.demoLoginUri,
        data: requestData,
      );

      setState(() {
        _isDemoLoading = false;
      });

      if (response.data != null && response.data is Map && response.data['status'] == true) {
        _stopPairingTimers();
        final dataMap = response.data['data'] as Map<String, dynamic>?;
        final authMap = dataMap?['auth'] as Map<String, dynamic>?;
        final token = authMap?['token']?.toString() ??
            dataMap?['token']?.toString() ??
            response.data['token']?.toString() ??
            '';

        if (token.isNotEmpty) {
          await TokenManager.saveToken(token);
        }

        final demoExpiresAt = authMap?['demo_expires_at']?.toString() ?? '';
        final demoDaysLeft = (authMap?['demo_days_left'] as num?)?.toInt() ?? 0;

        await SharedPrefs.setBool(AppConstants.isDemoModeKey, true);
        await SharedPrefs.setString(AppConstants.demoExpiresAtKey, demoExpiresAt);
        await SharedPrefs.setInt(AppConstants.demoDaysLeftKey, demoDaysLeft);

        await SharedPrefs.setString(AppConstants.tvLoginDataKey, jsonEncode(response.data));
        await TemplateManagerService.regenerateDataJson();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AppStartupDecider()),
          );
        }
      } else {
        String msg = 'Failed to activate demo mode';
        if (response.data is Map) {
          msg = response.data['message']?.toString() ?? response.data['msg']?.toString() ?? msg;
        }
        CustomSnackbar.showError(message: msg);

        // If demo expired, automatically shift focus to manual license input
        if (response.statusCode == 403 ||
            (response.data is Map && response.data['error_code'] == 'DEMO_EXPIRED')) {
          selectedTabNotifier.value = TvLoginTab.manual;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) licenseKeyFocus.requestFocus();
          });
        }
      }
    } catch (e) {
      setState(() {
        _isDemoLoading = false;
      });

      String errorMsg = 'Failed to activate demo mode';
      bool isExpired = false;
      if (e is DioException) {
        final res = e.response;
        if (res != null && res.data != null) {
          final data = res.data;
          if (data is Map) {
            errorMsg = (data['message'] ?? data['msg'] ?? errorMsg).toString();
            if (data['error_code'] == 'DEMO_EXPIRED') {
              isExpired = true;
            }
          }
        }
        if (res?.statusCode == 403) {
          isExpired = true;
        }
      }
      CustomSnackbar.showError(message: errorMsg);

      if (isExpired) {
        selectedTabNotifier.value = TvLoginTab.manual;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) licenseKeyFocus.requestFocus();
        });
      }
    }
  }

  void _stopPairingTimers() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
  }

  Future<void> _checkEmmConfig() async {
    try {
      final platform = MethodChannel('com.paxtv.hospitality/emm_config');
      final Map<dynamic, dynamic>? config = await platform.invokeMethod<Map>('getEmmConfig');
      if (config != null) {
        final String licenseKey = config['license_key']?.toString() ?? '';
        final String roomNo = config['room_no']?.toString() ?? '';
        if (licenseKey.isNotEmpty && roomNo.isNotEmpty) {
          Logger.i('[EMM] Found config. Performing automatic registration...');
          if (mounted) {
            _performRegistration(context, licenseKey, roomNo);
          }
        }
      }
    } catch (e) {
      Logger.e('[EMM] Error fetching EMM config: $e');
    }
  }

  @override
  void dispose() {
    _stopPairingTimers();
    licenseKeyController.dispose();
    roomNoController.dispose();
    qrTabFocus.dispose();
    manualTabFocus.dispose();
    demoTabFocus.dispose();
    licenseKeyFocus.dispose();
    roomNoFocus.dispose();
    submitFocus.dispose();
    selectedTabNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomBaseWidget(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF150A21),
              Color(0xFF09040E),
              Color(0xFF1B0715),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Ambient glow top right
            Positioned(
              top: -50,
              right: -80,
              child: Container(
                width: 550,
                height: 550,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE11D48).withOpacity(0.35),
                      const Color(0xFF9333EA).withOpacity(0.20),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: 50,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC084FC).withOpacity(0.25),
                      const Color(0xFFE11D48).withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4F46E5).withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 24,
              right: 32,
              child: const TvNetworkStatusHeader(),
            ),

            // Main layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ─── LEFT PANEL ───────────────────────────────────────
                Expanded(
                  flex: 9,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(64, 28, 32, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Branding
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              clipBehavior: Clip.antiAlias,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                            UiSpacer.hSpace(12),
                            CustomAppText(
                              AppConstants.appName,
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ],
                        ),
                        UiSpacer.vSpace(24),

                        // Title
                        const CustomAppText(
                          "Pair Your TV",
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        UiSpacer.vSpace(10),

                        // Subtitle
                        CustomAppText(
                          "Scan the QR code with your phone/admin dashboard or sign in manually using your remote.",
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        UiSpacer.vSpace(24),

                        // ── Option buttons ───────────────────────────────
                        ValueListenableBuilder<TvLoginTab>(
                          valueListenable: selectedTabNotifier,
                          builder: (context, selectedTab, child) {
                            final isQr = selectedTab == TvLoginTab.qr;
                            final isManual = selectedTab == TvLoginTab.manual;
                            final isDemo = selectedTab == TvLoginTab.demo;

                            return Column(
                              children: [
                                // Option 1: Pair with QR Code
                                Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent) {
                                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                        manualTabFocus.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TvFocusable(
                                    focusNode: qrTabFocus,
                                    autofocus: true,
                                    onFocusChange: (focused) {
                                      if (focused) selectedTabNotifier.value = TvLoginTab.qr;
                                    },
                                    onTap: () => selectedTabNotifier.value = TvLoginTab.qr,
                                    child: Container(
                                      height: 52,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: isQr
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: isQr
                                            ? [
                                                BoxShadow(
                                                  color: Colors.white.withOpacity(0.2),
                                                  blurRadius: 16,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.qr_code_scanner_rounded,
                                            color: isQr ? Colors.black : Colors.white70,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 16),
                                          CustomAppText(
                                            "Pair with QR Code",
                                            color: isQr ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                UiSpacer.vSpace(12),

                                // Option 2: Sign in with Remote
                                Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent) {
                                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                        qrTabFocus.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                        demoTabFocus.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                        selectedTabNotifier.value = TvLoginTab.manual;
                                        // Delay so AnimatedSwitcher can mount the widget
                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          licenseKeyFocus.requestFocus();
                                        });
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TvFocusable(
                                    focusNode: manualTabFocus,
                                    onFocusChange: (focused) {
                                      if (focused) selectedTabNotifier.value = TvLoginTab.manual;
                                    },
                                    onTap: () => selectedTabNotifier.value = TvLoginTab.manual,
                                    child: Container(
                                      height: 52,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: isManual
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: isManual
                                            ? [
                                                BoxShadow(
                                                  color: Colors.white.withOpacity(0.2),
                                                  blurRadius: 16,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.keyboard_alt_outlined,
                                            color: isManual ? Colors.black : Colors.white70,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 16),
                                          CustomAppText(
                                            "Sign in with Remote",
                                            color: isManual ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                UiSpacer.vSpace(12),

                                // Option 3: Try Free Demo
                                Focus(
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent) {
                                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                        manualTabFocus.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: TvFocusable(
                                    focusNode: demoTabFocus,
                                    onFocusChange: (focused) {
                                      if (focused) selectedTabNotifier.value = TvLoginTab.demo;
                                    },
                                    onTap: () {
                                      selectedTabNotifier.value = TvLoginTab.demo;
                                      if (!_isDemoLoading) {
                                        _performDemoLogin();
                                      }
                                    },
                                    child: Container(
                                      height: 52,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: isDemo
                                            ? Colors.amber.shade400
                                            : Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(14),
                                        border: isDemo
                                            ? null
                                            : Border.all(
                                                color: Colors.amber.shade600.withOpacity(0.4),
                                                width: 1.2,
                                              ),
                                        boxShadow: isDemo
                                            ? [
                                                BoxShadow(
                                                  color: Colors.amber.withOpacity(0.35),
                                                  blurRadius: 16,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          _isDemoLoading
                                              ? SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      isDemo ? Colors.black : Colors.amber,
                                                    ),
                                                  ),
                                                )
                                              : SvgPicture.asset(
                                                  AppAssets.demoIcon,
                                                  width: 22,
                                                  height: 22,
                                                  colorFilter: isDemo
                                                      ? const ColorFilter.mode(Colors.black, BlendMode.srcIn)
                                                      : null,
                                                ),
                                          const SizedBox(width: 16),
                                          CustomAppText(
                                            _isDemoLoading ? "Activating Demo..." : "Try Free Demo",
                                            color: isDemo ? Colors.black : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        UiSpacer.vSpace(32),

                        // Device ID Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CustomAppText(
                                "Device ID: ",
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                              FutureBuilder<String>(
                                future: DeviceInfoService.getDeviceId(),
                                builder: (context, snapshot) {
                                  return CustomAppText(
                                    snapshot.data ?? '...',
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── RIGHT PANEL ──────────────────────────────────────
                Expanded(
                  flex: 11,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(16, 32, 64, 32),
                    child: ValueListenableBuilder<TvLoginTab>(
                      valueListenable: selectedTabNotifier,
                      builder: (context, selectedTab, child) {
                        Widget content;
                        switch (selectedTab) {
                          case TvLoginTab.qr:
                            content = QrModeWidget(
                              pairCode: _pairCode,
                              remainingSeconds: _remainingSeconds,
                              isLoading: _isPairCodeLoading,
                              errorMessage: _pairCodeError,
                              onRefresh: _generatePairCode,
                            );
                            break;
                          case TvLoginTab.manual:
                            content = ManualModeWidget(
                              formKey: formKey,
                              licenseKeyController: licenseKeyController,
                              roomNoController: roomNoController,
                              licenseKeyFocus: licenseKeyFocus,
                              roomNoFocus: roomNoFocus,
                              submitFocus: submitFocus,
                              manualTabFocus: manualTabFocus,
                              onSaveAndStart: () {
                                if (formKey.currentState!.validate()) {
                                  _performRegistration(
                                    context,
                                    licenseKeyController.text,
                                    roomNoController.text,
                                  );
                                }
                              },
                            );
                            break;
                          case TvLoginTab.demo:
                            content = const DemoPreviewWidget();
                            break;
                        }

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: content,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),



            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                  child: const LoadingWidget(
                    type: LoadingType.tvScreen,
                    title: AppText.registeringTitle,
                    subtitle: AppText.registeringServerProgress,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _performRegistration(BuildContext context, String licenseKey, String roomNo) async {
    Logger.i('Registration triggered for License: $licenseKey, Room: $roomNo');

    setState(() {
      _isLoading = true;
    });

    try {
      final info = await DeviceInfoService.getFullDeviceInfo(forceRefresh: true);
      final Map<String, dynamic> requestData = {
        'license_key': licenseKey,
        'room_no': roomNo,
        'deviceId': info['deviceId'] ?? '',
        'macAddress': info['macAddress'] ?? '',
        'ipAddress': info['ipAddress'] ?? '',
        'model': info['model'] ?? '',
        'brand': info['brand'] ?? '',
        'osVersion': info['osVersion'] ?? '',
      };

      final ApiClient apiClient = ApiClient();
      final response = await apiClient.post(
        ApiConstants.loginUri,
        data: requestData,
      );

      setState(() {
        _isLoading = false;
      });

      if (response.data != null && response.data is Map && response.data['status'] == true) {
        _stopPairingTimers();
        await _handleLoginSuccess(response.data);
      } else {
        String msg = 'Failed to register TV';
        if (response.data != null) {
          if (response.data is Map) {
            msg = response.data['message'] ?? response.data['msg'] ?? msg;
          } else {
            msg = response.data.toString();
          }
        }
        CustomSnackbar.showError(message: msg);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMsg = 'Failed to register TV';
      if (e is DioException) {
        final response = e.response;
        if (response != null && response.data != null) {
          final data = response.data;
          if (data is Map) {
            errorMsg = (data['message'] ?? data['msg'] ?? errorMsg).toString();
          } else {
            errorMsg = data.toString();
          }
        } else if (e.message != null) {
          errorMsg = e.message!;
        }
      }
      CustomSnackbar.showError(message: '$errorMsg ($e)');
    }
  }
}

class LiveDateTimeWidget extends StatefulWidget {
  const LiveDateTimeWidget({Key? key}) : super(key: key);

  @override
  State<LiveDateTimeWidget> createState() => _LiveDateTimeWidgetState();
}

class _LiveDateTimeWidgetState extends State<LiveDateTimeWidget> {
  late DateTime _dateTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _dateTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _dateTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getFormattedDate() {
    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = weekDays[_dateTime.weekday - 1];
    final monthName = months[_dateTime.month - 1];
    return '$dayName, ${_dateTime.day} $monthName';
  }

  String _getFormattedTime() {
    int hour = _dateTime.hour;
    final minute = _dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomAppText(
          _getFormattedTime(),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        const SizedBox(height: 2),
        CustomAppText(
          _getFormattedDate(),
          fontSize: 9,
          fontWeight: FontWeight.w400,
          color: Colors.white70,
        ),
      ],
    );
  }
}
