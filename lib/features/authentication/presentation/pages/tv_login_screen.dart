import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/api_constents.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/widget/custom_app_text.dart';
import '../../../../core/widget/custom_base_widget.dart';
import '../../../../core/widget/loading_widget.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../../../core/services/device/device_info_service.dart';
import '../../../../core/services/network/api_client.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/services/storage/token_manger.dart';
import '../../../../core/services/template/template_manager_service.dart';
import 'app_startup_decider.dart';
import 'tv_register_screen.dart';
import '../widgets/qr_mode_widget.dart';
import '../widgets/manual_mode_widget.dart';
import '../widgets/demo_preview_widget.dart';
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
  late final FocusNode signUpFocus;
  late final FocusNode licenseKeyFocus;
  late final FocusNode roomNoFocus;
  late final FocusNode submitFocus;
  late final FocusNode demoActionFocus;

  // ValueNotifier to track active login tab (QR, Manual, Demo)
  late final ValueNotifier<TvLoginTab> selectedTabNotifier;

  // Pairing state variables
  String _pairCode = '';
  int _remainingSeconds = 180;
  bool _isPairCodeLoading = false;
  String? _pairCodeError;
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  bool _isPairingSuccess = false;

  @override
  void initState() {
    super.initState();
    _pairCode = '${100000 + Random().nextInt(900000)}';
    licenseKeyController = TextEditingController();
    roomNoController = TextEditingController();

    qrTabFocus = FocusNode();
    manualTabFocus = FocusNode();
    demoTabFocus = FocusNode();
    signUpFocus = FocusNode();
    licenseKeyFocus = FocusNode();
    roomNoFocus = FocusNode();
    submitFocus = FocusNode();
    demoActionFocus = FocusNode();

    selectedTabNotifier = ValueNotifier<TvLoginTab>(TvLoginTab.qr);

    // ── D-PAD NAVIGATION FOR TOP TABS ──────────────────────────────────
    // Tab 1: Use Phone (QR Mode)
    qrTabFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          manualTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          signUpFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // Tab 2: Use Remote (Manual Mode)
    manualTabFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          qrTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          demoTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          selectedTabNotifier.value = TvLoginTab.manual;
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) licenseKeyFocus.requestFocus();
          });
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // Tab 3: Try Free Demo (Demo Mode)
    demoTabFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          manualTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          selectedTabNotifier.value = TvLoginTab.demo;
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) demoActionFocus.requestFocus();
          });
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // Sign up button in QR mode
    signUpFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          qrTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          manualTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // ── D-PAD NAVIGATION FOR MANUAL FORM ──────────────────────────────
    licenseKeyFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          manualTabFocus.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          roomNoFocus.requestFocus();
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
      }
      return KeyEventResult.ignored;
    };

    submitFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          roomNoFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // ── D-PAD NAVIGATION FOR DEMO ACTION ──────────────────────────────
    demoActionFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          demoTabFocus.requestFocus();
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
    _isPairingSuccess = false;
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
      if (_pairCode.isEmpty || _remainingSeconds <= 0 || _isPairingSuccess) return;

      try {
        final ApiClient apiClient = ApiClient();
        final response = await apiClient.post(
          ApiConstants.pairStatusUri,
          data: {'pair_code': _pairCode},
        );

        if (response.data != null && response.data is Map) {
          final respMap = response.data as Map<String, dynamic>;
          final state = respMap['state']?.toString().toLowerCase();
          final status = respMap['status'];

          if (state == 'expired' || (status == false && state != 'pending')) {
            _stopPairingTimers();
            _generatePairCode();
          } else if (state == 'paired' ||
              (status == true &&
                  respMap['data'] != null &&
                  (respMap['data']['auth'] != null || respMap['data']['paired'] == true))) {
            _isPairingSuccess = true;
            _stopPairingTimers();
            Logger.i('[Pairing] Device successfully paired via phone!');
            final data = respMap['data'] as Map<String, dynamic>?;
            await _handleLoginSuccess(data);
          }
        }
      } catch (e) {
        Logger.e('Error polling pair status: $e');
      }
    });
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic>? data) async {
    try {
      if (data != null) {
        String token = '';
        if (data.containsKey('token') && data['token'] != null) {
          token = data['token'].toString();
        } else if (data.containsKey('auth') && data['auth'] is Map) {
          token = (data['auth'] as Map)['token']?.toString() ?? '';
        } else if (data.containsKey('data') && data['data'] is Map) {
          final inner = data['data'] as Map;
          if (inner.containsKey('token') && inner['token'] != null) {
            token = inner['token'].toString();
          } else if (inner.containsKey('auth') && inner['auth'] is Map) {
            token = (inner['auth'] as Map)['token']?.toString() ?? '';
          }
        }

        if (token.isNotEmpty) {
          await TokenManager.saveToken(token);
        }

        final fullPayload = {
          'status': true,
          'message': 'Logged in successfully.',
          'data': data.containsKey('data') ? data['data'] : data,
        };
        await SharedPrefs.setString(AppConstants.tvLoginDataKey, jsonEncode(fullPayload));
        await SharedPrefs.setBool(AppConstants.isDemoModeKey, false);
      }

      await TemplateManagerService.regenerateDataJson();

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
    signUpFocus.dispose();
    licenseKeyFocus.dispose();
    roomNoFocus.dispose();
    submitFocus.dispose();
    demoActionFocus.dispose();
    selectedTabNotifier.dispose();
    super.dispose();
  }

  void _openRegisterScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TvRegisterScreen()),
    );
  }

  // ── SEGMENTED TOP TAB BAR (NETFLIX STYLE) ──────────────────────────
  Widget _buildTopTabBar(TvLoginTab selectedTab) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabItem(
            tab: TvLoginTab.qr,
            label: "Use Phone",
            isSelected: selectedTab == TvLoginTab.qr,
            focusNode: qrTabFocus,
            autofocus: true,
          ),
          const SizedBox(width: 3),
          _buildTabItem(
            tab: TvLoginTab.manual,
            label: "Use Remote",
            isSelected: selectedTab == TvLoginTab.manual,
            focusNode: manualTabFocus,
          ),
          const SizedBox(width: 3),
          _buildTabItem(
            tab: TvLoginTab.demo,
            label: "Try Free Demo",
            isSelected: selectedTab == TvLoginTab.demo,
            focusNode: demoTabFocus,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required TvLoginTab tab,
    required String label,
    required bool isSelected,
    required FocusNode focusNode,
    bool autofocus = false,
  }) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: (focused) {
        if (focused) {
          selectedTabNotifier.value = tab;
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            selectedTabNotifier.value = tab;
            if (tab == TvLoginTab.manual) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) licenseKeyFocus.requestFocus();
              });
            } else if (tab == TvLoginTab.demo) {
              if (!_isDemoLoading) _performDemoLogin();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;

          Color bgColor;
          Color textColor;
          if (isSelected) {
            bgColor = Colors.white;
            textColor = Colors.black;
          } else if (isFocused) {
            bgColor = Colors.white.withOpacity(0.20);
            textColor = Colors.white;
          } else {
            bgColor = Colors.transparent;
            textColor = Colors.white.withOpacity(0.80);
          }

          return GestureDetector(
            onTap: () {
              focusNode.requestFocus();
              selectedTabNotifier.value = tab;
              if (tab == TvLoginTab.demo && !_isDemoLoading) {
                _performDemoLogin();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: isFocused && !isSelected
                    ? Border.all(color: Colors.white70, width: 1.2)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.22),
                          blurRadius: 12,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : (isFocused
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.12),
                              blurRadius: 8,
                            ),
                          ]
                        : null),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          );
        },
      ),
    );
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

            // Top Left Branding
            Positioned(
              top: 20,
              left: 36,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 10),
                  const CustomAppText(
                    AppConstants.appName,
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ],
              ),
            ),

            // Top Right Network Header
            Positioned(
              top: 20,
              right: 36,
              child: const TvNetworkStatusHeader(),
            ),

            // Main Content Area (Netflix Style)
            Positioned.fill(
              top: 48,
              bottom: 40,
              left: 36,
              right: 36,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Center Title
                  const CustomAppText(
                    "Choose how to sign in",
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                  const SizedBox(height: 14),

                  // 3-tab pill switcher
                  ValueListenableBuilder<TvLoginTab>(
                    valueListenable: selectedTabNotifier,
                    builder: (context, selectedTab, child) {
                      return _buildTopTabBar(selectedTab);
                    },
                  ),
                  const SizedBox(height: 22),

                  // Center Selected View
                  Expanded(
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
                              onSignUpNow: _openRegisterScreen,
                              signUpFocus: signUpFocus,
                            );
                            break;
                          case TvLoginTab.manual:
                            content = Center(
                              child: ManualModeWidget(
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
                              ),
                            );
                            break;
                          case TvLoginTab.demo:
                            content = Center(
                              child: DemoPreviewWidget(
                                onStartDemo: _performDemoLogin,
                                isLoading: _isDemoLoading,
                                demoActionFocus: demoActionFocus,
                              ),
                            );
                            break;
                        }

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: content,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Left Device ID Badge
            Positioned(
              bottom: 16,
              left: 36,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CustomAppText(
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
            ),

            // Loading Overlay
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
