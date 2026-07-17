import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/repair_board/presentation/screens/repair_board_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/customers/presentation/screens/customer_detail_screen.dart';
import '../../features/customers/presentation/screens/customer_form_screen.dart';
import '../../features/devices/presentation/screens/devices_screen.dart';
import '../../features/devices/presentation/screens/device_detail_screen.dart';
import '../../features/devices/presentation/screens/device_form_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_detail_screen.dart';
import '../../features/maintenance/presentation/screens/maintenance_form_screen.dart';
import '../../features/maintenance/presentation/cubit/maintenance_cubit.dart';
import '../../features/warranty/presentation/screens/warranty_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/inventory/presentation/screens/product_form_screen.dart';
import '../../features/inventory/presentation/cubit/inventory_cubit.dart';
import '../../features/suppliers/presentation/screens/suppliers_screen.dart';
import '../../features/purchases/presentation/screens/purchases_screen.dart';
import '../../features/purchases/presentation/screens/purchase_form_screen.dart';
import '../../features/sales/presentation/screens/sales_screen.dart';
import '../../features/sales/presentation/screens/sale_form_screen.dart';
import '../../features/invoices/presentation/screens/invoices_screen.dart';
import '../../features/accounting/presentation/screens/accounting_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/whatsapp/presentation/screens/whatsapp_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/backup/presentation/screens/backup_screen.dart';
import '../../features/settings/presentation/screens/shop_setup_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/technicians/presentation/screens/technicians_screen.dart';
import '../../features/media/presentation/screens/media_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/auth/presentation/screens/users_screen.dart';
import '../../features/barcode/presentation/screens/barcode_scan_screen.dart';
import '../../features/tracking/presentation/screens/tracking_screen.dart';
import '../layout/main_layout.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/shop-setup',
        builder: (context, state) => const ShopSetupScreen(),
      ),
      GoRoute(
        path: '/track',
        builder: (context, state) => TrackingScreen(
          initialCode: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(
        path: '/track/:code',
        builder: (context, state) => TrackingScreen(
          initialCode: state.pathParameters['code'],
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/repair-board',
            builder: (context, state) => const RepairBoardScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const CustomerFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => CustomerDetailScreen(
                    customerId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => CustomerFormScreen(
                      customerId: state.pathParameters['id'],
                    ),
                  ),
                  GoRoute(
                    path: 'devices/new',
                    builder: (context, state) => DeviceFormScreen(
                      customerId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/devices',
            builder: (context, state) => const DevicesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    DeviceDetailScreen(deviceId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/maintenance',
            builder: (context, state) => BlocProvider(
              create: (_) => MaintenanceCubit(),
              child: const MaintenanceScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => BlocProvider(
                  create: (_) => MaintenanceCubit(),
                  child: MaintenanceFormScreen(
                    customerId: state.uri.queryParameters['customerId'],
                    deviceId: state.uri.queryParameters['deviceId'],
                  ),
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => BlocProvider(
                  create: (_) => MaintenanceCubit(),
                  child: MaintenanceDetailScreen(
                    maintenanceId: state.pathParameters['id']!,
                    justCreated:
                        state.uri.queryParameters['justCreated'] == '1',
                  ),
                ),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) => BlocProvider(
                  create: (_) => MaintenanceCubit(),
                  child: MaintenanceFormScreen(
                    maintenanceId: state.pathParameters['id'],
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/warranty',
            builder: (context, state) => const WarrantyScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => BlocProvider(
              create: (_) => InventoryCubit(),
              child: const InventoryScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => BlocProvider(
                  create: (_) => InventoryCubit(),
                  child: const ProductFormScreen(),
                ),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) => BlocProvider(
                  create: (_) => InventoryCubit(),
                  child:
                      ProductFormScreen(productId: state.pathParameters['id']),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/suppliers',
            builder: (context, state) => const SuppliersScreen(),
          ),
          GoRoute(
            path: '/purchases',
            builder: (context, state) => const PurchasesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const PurchaseFormScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => const SalesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const SaleFormScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoicesScreen(),
          ),
          GoRoute(
            path: '/accounting',
            builder: (context, state) => const AccountingScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/whatsapp',
            builder: (context, state) => const WhatsappScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/backup',
            builder: (context, state) => const BackupScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/technicians',
            builder: (context, state) => const TechniciansScreen(),
          ),
          GoRoute(
            path: '/media',
            builder: (context, state) => const MediaScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/barcode',
            builder: (context, state) => const BarcodeScanScreen(),
          ),
        ],
      ),
    ],
  );
}
