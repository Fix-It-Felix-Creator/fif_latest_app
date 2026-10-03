import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/customers/customers_bloc.dart';
import 'blocs/invoices/invoices_bloc.dart';
import 'blocs/jobs/jobs_bloc.dart';
import 'blocs/journal/journal_bloc.dart';
import 'blocs/pricing/pricing_bloc.dart';
import 'blocs/quote_settings/quote_settings_bloc.dart';
import 'blocs/quotes/quotes_bloc.dart';
import 'blocs/staff/staff_bloc.dart';
import 'blocs/notifications/notifications_bloc.dart';
import 'blocs/todos/todo_bloc.dart';
import 'blocs/tools/files/files_bloc.dart';
import 'blocs/tools/notes/notes_bloc.dart';
import 'blocs/tools/photos/photos_bloc.dart';
import 'blocs/tools/videos/videos_bloc.dart';
import 'blocs/leads/lead_application_bloc.dart';
import 'blocs/usage/usage_bloc.dart';
import 'globals.dart';
import 'repositories/authentication/authentication_repository.dart';
import 'repositories/configurations/configurations_repositories.dart';
import 'repositories/customers/customers_repository.dart';
import 'repositories/device/device_info_repository.dart';
import 'repositories/journal/journal_repository.dart';
import 'repositories/notifications/notifications_repository.dart';
import 'repositories/invoices/invoices_repository.dart';
import 'repositories/jobs/jobs_repository.dart';
import 'repositories/pricing/pricing_repository.dart';
import 'repositories/quotes/quote_settings_repository.dart';
import 'repositories/quotes/quotes_repository.dart';
import 'repositories/staff/staff_repository.dart';
import 'repositories/subscription/subscription_repository.dart';
import 'repositories/todos/todo_repository.dart';
import 'repositories/tools/files_repository.dart';
import 'repositories/tools/notes_repository.dart';
import 'repositories/tools/photos_repository.dart';
import 'repositories/tools/videos_repository.dart';
import 'repositories/tradesman/tradesman_repository.dart';
import 'repositories/usage/usage_repository.dart';
import 'services/push_notifications_service.dart';
import 'routes.dart';
import 'screens/app_status/app_status.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/theme.dart';
import 'theme/theme_provider.dart';

class FixItFelixApp extends StatefulWidget {
  const FixItFelixApp({super.key, required this.remoteConfigRepository});

  final ConfigurationRepository remoteConfigRepository;

  @override
  State<FixItFelixApp> createState() => _FixItFelixAppState();
}

class _FixItFelixAppState extends State<FixItFelixApp> {
  final _themeProvider = ThemeProvider();
  late final AuthRepository _authRepository;
  late final TradesmanRepository _tradesmanRepository;
  final _subscriptionRepository = SubscriptionRepository();
  final _usageRepository = UsageRepository();
  final _notificationsRepository = NotificationsRepository();
  final _journalRepository = JournalRepository();
  final _customersRepository = CustomersRepository();
  final _staffRepository = StaffRepository();
  final _pricingRepository = PricingRepository();
  final _quoteSettingsRepository = QuoteSettingsRepository();
  final _quotesRepository = QuotesRepository();
  final _invoicesRepository = InvoicesRepository();
  final _jobsRepository = JobsRepository();
  final _todoRepository = TodoRepository();
  final _notesRepository = NotesRepository();
  final _photosRepository = PhotosRepository();
  final _videosRepository = VideosRepository();
  final _filesRepository = FilesRepository();

