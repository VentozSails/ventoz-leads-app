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
import '../services/user_service.dart';
import '../widgets/public_shell.dart';

/// Central route → permission mapping.
/// Each entry maps a route path to the permission key(s) required.
/// If multiple keys are listed, ANY of them grants access (OR logic).
/// Routes not listed here are either public or only require login.
/// When adding a new /dashboard/* route, add its required permission here;
/// the router redirect will enforce it automatically.
const _routePermissions = <String, List<String>>{
  '/dashboard/voorraad':         ['voorraad_beheren'],
  '/dashboard/voorraad/archief': ['voorraad_beheren'],
  '/dashboard/voorraad/import':  ['voorraad_importeren'],
  '/dashboard/voorraad/item':    ['voorraad_beheren'],
  '/dashboard/ean-beheer':       ['ean_codes_beheren'],
  '/dashboard/zeil-voorraad':    ['voorraad_beheren'],
  '/dashboard/klanten':          ['klanten_beheren'],
  '/dashboard/klant':            ['klanten_beheren'],
  '/dashboard/verkoopkanalen':   ['verkoopkanalen_beheren'],
  '/dashboard/voorraadlog':      ['voorraad_beheren'],
  '/dashboard/marktplaatsen':    ['marktplaats_koppelingen', 'verkoopkanalen_beheren'],
  '/dashboard/kanaaloverzicht':  ['marktplaats_koppelingen', 'verkoopkanalen_beheren'],
};

UserPermissions? _cachedPerms;
DateTime? _cachedPermsAt;

Future<UserPermissions> _getPerms() async {
  final now = DateTime.now();
  if (_cachedPerms != null && _cachedPermsAt != null &&
      now.difference(_cachedPermsAt!).inSeconds < 30) {
    return _cachedPerms!;
  }
  _cachedPerms = await UserService().getCurrentUserPermissions();
  _cachedPermsAt = now;
  return _cachedPerms!;
}

/// Invalidate cached permissions (call on login/logout/impersonation).
void invalidatePermissionCache() {
  _cachedPerms = null;
  _cachedPermsAt = null;
}

/// Wire up the UserService hook so impersonation changes invalidate the cache.
void initRouterPermissionHook() {
  UserService.onPermissionsChanged = invalidatePermissionCache;
}

/// Wraps a child screen with an async permission check.
/// If the user lacks the required permission(s) for the matched route,
/// they are redirected to /dashboard with an error message.
class _PermissionGate extends StatefulWidget {
  final String routePath;
  final Widget child;
  const _PermissionGate({required this.routePath, required this.child});

  @override
  State<_PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<_PermissionGate> {
  bool _checked = false;
  bool _allowed = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final requiredKeys = _routePermissions[widget.routePath];
    if (requiredKeys == null || requiredKeys.isEmpty) {
      if (mounted) setState(() { _checked = true; _allowed = true; });
      return;
    }
    final perms = await _getPerms();
    final hasAccess = requiredKeys.any((key) => perms.getByKey(key));
    if (!mounted) return;
    if (!hasAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
      );
      context.go('/dashboard');
      return;
    }
    setState(() { _checked = true; _allowed = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_allowed) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}

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
      invalidatePermissionCache();
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
            final isInvite = state.uri.queryParameters['invite'] == 'true';
            return NoTransitionPage(
              child: LoginScreen(
                startWithInvite: isInvite,
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
      pageBuilder: (context, state) => NoTransitionPage(
        child: _PermissionGate(routePath: '/dashboard/voorraad', child: const InventoryDashboardScreen()),
      ),
    ),
    GoRoute(
      path: '/dashboard/voorraad/archief',
      pageBuilder: (context, state) => NoTransitionPage(
        child: _PermissionGate(routePath: '/dashboard/voorraad/archief', child: const InventoryArchiveScreen()),
      ),
    ),
    GoRoute(
      path: '/dashboard/voorraad/import',
      pageBuilder: (context, state) => NoTransitionPage(
        child: _PermissionGate(routePath: '/dashboard/voorraad/import', child: const InventoryImportScreen()),
      ),
    ),
    GoRoute(
      path: '/dashboard/voorraad/item',
      pageBuilder: (context, state) {
        final id = state.uri.queryParameters['id'];
        return NoTransitionPage(
          child: _PermissionGate(routePath: '/dashboard/voorraad/item', child: InventoryItemScreen(itemId: id != null ? int.tryParse(id) : null)),
        );
      },
    ),
    GoRoute(
      path: '/dashboard/ean-beheer',
      pageBuilder: (context, state) => NoTransitionPage(
        child: _PermissionGate(routePath: '/dashboard/ean-beheer', child: const EanManagementScreen()),
      ),
    ),
    GoRoute(
      path: '/dashboard/zeil-voorraad',
      pageBuilder: (context, state) => NoTransitionPage(
        child: _PermissionGate(routePath: '/dashboard/zeil-voorraad', child: const SailInventoryScreen()),
      ),
    ),
    GoRoute(
      path: '/dashboard/klanten',
      pageBuilder: (context, state) => NoTransitionPage(
        child: _PermissionGate(routePath: '/dashboard/klanten', child: const CustomerListScreen()),
      ),
    ),
    GoRoute(
      path: '/dashboard/klant',
      pageBuilder: (context, state) {
        final id = state.uri.queryParameters['id'];
        return NoTransitionPage(
          child: _PermissionGate(routePath: '/dashboard/klant', child: CustomerDetailScreen(customerId: id)),
        );
      },
    ),
    GoRoute(
      path: '/dashboard/verkoopkanalen',
      pageBuilder: (context, state) => NoTransitionPage(
        child: _PermissionGate(routePath: '/dashboard/verkoopkanalen', child: const AdminSalesChannelsScreen()),
      ),
    ),
    GoRoute(
      path: '/dashboard/voorraadlog',
      pageBuilder: (context, state) => NoTransitionPage(
        child: _PermissionGate(routePath: '/dashboard/voorraadlog', child: const InventoryLogScreen()),
      ),
    ),
    GoRoute(
      path: '/dashboard/marktplaatsen',
      pageBuilder: (context, state) => NoTransitionPage(
        child: _PermissionGate(routePath: '/dashboard/marktplaatsen', child: const MarketplaceDashboardScreen()),
      ),
    ),
    GoRoute(
      path: '/dashboard/kanaaloverzicht',
      pageBuilder: (context, state) => NoTransitionPage(
        child: _PermissionGate(routePath: '/dashboard/kanaaloverzicht', child: const MarketplaceDashboardScreen(initialTabIndex: 1)),
      ),
    ),
  ],
);
