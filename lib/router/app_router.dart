import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/landing_screen.dart';
import '../screens/public_catalog_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/guest_checkout_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/admin_home_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/reviews_screen.dart';
import '../screens/impressions_screen.dart';
import '../screens/shipping_info_screen.dart';
import '../screens/inventory_dashboard_screen.dart';
import '../screens/inventory_archive_screen.dart';
import '../screens/inventory_import_screen.dart';
import '../screens/inventory_item_screen.dart';
import '../screens/ean_management_screen.dart';
import '../screens/sail_inventory_screen.dart';
import '../screens/customer_list_screen.dart';
import '../screens/customer_detail_screen.dart';
import '../screens/admin_sales_channels_screen.dart';
import '../screens/inventory_log_screen.dart';
import '../screens/marketplace_dashboard_screen.dart';
import '../widgets/public_shell.dart';

final navigatorKey = GlobalKey<NavigatorState>();

bool get _isLoggedIn {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return false;
  final expiry = session.expiresAt;
  if (expiry != null && DateTime.fromMillisecondsSinceEpoch(expiry * 1000).isBefore(DateTime.now())) {
    return false;
  }
  return true;
}

class AuthNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authNotifier = AuthNotifier();

final appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  refreshListenable: authNotifier,
  redirect: (context, state) {
    final path = state.matchedLocation;
    // Authentication gate: login required for dashboard routes.
    // Fine-grained role/permission checks are enforced within the screens
    // themselves based on UserPermissions and UserType.
    const protectedPrefixes = ['/dashboard', '/bedrijfsgegevens', '/templates'];
    final isProtected = protectedPrefixes.any((p) => path.startsWith(p));

    if (isProtected && !_isLoggedIn) {
      return '/inloggen?redirect=${Uri.encodeComponent(path)}';
    }
    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) => PublicShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: LandingScreen(),
          ),
        ),
        GoRoute(
          path: '/catalogus',
          pageBuilder: (context, state) {
            final cat = state.uri.queryParameters['categorie'];
            return NoTransitionPage(
              child: PublicCatalogScreen(initialCategory: cat),
            );
          },
        ),
        GoRoute(
          path: '/product/:id',
          pageBuilder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return NoTransitionPage(
              child: ProductDetailScreen(productId: id),
            );
          },
        ),
        GoRoute(
          path: '/winkelwagen',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: CartScreen(),
          ),
        ),
        GoRoute(
          path: '/beoordelingen',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ReviewsScreen(),
          ),
        ),
        GoRoute(
          path: '/impressies',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ImpressionsScreen(),
          ),
        ),
        GoRoute(
          path: '/verzending',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ShippingInfoScreen(),
          ),
        ),
        GoRoute(
          path: '/inloggen',
          pageBuilder: (context, state) {
            final rawRedirect = state.uri.queryParameters['redirect'];
            final safeRedirect = (rawRedirect != null
                && rawRedirect.startsWith('/')
                && !rawRedirect.startsWith('//')
                && !rawRedirect.contains('://'))
                ? rawRedirect : null;
            return NoTransitionPage(
              child: LoginScreen(
                onLoginSuccess: () {
                  navigatorKey.currentContext?.go(safeRedirect ?? '/dashboard');
                },
              ),
            );
          },
        ),
        GoRoute(
          path: '/registreren',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: RegisterScreen(),
          ),
        ),
        GoRoute(
          path: '/afrekenen',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GuestCheckoutScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: AdminHomeScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/beheer',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: DashboardScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/voorraad',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: InventoryDashboardScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/voorraad/archief',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: InventoryArchiveScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/voorraad/import',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: InventoryImportScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/voorraad/item',
      pageBuilder: (context, state) {
        final id = state.uri.queryParameters['id'];
        return NoTransitionPage(
          child: InventoryItemScreen(itemId: id != null ? int.tryParse(id) : null),
        );
      },
    ),
    GoRoute(
      path: '/dashboard/ean-beheer',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: EanManagementScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/zeil-voorraad',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: SailInventoryScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/klanten',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: CustomerListScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/klant',
      pageBuilder: (context, state) {
        final id = state.uri.queryParameters['id'];
        return NoTransitionPage(
          child: CustomerDetailScreen(customerId: id),
        );
      },
    ),
    GoRoute(
      path: '/dashboard/verkoopkanalen',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: AdminSalesChannelsScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/voorraadlog',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: InventoryLogScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/marktplaatsen',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: MarketplaceDashboardScreen(),
      ),
    ),
    GoRoute(
      path: '/dashboard/kanaaloverzicht',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: MarketplaceDashboardScreen(initialTabIndex: 1),
      ),
    ),
  ],
);
