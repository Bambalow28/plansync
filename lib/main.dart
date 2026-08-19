import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controllers/trip_controller.dart';
import 'firebase_options.dart';
import 'models/trip.dart';
import 'services/advisor_workspace.dart';
import 'services/live_activity_service.dart';
import 'services/notification_service.dart';
import 'services/onboarding_service.dart';
import 'services/trip_link.dart';
import 'services/unsplash_service.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/trip/trip_detail_screen.dart';
import 'ui/trip/trip_review_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Let the status bar blend into the app's dark header: transparent
  // background with light (white) icons, plus a matching nav bar.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await TripController.instance.load();
  // Load the saved destination-photo urls before the first frame so cards that
  // already have one paint it immediately instead of resolving it again.
  await UnsplashService.instance.warmUp();
  await AdvisorWorkspace.instance.load();
  // Set up local notifications, then schedule reminders for existing plans.
  await NotificationService.instance.init();
  await NotificationService.instance.syncAll(TripController.instance.trips);
  // Set up the Lock Screen Live Activity for the next plan.
  await LiveActivityService.instance.init();
  await LiveActivityService.instance.syncNext(TripController.instance.trips);
  runApp(const PlanSyncApp());
}

class PlanSyncApp extends StatefulWidget {
  const PlanSyncApp({super.key});

  @override
  State<PlanSyncApp> createState() => _PlanSyncAppState();
}

class _PlanSyncAppState extends State<PlanSyncApp> {
  final _navKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Incoming plansync:// links (shared trips, e.g. from a TravelSync post).
    _linkSub = _appLinks.uriLinkStream.listen(_onUri);
    _appLinks.getInitialLink().then((u) {
      if (u != null) _onUri(u);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await OnboardingService.instance.hasSeenOnboarding()) {
        _navKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  void _onUri(Uri uri) {
    final decoded = TripLink.decode(uri);
    if (decoded == null) return;
    // Defer until the Navigator is mounted (links can arrive at cold start).
    WidgetsBinding.instance.addPostFrameCallback((_) => _importFlow(decoded));
  }

  Future<void> _importFlow(Trip decoded) async {
    final ctx = _navKey.currentContext;
    if (ctx == null) return;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Add shared trip?', style: AppText.display(20)),
        content: Text(
          'Add “${decoded.name}” and its itinerary to your trips?',
          style: AppText.body(14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppText.body(14, color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Add trip',
              style: AppText.body(14, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final trip = await TripController.instance.importTrip(decoded);
    _navKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => trip.isPast
            ? TripReviewScreen(tripId: trip.id)
            : TripDetailScreen(tripId: trip.id, showFullTopBar: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanSync',
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      theme: buildPlanSyncTheme(),
      // Tap anywhere outside a field to dismiss the keyboard.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
