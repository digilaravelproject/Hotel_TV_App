import 'package:flutter/material.dart';
import '../features/authentication/presentation/pages/tv_login_screen.dart';
import '../features/dashboard/presentation/pages/tv_webview_screen.dart';

class RouteHelper {
  // Route Names
  static const String tvLogin = '/tv-login';
  static const String tvWebview = '/tv-dashboard';

  // Route Getters
  static String getTvLoginRoute() => tvLogin;
  static String getTvWebviewRoute() => tvWebview;

  // Route Generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case tvLogin:
        return MaterialPageRoute(
          builder: (_) => const TvLoginScreen(),
        );
      case tvWebview:
        return MaterialPageRoute(
          builder: (_) => const TvWebviewScreen(),
        );

      default:
        return _errorRoute();
    }
  }

  // Error Route
  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(
          child: Text('Route not found'),
        ),
      ),
    );
  }
}