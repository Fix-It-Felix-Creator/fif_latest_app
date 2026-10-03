import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';

const _splashOrange = Color(0xFFFF5900);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String? _version;

  // Subtle "breathing" zoom on the logo/title/badge group — scales
  // 1.00 ↔ 1.05 over 1.4s, easing both ways, repeating with reverse.
  late final AnimationController _zoomCtrl;
  late final Animation<double> _zoom;

  @override
  void initState() {
    super.initState();
    _zoomCtrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _zoom = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeInOut),
    );
    _zoomCtrl.repeat(reverse: true);
    _loadVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        context.read<AuthBloc>().add(const HandleAuthentication());
      });
    });
  }

  @override
  void dispose() {
    _zoomCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      // Show the real pubspec version plus the build number, e.g.
      // "1.0.3 (8)" — handy for QA/TestFlight to pin the exact build.
      final build = info.buildNumber.trim();
      setState(() => _version =
          build.isEmpty ? info.version : '${info.version} ($build)');
    } catch (_) {
      // Leave _version null; the footer will hide the v… token rather
      // than show "vnull".
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashOrange,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ScaleTransition(
                scale: _zoom,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/logo_white.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fix It Felix',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 54,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Text(
                _version == null
                    ? '2026 - FixItFelix Software Solution'
                    : '2026 - FixItFelix Software Solution - v$_version',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
