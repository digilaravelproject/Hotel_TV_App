import 'package:flutter/material.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'core/constants/app_constants.dart';
import 'core/services/storage/shared_prefs.dart';
import 'features/authentication/presentation/pages/app_startup_decider.dart';
import 'routes/route_helper.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefs.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveSizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          title: AppConstants.appName,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: Colors.amber,
          ),
          home: const AppStartupDecider(),
          onGenerateRoute: RouteHelper.generateRoute,
        );
      },
    );
  }
}