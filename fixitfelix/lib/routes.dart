import 'package:fixitfelix/screens/account/account_disabled_screen.dart';
import 'package:fixitfelix/screens/account/delete_account_screen.dart';
import 'package:fixitfelix/screens/app_status/force_update_screen.dart';
import 'package:fixitfelix/screens/app_status/maintenance_screen.dart';
import 'package:fixitfelix/screens/authentication/emailverify_screen.dart';
import 'package:fixitfelix/screens/authentication/forgotpw_screen.dart';
import 'package:fixitfelix/screens/authentication/onboarding/address_step.dart';
import 'package:fixitfelix/screens/authentication/onboarding/personal_details_step.dart';
import 'package:fixitfelix/screens/authentication/signin_screen.dart';
import 'package:fixitfelix/screens/authentication/signup_screen.dart';
import 'package:fixitfelix/screens/home/home_shell.dart';
import 'package:fixitfelix/screens/notifications/notifications_screen.dart';
import 'package:fixitfelix/screens/tools/files/file_upload_screen.dart';
import 'package:fixitfelix/screens/tools/files/files_list_screen.dart';
import 'package:fixitfelix/screens/tools/notes/note_edit_screen.dart';
import 'package:fixitfelix/screens/tools/notes/notes_list_screen.dart';
import 'package:fixitfelix/screens/tools/photos/photo_upload_screen.dart';
import 'package:fixitfelix/screens/tools/photos/photo_viewer_screen.dart';
import 'package:fixitfelix/screens/tools/photos/photos_grid_screen.dart';
import 'package:fixitfelix/screens/tools/videos/video_player_screen.dart';
import 'package:fixitfelix/screens/tools/videos/video_upload_screen.dart';
import 'package:fixitfelix/screens/tools/videos/videos_list_screen.dart';
import 'package:fixitfelix/screens/settings/address_edit_screen.dart';
import 'package:fixitfelix/screens/settings/bank_details_screen.dart';
import 'package:fixitfelix/screens/settings/personal_information_screen.dart';
import 'package:fixitfelix/screens/subscription/choose_plan_screen.dart';
import 'package:fixitfelix/screens/shared/webview_screen.dart';
import 'package:fixitfelix/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';

/// The customer app's route table.
///
/// Splash → sign in / sign up → email verification → onboarding → home, plus
/// the account and app-status screens the auth flow can divert to.
///
/// Onboarding is two steps here rather than the pro app's three: a customer
/// has no company to declare. The pro app's role selection and paywall are
/// absent by design — one account type, nothing to subscribe to.
class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/signIn':
        return MaterialPageRoute(builder: (_) => SignInScreen());
      case '/signUp':
        return MaterialPageRoute(builder: (_) => SignUpScreen());
      case '/forgotPassword':
        return MaterialPageRoute(builder: (_) => ForgotPasswordScreen());
      case '/emailVerify':
        return MaterialPageRoute(builder: (_) => EmailVerifyScreen());
      case '/onboarding/personal':
        return MaterialPageRoute(builder: (_) => const PersonalDetailsStep());
      case '/onboarding/address':
        return MaterialPageRoute(builder: (_) => const AddressStep());
      case '/home':
        return MaterialPageRoute(builder: (_) => const HomeShell());
      case '/settings/personalInfo':
        return MaterialPageRoute(
          builder: (_) => const PersonalInformationScreen(),
        );
      case '/settings/address':
        return MaterialPageRoute(builder: (_) => const AddressEditScreen());
      case '/settings/bank':
        return MaterialPageRoute(builder: (_) => const BankDetailsScreen());
      case '/tools/notes':
        return MaterialPageRoute(builder: (_) => const NotesListScreen());
      case '/tools/notes/edit':
        final args = settings.arguments;
        if (args is NoteEditArgs) {
          return MaterialPageRoute(
            builder: (_) => NoteEditScreen(existing: args.existing),
          );
        }
        return MaterialPageRoute(builder: (_) => const NoteEditScreen());
      case '/tools/photos':
        return MaterialPageRoute(builder: (_) => const PhotosGridScreen());
      case '/tools/photos/upload':
        return MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const PhotoUploadScreen(),
        );
      case '/tools/photos/view':
        final args = settings.arguments;
        if (args is PhotoViewerArgs) {
          return MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PhotoViewerScreen(
              photos: args.photos,
              initialIndex: args.initialIndex,
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const PhotosGridScreen());
      case '/tools/videos':
        return MaterialPageRoute(builder: (_) => const VideosListScreen());
      case '/tools/videos/upload':
        return MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const VideoUploadScreen(),
        );
      case '/tools/videos/view':
        final args = settings.arguments;
        if (args is VideoPlayerArgs) {
          return MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => VideoPlayerScreen(
              videos: args.videos,
              initialIndex: args.initialIndex,
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const VideosListScreen());
      case '/tools/files':
        return MaterialPageRoute(builder: (_) => const FilesListScreen());
      case '/tools/files/upload':
        return MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const FileUploadScreen(),
        );
      case '/notifications':
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case '/plans':
        return MaterialPageRoute(builder: (_) => const ChoosePlanScreen());
      case '/deleteAccount':
        return MaterialPageRoute(builder: (_) => const DeleteAccountScreen());
      case '/accountDisabled':
        final args = settings.arguments is Map<String, dynamic>
            ? settings.arguments as Map<String, dynamic>
            : <String, dynamic>{};
        return MaterialPageRoute(
          builder: (_) => AccountDisabledScreen(
            recoveryWindowEndsAt:
                (args['recoveryWindowEndsAt'] as num?)?.toInt(),
            personalDataRetainedUntil:
                (args['personalDataRetainedUntil'] as num?)?.toInt(),
          ),
        );
      case '/settings/webPage':
        final args = settings.arguments is Map<String, dynamic>
            ? settings.arguments as Map<String, dynamic>
            : <String, dynamic>{};
        return MaterialPageRoute(
          builder: (_) => WebViewScreen(
            title: (args['title'] as String?) ?? '',
            url: (args['url'] as String?) ?? 'https://example.com',
          ),
        );
      case '/maintenance':
        return MaterialPageRoute(builder: (_) => MaintenanceScreen());
      case '/force_update':
        return MaterialPageRoute(builder: (_) => ForceUpdateScreen());
      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(title: const Text('Error Route')),
          body: const Center(child: Text('ERROR Route!')),
        );
      },
    );
  }
}
