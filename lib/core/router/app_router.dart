import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/medicines/presentation/medicine_list_screen.dart';
import '../../features/medicines/presentation/add_medicine_screen.dart';
import '../../features/medicines/presentation/edit_medicine_screen.dart';
import '../../features/medicines/presentation/medicine_details_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/prescriptions/presentation/prescription_list_screen.dart';
import '../../features/prescriptions/presentation/add_prescription_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/medicines',
        builder: (context, state) => const MedicineListScreen(),
      ),
      GoRoute(
        path: '/medicines/add',
        builder: (context, state) => const AddMedicineScreen(),
      ),
      GoRoute(
        path: '/medicines/edit/:id',
        builder: (context, state) {
          final idStr = state.pathParameters['id']!;
          final id = int.parse(idStr);
          return EditMedicineScreen(medicineId: id);
        },
      ),
      GoRoute(
        path: '/medicines/details/:id',
        builder: (context, state) {
          final idStr = state.pathParameters['id']!;
          final id = int.parse(idStr);
          return MedicineDetailsScreen(medicineId: id);
        },
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/prescriptions',
        builder: (context, state) => const PrescriptionListScreen(),
      ),
      GoRoute(
        path: '/prescriptions/add',
        builder: (context, state) => const AddPrescriptionScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
