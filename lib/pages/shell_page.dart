import 'package:flutter/material.dart';
import '../l10n.dart';
import '../main.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'doctors_list_page.dart';
import 'booking_operations_page.dart';
import 'installment_operations_page.dart';
import 'patient_management_page.dart';
import 'loan_requests_page.dart';
import 'notifications_page.dart';
import 'categories_page.dart';
import 'areas_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});
  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_outlined,       label: S.dashboard),
    _NavItem(icon: Icons.medical_services_outlined, label: S.doctors),
    _NavItem(icon: Icons.calendar_today_outlined,  label: S.bookings),
    _NavItem(icon: Icons.receipt_long_outlined,    label: S.installments),
    _NavItem(icon: Icons.people_outline,           label: S.patients),
    _NavItem(icon: Icons.request_quote_outlined,   label: S.loans),
    _NavItem(icon: Icons.notifications_outlined,   label: S.notifications),
    _NavItem(icon: Icons.category_outlined,        label: S.categories),
    _NavItem(icon: Icons.location_on_outlined,     label: S.areas),
  ];

  void _navigateTo(int index) => setState(() => _selectedIndex = index);

  List<Widget> get _pages => [
    DashboardPage(onNavigate: _navigateTo),
    const DoctorsListPage(),
    const BookingOperationsPage(),
    const InstallmentOperationsPage(),
    const PatientManagementPage(),
    const LoanRequestsPage(),
    const NotificationsPage(),
    const CategoriesPage(),
    const AreasPage(),
  ];

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = supabase.auth.currentUser;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────────────────────
          NavigationRail(
            backgroundColor: cs.surfaceContainerLow,
            extended: isWide,
            minWidth: 72,
            minExtendedWidth: 200,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.local_hospital_rounded,
                        size: 28, color: cs.primary),
                  ),
                  if (isWide) ...[
                    const SizedBox(height: 6),
                    Text(S.clinicAdmin,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                            fontSize: 14)),
                  ],
                ],
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isWide && user != null) ...[
                    Text(user.email ?? '',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                  ],
                  IconButton(
                    tooltip: S.signOut,
                    icon: const Icon(Icons.logout),
                    onPressed: _signOut,
                  ),
                ],
              ),
            ),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) =>
                setState(() => _selectedIndex = i),
            destinations: _navItems
                .map((e) => NavigationRailDestination(
                      icon: Icon(e.icon),
                      selectedIcon: Icon(e.icon, color: cs.primary),
                      label: Text(e.label),
                    ))
                .toList(),
          ),

          const VerticalDivider(width: 1),

          // ── Main content ───────────────────────────────────────────────────
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
