import 'package:fixitfelix/screens/account/account_disabled_screen.dart';
import 'package:fixitfelix/screens/account/delete_account_screen.dart';
import 'package:fixitfelix/screens/app_status/force_update_screen.dart';
import 'package:fixitfelix/screens/app_status/maintenance_screen.dart';
import 'package:fixitfelix/screens/authentication/business/team_onboarding_screen.dart';
import 'package:fixitfelix/screens/authentication/emailverify_screen.dart';
import 'package:fixitfelix/screens/authentication/forgotpw_screen.dart';
import 'package:fixitfelix/screens/authentication/onboarding/address_step.dart';
import 'package:fixitfelix/screens/authentication/onboarding/company_details_step.dart';
import 'package:fixitfelix/screens/authentication/onboarding/personal_details_step.dart';
import 'package:fixitfelix/screens/authentication/selectrole_screen.dart';
import 'package:fixitfelix/screens/authentication/signin_screen.dart';
import 'package:fixitfelix/screens/authentication/signup_screen.dart';
import 'package:fixitfelix/screens/authentication/tradesman/tradesman_rejected_screen.dart';
import 'package:fixitfelix/screens/authentication/tradesman/tradesman_verify_waiting_screen.dart';
import 'package:fixitfelix/screens/customers/customer_edit_screen.dart';
import 'package:fixitfelix/screens/customers/customers_screen.dart';
import 'package:fixitfelix/screens/invoices/invoice_send_screen.dart';
import 'package:fixitfelix/screens/invoices/invoices_screen.dart';
import 'package:fixitfelix/screens/invoices/new_invoice_screen.dart';
import 'package:fixitfelix/screens/notifications/notifications_screen.dart';
import 'package:fixitfelix/screens/owner/owner_home.dart';
import 'package:fixitfelix/models/invoice_model.dart';
import 'package:fixitfelix/models/job_model.dart';
import 'package:fixitfelix/models/quote_model.dart';
import 'package:fixitfelix/screens/jobs/jobs_screen.dart';
import 'package:fixitfelix/screens/jobs/new_job_screen.dart';
import 'package:fixitfelix/screens/pricing/pricing_screen.dart';
import 'package:fixitfelix/screens/quotes/new_quote_screen.dart';
import 'package:fixitfelix/screens/quotes/quote_send_screen.dart';
import 'package:fixitfelix/screens/quotes/quote_settings_screen.dart';
import 'package:fixitfelix/screens/quotes/quotes_screen.dart';
import 'package:fixitfelix/screens/settings/address_edit_screen.dart';
import 'package:fixitfelix/screens/settings/bank_details_screen.dart';
import 'package:fixitfelix/screens/settings/company_details_screen.dart';
import 'package:fixitfelix/screens/settings/personal_information_screen.dart';
import 'package:fixitfelix/screens/settings/settings_screen.dart';
import 'package:fixitfelix/screens/shared/webview_screen.dart';
import 'package:fixitfelix/screens/staff/staff_edit_screen.dart';
import 'package:fixitfelix/screens/staff/staff_screen.dart';
import 'package:fixitfelix/screens/splash/splash_screen.dart';
import 'package:fixitfelix/screens/subscription/choose_plan_screen.dart';
import 'package:fixitfelix/screens/todos/todo_list_screen.dart';
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
import 'package:fixitfelix/screens/tradesman/journal/journal_event_edit_screen.dart';
import 'package:fixitfelix/screens/tradesman/tradesman_home.dart';
import 'package:flutter/material.dart';

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
      case '/createAccountCategory':
        return MaterialPageRoute(builder: (_) => SelectRoleScreen());
      case '/onboarding/personal':
        return MaterialPageRoute(
          builder: (_) => const PersonalDetailsStep(),
        );
      case '/onboarding/company':
        return MaterialPageRoute(
          builder: (_) => const CompanyDetailsStep(),
        );
      case '/onboarding/address':
        return MaterialPageRoute(builder: (_) => const AddressStep());
      case '/tradesmanVerifyWaiting':
        return MaterialPageRoute(
          builder: (_) => const TradesmanVerifyWaitingScreen(),
        );
      case '/tradesmanRejected':
        final rejectionReason = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) =>
              TradesmanRejectedScreen(rejectionReason: rejectionReason),
        );
      case '/teamOnboarding':
        return MaterialPageRoute(builder: (_) => TeamOnboardingScreen());
      // Both legacy subscription routes resolve to the simplified
      // ChoosePlanScreen; the role-specific tier ladders (legacy
      // tradesman_subscription.dart / business_subscription.dart) are
      // kept on disk but no longer reachable. Pass
      // `ChoosePlanArgs(fromSettings: true)` to render the back-button
      // / no-sign-out variant when coming from the profile card.
      case '/businessSubscription':
      case '/tradesmanSubscription':
      case '/choosePlan':
        final args = settings.arguments;
        final fromSettings =
            args is ChoosePlanArgs ? args.fromSettings : false;
        return MaterialPageRoute(
          builder: (_) => ChoosePlanScreen(fromSettings: fromSettings),
        );
      case '/tradesmanHome':
        return MaterialPageRoute(builder: (_) => const TradesmanHomeScreen());
      case '/ownerHome':
        return MaterialPageRoute(builder: (_) => const OwnerHomeScreen());
      case '/notifications':
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case '/journalEdit':
        final args = settings.arguments is JournalEditArgs
            ? settings.arguments as JournalEditArgs
            : null;
        return MaterialPageRoute(
          builder: (_) => JournalEventEditScreen(args: args),
        );
      case '/customers':
        return MaterialPageRoute(builder: (_) => const CustomersScreen());
      case '/staff':
        return MaterialPageRoute(builder: (_) => const StaffScreen());
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
      case '/quotes':
        return MaterialPageRoute(builder: (_) => const QuotesScreen());
      case '/quotes/new':
        final args = settings.arguments;
        if (args is NewQuoteArgs) {
          return MaterialPageRoute(
            builder: (_) => NewQuoteScreen(
              existing: args.existing,
              nextSequence: args.nextSequence,
            ),
          );
        }
        if (args is Quote) {
          return MaterialPageRoute(
            builder: (_) => NewQuoteScreen(existing: args),
          );
        }
        return MaterialPageRoute(builder: (_) => const NewQuoteScreen());
      case '/quotes/settings':
        return MaterialPageRoute(
          builder: (_) => const QuoteSettingsScreen(),
        );
      case '/quotes/send':
        final args = settings.arguments;
        if (args is QuoteSendArgs) {
          return MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => QuoteSendScreen(quote: args.quote),
          );
        }
        return MaterialPageRoute(builder: (_) => const QuotesScreen());
      case '/invoices':
        return MaterialPageRoute(builder: (_) => const InvoicesScreen());
      case '/invoices/new':
        final args = settings.arguments;
        if (args is NewInvoiceArgs) {
          return MaterialPageRoute(
            builder: (_) => NewInvoiceScreen(
              existing: args.existing,
              nextSequence: args.nextSequence,
            ),
          );
        }
        if (args is Invoice) {
          return MaterialPageRoute(
            builder: (_) => NewInvoiceScreen(existing: args),
          );
        }
        return MaterialPageRoute(builder: (_) => const NewInvoiceScreen());
      case '/invoices/send':
        final args = settings.arguments;
        if (args is InvoiceSendArgs) {
          return MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => InvoiceSendScreen(invoice: args.invoice),
          );
        }
        return MaterialPageRoute(builder: (_) => const InvoicesScreen());
      case '/jobs':
        return MaterialPageRoute(builder: (_) => const JobsScreen());
      case '/jobs/new':
        final args = settings.arguments;
        if (args is NewJobArgs) {
          return MaterialPageRoute(
            builder: (_) => NewJobScreen(
              existing: args.existing,
              nextSequence: args.nextSequence,
            ),
          );
        }
        if (args is Job) {
          return MaterialPageRoute(
            builder: (_) => NewJobScreen(existing: args),
          );
        }
        return MaterialPageRoute(builder: (_) => const NewJobScreen());
      case '/pricing':
        return MaterialPageRoute(builder: (_) => const PricingScreen());
      case '/staffEdit':
        final args = settings.arguments is StaffEditArgs
            ? settings.arguments as StaffEditArgs
            : null;
        return MaterialPageRoute(
          builder: (_) => StaffEditScreen(args: args),
        );
      case '/todos':
        return MaterialPageRoute(builder: (_) => const TodoListScreen());
      case '/customerEdit':
        final args = settings.arguments is CustomerEditArgs
            ? settings.arguments as CustomerEditArgs
            : null;
        return MaterialPageRoute(
          builder: (_) => CustomerEditScreen(args: args),
        );
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case '/settings/personalInfo':
        return MaterialPageRoute(
          builder: (_) => const PersonalInformationScreen(),
        );
      case '/settings/company':
        return MaterialPageRoute(
          builder: (_) => const CompanyDetailsScreen(),
        );
      case '/settings/bank':
        return MaterialPageRoute(
          builder: (_) => const BankDetailsScreen(),
        );
      case '/settings/address':
        return MaterialPageRoute(builder: (_) => const AddressEditScreen());
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
      case '/deleteAccount':
        return MaterialPageRoute(builder: (_) => const DeleteAccountScreen());
      case '/accountDisabled':
        final args = settings.arguments is Map<String, dynamic>
            ? settings.arguments as Map<String, dynamic>
            : <String, dynamic>{};
        return MaterialPageRoute(
          builder: (_) => AccountDisabledScreen(
            recoveryWindowEndsAt: (args['recoveryWindowEndsAt'] as num?)?.toInt(),
            personalDataRetainedUntil:
                (args['personalDataRetainedUntil'] as num?)?.toInt(),
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
