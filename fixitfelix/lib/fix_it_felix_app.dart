import 'package:flutter/material.dart';

import 'blocs/job_requests/job_requests_bloc.dart';
import 'blocs/jobs/jobs_bloc.dart';
import 'blocs/notifications/notifications_bloc.dart';
import 'blocs/tools/files/files_bloc.dart';
import 'blocs/tools/notes/notes_bloc.dart';
import 'blocs/tools/photos/photos_bloc.dart';
import 'blocs/tools/videos/videos_bloc.dart';
import 'repositories/job_requests/job_requests_repository.dart';
import 'repositories/jobs/jobs_repository.dart';
import 'repositories/notifications/notifications_repository.dart';
import 'repositories/tools/files_repository.dart';
import 'repositories/tools/notes_repository.dart';
import 'repositories/tools/photos_repository.dart';
import 'repositories/tools/videos_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'globals.dart';
import 'repositories/authentication/authentication_repository.dart';
import 'repositories/configurations/configurations_repositories.dart';
import 'repositories/device/device_info_repository.dart';
import 'routes.dart';
import 'screens/app_status/app_status.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/theme.dart';
import 'theme/theme_provider.dart';

/// Root of the customer app.
///
/// The same shape as the pro app's root, with the repository and bloc list cut
/// down to what the auth journey needs — the feature repositories (jobs,
/// quotes, invoices, staff, subscriptions) have no customer-side equivalent
/// yet, so providing them would only be scaffolding for code that does not
/// exist.
class FixItFelixApp extends StatefulWidget {
  const FixItFelixApp({super.key, required this.remoteConfigRepository});

  final ConfigurationRepository remoteConfigRepository;

  @override
  State<FixItFelixApp> createState() => _FixItFelixAppState();
}

class _FixItFelixAppState extends State<FixItFelixApp> {
  final _themeProvider = ThemeProvider();
  late final AuthRepository _authRepository;

  // One instance each, held by the app rather than created per route: the
  // repositories cache and stream, so a new one per screen would refetch and
  // lose the cache on every navigation.
  final _jobsRepository = JobsRepository();
  final _jobRequestsRepository = JobRequestsRepository();
  final _notificationsRepository = NotificationsRepository();
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

    DeviceInfoRepository.onForceLogout = (reason) {
      debugPrint('Force logout: $reason');
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
              RepositoryProvider<JobsRepository>.value(value: _jobsRepository),
              RepositoryProvider<JobRequestsRepository>.value(
                value: _jobRequestsRepository,
              ),
              RepositoryProvider<NotificationsRepository>.value(
                value: _notificationsRepository,
              ),
              RepositoryProvider<NotesRepository>.value(value: _notesRepository),
              RepositoryProvider<PhotosRepository>.value(value: _photosRepository),
              RepositoryProvider<VideosRepository>.value(value: _videosRepository),
              RepositoryProvider<FilesRepository>.value(value: _filesRepository),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>(
                  create: (_) =>
                      AuthBloc(authRepository: _authRepository)
                        ..add(const AuthStarted()),
                ),
                BlocProvider<NotificationsBloc>(
                  create: (_) =>
                      NotificationsBloc(repository: _notificationsRepository),
                ),
                // App-wide, not tab-scoped: the bottom bar's badge reads this
                // on every screen, so it cannot live inside the Jobs tab.
                BlocProvider<JobRequestsBloc>(
                  create: (_) => JobRequestsBloc(
                    repository: _jobRequestsRepository,
                  )..add(const JobRequestsStartWatching()),
                ),
                BlocProvider<JobsBloc>(
                  create: (_) => JobsBloc(repository: _jobsRepository),
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
                title: 'FixItFelix',
                debugShowCheckedModeBanner: false,
                navigatorKey: globalNavigatorKey,
                themeMode: _themeProvider.themeMode,
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                materialThemeBuilder: (context, theme) => theme,
                onGenerateRoute: RouteGenerator.generateRoute,
                // Tapping anywhere that is not itself interactive drops
                // the keyboard. `deferToChild` is what keeps this safe: the
                // detector only sees taps no inner recognizer claimed, so a
                // button or list row still wins its own tap and this never
                // fires twice.
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
