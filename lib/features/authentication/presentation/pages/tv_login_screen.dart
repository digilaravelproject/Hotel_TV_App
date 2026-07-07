import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
import '../../../../core/services/storage/token_manger.dart';
import '../../../../core/services/template/template_manager_service.dart';
import '../../../dashboard/presentation/pages/tv_webview_screen.dart';
import '../widgets/qr_mode_widget.dart';
import '../widgets/manual_mode_widget.dart';

class TvLoginScreen extends StatefulWidget {
  const TvLoginScreen({Key? key}) : super(key: key);

  @override
  State<TvLoginScreen> createState() => _TvLoginScreenState();
}

class _TvLoginScreenState extends State<TvLoginScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController licenseKeyController;
  late final TextEditingController roomNoController;
  bool _isLoading = false;

  late final FocusNode qrTabFocus;
  late final FocusNode manualTabFocus;
  late final FocusNode licenseKeyFocus;
  late final FocusNode roomNoFocus;
  late final FocusNode submitFocus;

  // ValueNotifier to track tab state
  late final ValueNotifier<bool> isQrModeNotifier;

  @override
  void initState() {
    super.initState();
    licenseKeyController = TextEditingController(text: 'P1SU-FOO9-F4T7-YJZF');
    roomNoController = TextEditingController(text: '101');
    qrTabFocus = FocusNode();
    manualTabFocus = FocusNode();
    licenseKeyFocus = FocusNode();
    roomNoFocus = FocusNode();
    submitFocus = FocusNode();
    isQrModeNotifier = ValueNotifier<bool>(true);

    // Focus will be set via autofocus on QR tab
  }

  @override
  void dispose() {
    licenseKeyController.dispose();
    roomNoController.dispose();
    qrTabFocus.dispose();
    manualTabFocus.dispose();
    licenseKeyFocus.dispose();
    roomNoFocus.dispose();
    submitFocus.dispose();
    isQrModeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return CustomBaseWidget(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF07090E), // Deep cosmos black-blue
              Color(0xFF0C1322), // Soft night navy
              Color(0xFF07090D), // Deep space black
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background Subtle Glow Effect
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.04), // Cyan neon glow
                      blurRadius: 120,
                      spreadRadius: 60,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              right: -50,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7000FF).withOpacity(0.04), // Violet neon glow
                      blurRadius: 150,
                      spreadRadius: 80,
                    ),
                  ],
                ),
              ),
            ),

            // Main layout content
            Row(
              children: [
                // Left Side: Welcome Panel (52% width)
                Expanded(
                  flex: 11,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(64, 32, 48, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App Branding Logo Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.android,
                                color: Color(0xFF818CF8),
                                size: 24,
                              ),
                            ),
                            UiSpacer.hSpace(14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomAppText(
                                  AppConstants.appName,
                                  
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                const SizedBox(height: 2),
                                CustomAppText(
                                  "Entertainment. Your Way.",
                                  
                                  color: Colors.white70.withOpacity(0.5),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                ),
                              ],
                            ),
                          ],
                        ),
                        UiSpacer.expandedSpace(),

                        // Welcome Heading with purple underline
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomAppText(
                              AppText.welcome,
                              
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 80,
                              height: 3,
                              color: const Color(0xFF6366F1), // Purple underline
                            ),
                          ],
                        ),
                        UiSpacer.vSpace(14),

                        // Subtitle Description
                        CustomAppText(
                          AppText.welcomeSubtitle,
                          
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          height: 1.4,
                        ),
                        UiSpacer.vSpace(14),

                        // 3 Bullet Feature Items
                        _buildFeatureItem(
                          icon: Icons.business,
                          iconColor: const Color(0xFF818CF8),
                          tileColor: const Color(0xFF6366F1).withOpacity(0.15),
                          title: "Personalized Experience",
                          subtitle: "Access your favorite shows and services.",
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureItem(
                          icon: Icons.security,
                          iconColor: const Color(0xFF34D399),
                          tileColor: const Color(0xFF10B981).withOpacity(0.15),
                          title: "Secure & Private",
                          subtitle: "Your data is safe and protected.",
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureItem(
                          icon: Icons.settings_remote,
                          iconColor: const Color(0xFF60A5FA),
                          tileColor: const Color(0xFF3B82F6).withOpacity(0.15),
                          title: "Quick & Easy",
                          subtitle: "Setup will take just a few seconds.",
                        ),

                        UiSpacer.expandedSpace(),

                        // Footer: Device ID Container
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomAppText(
                                "Device ID",
                                
                                color: Colors.white70.withOpacity(0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<String>(
                                future: DeviceInfoService.getDeviceId(),
                                builder: (context, snapshot) {
                                  final deviceId = snapshot.data ?? 'Loading...';
                                  return CustomAppText(
                                    deviceId,
                                    
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
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

                // Right Side: Setup Options Card Panel (48% width)
                Expanded(
                  flex: 9,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 64, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.35),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF1E293B).withOpacity(0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 40,
                            spreadRadius: -5,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          UiSpacer.vSpace(4),
                          // Heading
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Color(0xFF60A5FA),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              CustomAppText(
                                AppText.setupTitle,
                                
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          CustomAppText(
                            "Choose an option below to get started.",
                            
                            color: Colors.white70.withOpacity(0.5),
                            fontSize: 11,
                          ),
                          UiSpacer.vSpace(10),

                          // Toggle selector capsule bar (TV Styled - Gradient select pill)
                          Container(
                            height: 40,
                            width: 280,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.05),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                // Scan QR Tab
                                Expanded(
                                  child: TvFocusable(
                                    focusNode: qrTabFocus,
                                    autofocus: true,
                                    scaleFactor: 1.0,
                                    onFocusChange: (focused) {
                                      if (focused) {
                                        isQrModeNotifier.value = true;
                                      }
                                    },
                                    onTap: () {
                                      isQrModeNotifier.value = true;
                                    },
                                    child: ValueListenableBuilder<bool>(
                                      valueListenable: isQrModeNotifier,
                                      builder: (context, isQrMode, child) {
                                        return Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            gradient: isQrMode
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFF6366F1), // Purple
                                                      Color(0xFF3B82F6), // Blue
                                                    ],
                                                  )
                                                : null,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: isQrMode
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFF6366F1).withOpacity(0.3),
                                                      blurRadius: 10,
                                                      spreadRadius: 1,
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.qr_code_scanner,
                                                color: isQrMode ? Colors.white : Colors.white70.withOpacity(0.5),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 8),
                                              CustomAppText(
                                                AppText.scanQrTab,
                                                
                                                color: isQrMode ? Colors.white : Colors.white70.withOpacity(0.5),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // Manual Entry Tab
                                Expanded(
                                  child: TvFocusable(
                                    focusNode: manualTabFocus,
                                    scaleFactor: 1.0,
                                    onFocusChange: (focused) {
                                      if (focused) {
                                        isQrModeNotifier.value = false;
                                      }
                                    },
                                    onTap: () {
                                      isQrModeNotifier.value = false;
                                    },
                                    child: ValueListenableBuilder<bool>(
                                      valueListenable: isQrModeNotifier,
                                      builder: (context, isQrMode, child) {
                                        return Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            gradient: !isQrMode
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFF6366F1), // Purple
                                                      Color(0xFF3B82F6), // Blue
                                                    ],
                                                  )
                                                : null,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: !isQrMode
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFF6366F1).withOpacity(0.3),
                                                      blurRadius: 10,
                                                      spreadRadius: 1,
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.keyboard_alt_outlined,
                                                color: !isQrMode ? Colors.white : Colors.white70.withOpacity(0.5),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 8),
                                              CustomAppText(
                                                AppText.manualEntryTab,
                                                
                                                color: !isQrMode ? Colors.white : Colors.white70.withOpacity(0.5),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          UiSpacer.vSpace(12),

                          // Tab Views (QR View or Manual Form)
                          ValueListenableBuilder<bool>(
                            valueListenable: isQrModeNotifier,
                            builder: (context, isQrMode, child) {
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: isQrMode
                                    ? const QrModeWidget()
                                    : ManualModeWidget(
                                        formKey: formKey,
                                        licenseKeyController: licenseKeyController,
                                        roomNoController: roomNoController,
                                        licenseKeyFocus: licenseKeyFocus,
                                        roomNoFocus: roomNoFocus,
                                        submitFocus: submitFocus,
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
                            },
                          ),

                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Top Right Status Bar (Network Icon, Settings Icon, stacked Time and Date)
            Positioned(
              top: 32,
              right: 64,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FutureBuilder<String>(
                    future: DeviceInfoService.getNetworkType(),
                    builder: (context, snapshot) {
                      final netType = snapshot.data ?? '';
                      IconData iconData;
                      Color iconColor = Colors.white70;

                      switch (netType) {
                        case 'WiFi':
                          iconData = Icons.wifi;
                          break;
                        case 'Ethernet':
                          iconData = Icons.lan;
                          break;
                        case 'Mobile':
                          iconData = Icons.signal_cellular_alt;
                          break;
                        case 'Disconnected':
                          iconData = Icons.signal_wifi_off;
                          iconColor = Colors.white70.withOpacity(0.3);
                          break;
                        default:
                          iconData = Icons.wifi;
                      }

                      return Icon(
                        iconData,
                        color: iconColor,
                        size: 20,
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  const LiveDateTimeWidget(),
                ],
              ),
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

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required Color tileColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomAppText(
              title,
              
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 4),
            CustomAppText(
              subtitle,
              
              color: Colors.white70.withOpacity(0.5),
              fontSize: 11,
            ),
          ],
        ),
      ],
    );
  }

  void _performRegistration(BuildContext context, String licenseKey, String roomNo) async {
    Logger.i('Registration triggered for License: $licenseKey, Room: $roomNo');

    setState(() {
      _isLoading = true;
    });

    try {
      final info = await DeviceInfoService.getFullDeviceInfo();
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
        final dataMap = response.data['data'] as Map<String, dynamic>?;
        final token = dataMap?['auth']?['token'] ?? '';
        if (token.isNotEmpty) {
          await TokenManager.saveToken(token);
        }
        await SharedPrefs.setString(AppConstants.tvLoginDataKey, jsonEncode(response.data));
        await TemplateManagerService.regenerateDataJson();

        CustomSnackbar.showSuccess(
          message: response.data['message'] ?? 'TV logged in successfully.',
        );

        // Navigate to dashboard webview
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TvWebviewScreen()),
          );
        }
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
        if (e.response?.data != null) {
          if (e.response?.data is Map) {
            errorMsg = (e.response?.data['message'] ?? e.response?.data['msg'] ?? errorMsg).toString();
          } else {
            errorMsg = e.response?.data.toString();
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
          color: Colors.white70.withOpacity(0.5),
        ),
      ],
    );
  }
}
