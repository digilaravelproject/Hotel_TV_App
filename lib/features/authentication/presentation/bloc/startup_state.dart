abstract class StartupState {}

class StartupInitial extends StartupState {}

class StartupInstalling extends StartupState {
  final String message;
  StartupInstalling({required this.message});
}

class StartupNavigateToLogin extends StartupState {}

class StartupNavigateToWebview extends StartupState {}
