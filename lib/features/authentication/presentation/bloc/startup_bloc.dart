import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage/shared_prefs.dart';
import '../../../../core/services/storage/token_manger.dart';
import '../../../../core/services/template/template_manager_service.dart';
import 'startup_event.dart';
import 'startup_state.dart';

class StartupBloc extends Bloc<StartupEvent, StartupState> {
  StartupBloc() : super(StartupInitial()) {
    on<CheckStartupStatus>(_onCheckStartupStatus);
  }

  Future<void> _onCheckStartupStatus(
    CheckStartupStatus event,
    Emitter<StartupState> emit,
  ) async {
    try {
      final token = await TokenManager.getToken();
      final hasLoginData =
          SharedPrefs.containsKey(AppConstants.tvLoginDataKey);

      if (token.isEmpty || !hasLoginData) {
        emit(StartupNavigateToLogin());
        return;
      }

      final isDownloaded = await TemplateManagerService.isTemplateDownloaded();
      if (isDownloaded) {
        emit(StartupNavigateToWebview());
        return;
      }

      emit(StartupInstalling(message: 'Installing...'));
      await TemplateManagerService.checkAndUpdateTemplateSilent(
        onProgress: (progress) {
          if (!isClosed) {
            emit(StartupInstalling(
              message:
                  'Installing: ${(progress * 100).toStringAsFixed(0)}%',
            ));
          }
        },
      );

      final nowDownloaded = await TemplateManagerService.isTemplateDownloaded();
      if (nowDownloaded) {
        emit(StartupNavigateToWebview());
      } else {
        emit(StartupNavigateToLogin());
      }
    } catch (_) {
      emit(StartupNavigateToLogin());
    }
  }
}