  @override
  void initState() {
    super.initState();
    _themeProvider.initialize();

    _authRepository = AuthRepository(
      remoteConfigRepository: widget.remoteConfigRepository,
    );
    _tradesmanRepository = TradesmanRepository(
      remoteConfigRepository: widget.remoteConfigRepository,
    );

    DeviceInfoRepository.onForceLogout = (reason) {
      debugPrint('Force logout: $reason');
    };
    AuthRepository.onBeforeSignOut = () async {
      debugPrint('Before sign out cleanup');
      await PushNotificationsService.instance.clearToken();
    };
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      themeProvider: _themeProvider,
      child: ListenableBuilder(
        listenable: _themeProvider,
        builder: (context, _) {
          return MultiRepositoryProvider(
            providers: [
              RepositoryProvider<AuthRepository>.value(value: _authRepository),
              RepositoryProvider<TradesmanRepository>.value(
                value: _tradesmanRepository,
              ),
              RepositoryProvider<SubscriptionRepository>.value(
                value: _subscriptionRepository,
              ),
              RepositoryProvider<UsageRepository>.value(
                value: _usageRepository,
              ),
              RepositoryProvider<NotificationsRepository>.value(
                value: _notificationsRepository,
              ),
              RepositoryProvider<JournalRepository>.value(
                value: _journalRepository,
              ),
              RepositoryProvider<CustomersRepository>.value(
                value: _customersRepository,
              ),
              RepositoryProvider<StaffRepository>.value(
                value: _staffRepository,
              ),
              RepositoryProvider<PricingRepository>.value(
                value: _pricingRepository,
              ),
              RepositoryProvider<QuoteSettingsRepository>.value(
                value: _quoteSettingsRepository,
              ),
              RepositoryProvider<QuotesRepository>.value(
                value: _quotesRepository,
              ),
              RepositoryProvider<InvoicesRepository>.value(
                value: _invoicesRepository,
              ),
              RepositoryProvider<JobsRepository>.value(
                value: _jobsRepository,
              ),
              RepositoryProvider<TodoRepository>.value(
                value: _todoRepository,
              ),
              RepositoryProvider<NotesRepository>.value(
                value: _notesRepository,
              ),
              RepositoryProvider<PhotosRepository>.value(
                value: _photosRepository,
              ),
              RepositoryProvider<VideosRepository>.value(
                value: _videosRepository,
              ),
              RepositoryProvider<FilesRepository>.value(
                value: _filesRepository,
              ),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>(
                  create: (_) => AuthBloc(
                    authRepository: _authRepository,
                    tradesmanRepository: _tradesmanRepository,
                  )..add(const AuthStarted()),
                ),
                BlocProvider<UsageBloc>(
                  create: (_) =>
                      UsageBloc(usageRepository: _usageRepository),
                ),
                // App-wide: the home banner reads this on every screen, so
                // it cannot live inside the leads flow it opens.
                BlocProvider<LeadApplicationBloc>(
                  create: (_) => LeadApplicationBloc()
                    ..add(const LeadApplicationStartWatching()),
                ),
                BlocProvider<NotificationsBloc>(
                  create: (_) =>
                      NotificationsBloc(repository: _notificationsRepository),
                ),
                BlocProvider<JournalBloc>(
                  create: (_) =>
                      JournalBloc(repository: _journalRepository),
                ),
                BlocProvider<CustomersBloc>(
                  create: (_) =>
                      CustomersBloc(repository: _customersRepository),
                ),
                BlocProvider<StaffBloc>(
                  create: (_) => StaffBloc(repository: _staffRepository),
                ),
                BlocProvider<PricingBloc>(
                  create: (_) =>
                      PricingBloc(repository: _pricingRepository),
                ),
                BlocProvider<QuoteSettingsBloc>(
                  create: (_) => QuoteSettingsBloc(
                    repository: _quoteSettingsRepository,
                  ),
                ),
                BlocProvider<QuotesBloc>(
                  create: (_) =>
                      QuotesBloc(repository: _quotesRepository),
                ),
                BlocProvider<InvoicesBloc>(
                  create: (_) =>
                      InvoicesBloc(repository: _invoicesRepository),
                ),
                BlocProvider<JobsBloc>(
                  create: (_) => JobsBloc(repository: _jobsRepository),
                ),
                BlocProvider<TodoBloc>(
                  create: (_) => TodoBloc(repository: _todoRepository),
                ),
                BlocProvider<NotesBloc>(
                  create: (_) => NotesBloc(repository: _notesRepository),
                ),
                BlocProvider<PhotosBloc>(
                  create: (_) => PhotosBloc(repository: _photosRepository),
                ),
                BlocProvider<VideosBloc>(
                  create: (_) => VideosBloc(repository: _videosRepository),
                ),
                BlocProvider<FilesBloc>(
                  create: (_) => FilesBloc(repository: _filesRepository),
                ),
              ],
              child: ShadApp(
              title: 'Fix It Felix Pro',
              debugShowCheckedModeBanner: false,
              navigatorKey: globalNavigatorKey,
              themeMode: _themeProvider.themeMode,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              materialThemeBuilder: (context, theme) => theme,
              onGenerateRoute: RouteGenerator.generateRoute,
              // Tapping anywhere that is not itself interactive drops the
              // keyboard. `deferToChild` is what keeps this safe: the detector
              // only sees taps no inner recognizer claimed, so a button or a
              // list row still wins its own tap and this never fires twice.
              builder: (context, child) => GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: AppStatusWrapper(
                  child: child ?? const SplashScreen(),
                ),
              ),
              home: const SplashScreen(),
            ),
            ),
          );
        },
      ),
    );
  }
}
