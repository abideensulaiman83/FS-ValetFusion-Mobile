//
// // lib/components/layout/app_layout.dart
//
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
//
// class MenuItem {
//   final String text;
//   final IconData icon;
//   final String path;
//
//   MenuItem({
//     required this.text,
//     required this.icon,
//     required this.path,
//   });
// }
//
// class AppLayout extends StatefulWidget {
//   final Widget child;
//
//   const AppLayout({
//     Key? key,
//     required this.child,
//   }) : super(key: key);
//
//   @override
//   State<AppLayout> createState() => _AppLayoutState();
// }
//
// class _AppLayoutState extends State<AppLayout> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   String currentLocation = '';
//   bool isSuperAdmin = false;
//   bool isLocationAdmin = false;
//   String currentPath = '/dashboard';
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//   }
//
//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userStr = prefs.getString('vf_user');
//
//     if (userStr != null) {
//       final user = jsonDecode(userStr);
//       final roles = List<String>.from(user['roles'] ?? []);
//
//       setState(() {
//         currentLocation = user['locationName'] ?? '';
//         isSuperAdmin = roles.contains('SUPER_ADMIN');
//         isLocationAdmin = roles.contains('LOCATION_ADMIN');
//       });
//     }
//   }
//
//   Future<void> _handleLogout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('vf_token');
//     await prefs.remove('vf_user');
//     await prefs.remove('vf_location');
//     await prefs.remove('vf_pending_locations');
//     await prefs.remove('vf_pending_user');
//
//     if (mounted) {
//       Navigator.of(context).pushNamedAndRemoveUntil(
//         '/login',
//             (route) => false,
//       );
//     }
//   }
//
//   List<MenuItem> get menuItems => [
//     MenuItem(
//       text: 'Dashboard',
//       icon: Icons.dashboard_rounded,
//       path: '/dashboard',
//     ),
//   ];
//
//   List<MenuItem> get superAdminMasterMenuItems => [
//     MenuItem(
//       text: 'Create Company',
//       icon: Icons.business_rounded,
//       path: '/master/create-company',
//     ),
//     MenuItem(
//       text: 'Users',
//       icon: Icons.people_rounded,
//       path: '/master/create-user',
//     ),
//     MenuItem(
//       text: 'Vehicle Make',
//       icon: Icons.directions_car_rounded,
//       path: '/master/vehicle-make',
//     ),
//     MenuItem(
//       text: 'Vehicle Colours',
//       icon: Icons.palette_rounded,
//       path: '/master/vehicle-colours',
//     ),
//     MenuItem(
//       text: 'Parking List',
//       icon: Icons.list_alt_rounded,
//       path: '/master/parking-list',
//     ),
//     MenuItem(
//       text: 'Parking Charges',
//       icon: Icons.attach_money_rounded,
//       path: '/master/parking-charges',
//     ),
//     MenuItem(
//       text: 'Shops',
//       icon: Icons.store_rounded,
//       path: '/master/shops',
//     ),
//     MenuItem(
//       text: 'Switch Location',
//       icon: Icons.swap_horiz_rounded,
//       path: '/master/switch-location',
//     ),
//   ];
//
//   List<MenuItem> get locationAdminMenuItems => [
//     MenuItem(
//       text: 'Company Details',
//       icon: Icons.info_rounded,
//       path: '/master/company-details',
//     ),
//     MenuItem(
//       text: 'Ticket Details',
//       icon: Icons.confirmation_number_rounded,
//       path: '/master/ticket-details',
//     ),
//     MenuItem(
//       text: 'Parking Charges',
//       icon: Icons.attach_money_rounded,
//       path: '/master/parking-charges',
//     ),
//     MenuItem(
//       text: 'Shops',
//       icon: Icons.store_rounded,
//       path: '/master/shops',
//     ),
//   ];
//
//   List<MenuItem> getMasterMenuItems() {
//     final items = <MenuItem>[];
//
//     if (isSuperAdmin) {
//       items.addAll(superAdminMasterMenuItems);
//     }
//
//     if (isLocationAdmin) {
//       for (final locationItem in locationAdminMenuItems) {
//         final exists = items.any((item) => item.path == locationItem.path);
//         if (!exists) {
//           items.add(locationItem);
//         }
//       }
//     }
//
//     return items;
//   }
//
//   String getRoleBadgeText() {
//     if (isSuperAdmin && isLocationAdmin) {
//       return 'Super Admin + Location Admin';
//     } else if (isSuperAdmin) {
//       return 'Super Admin';
//     } else if (isLocationAdmin) {
//       return 'Location Admin';
//     }
//     return 'Staff';
//   }
//
//   Color getRoleBadgeColor() {
//     if (isSuperAdmin) {
//       return const Color(0xFF6366F1);
//     } else if (isLocationAdmin) {
//       return const Color(0xFF14B8A6);
//     }
//     return const Color(0xFF64748B);
//   }
//
//   void _navigateTo(String path) {
//     setState(() {
//       currentPath = path;
//     });
//     Navigator.of(context).pop(); // Close drawer
//     Navigator.of(context).pushNamed(path);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final currentRoute = ModalRoute.of(context)?.settings.name;
//     final showAppBar = currentRoute != '/login';
//     final masterMenuItems = getMasterMenuItems();
//     final showMasterMenu = isSuperAdmin || isLocationAdmin;
//
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: const Color(0xFFF7F9FC),
//       appBar: showAppBar
//           ? AppBar(
//         elevation: 0,
//         backgroundColor: Colors.transparent,
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: const LinearGradient(
//               colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
//               begin: Alignment.centerLeft,
//               end: Alignment.centerRight,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: const Color(0xFF6366F1).withOpacity(0.3),
//                 blurRadius: 20,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.menu_rounded, color: Colors.white),
//           onPressed: () {
//             _scaffoldKey.currentState?.openDrawer();
//           },
//         ),
//         title: const Text(
//           'Valet Fusion',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 20,
//             fontWeight: FontWeight.w700,
//             letterSpacing: -0.5,
//           ),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout_rounded, color: Colors.white),
//             onPressed: _handleLogout,
//             tooltip: 'Logout',
//           ),
//         ],
//       )
//           : null,
//       drawer: showAppBar
//           ? Drawer(
//         child: Container(
//           color: Colors.white,
//           child: Column(
//             children: [
//               // Drawer Header
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
//                 decoration: const BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Container(
//                       width: 64,
//                       height: 64,
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         shape: BoxShape.circle,
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.2),
//                             blurRadius: 12,
//                             offset: const Offset(0, 4),
//                           ),
//                         ],
//                       ),
//                       child: const Center(
//                         child: Text(
//                           'VF',
//                           style: TextStyle(
//                             color: Color(0xFF6366F1),
//                             fontWeight: FontWeight.bold,
//                             fontSize: 26,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     const Text(
//                       'Valet Fusion',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     if (currentLocation.isNotEmpty) ...[
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           const Icon(
//                             Icons.location_on_rounded,
//                             color: Colors.white,
//                             size: 18,
//                           ),
//                           const SizedBox(width: 6),
//                           Expanded(
//                             child: Text(
//                               currentLocation,
//                               style: TextStyle(
//                                 color: Colors.white.withOpacity(0.95),
//                                 fontSize: 15,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//
//               // Menu Items
//               Expanded(
//                 child: ListView(
//                   padding: EdgeInsets.zero,
//                   children: [
//                     const SizedBox(height: 8),
//
//                     // Main Menu Items
//                     ...menuItems.map((item) {
//                       final isActive = currentPath == item.path ||
//                           (item.path == '/dashboard' &&
//                               currentPath == '/');
//                       return _buildDrawerItem(item, isActive);
//                     }),
//
//                     // Master Menu Section
//                     if (showMasterMenu &&
//                         masterMenuItems.isNotEmpty) ...[
//                       const Divider(height: 32),
//                       Padding(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 20,
//                           vertical: 8,
//                         ),
//                         child: Text(
//                           isSuperAdmin ? 'MASTER' : 'MANAGEMENT',
//                           style: TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w700,
//                             color: Colors.grey.shade600,
//                             letterSpacing: 1.2,
//                           ),
//                         ),
//                       ),
//                       ...masterMenuItems.map((item) {
//                         final isActive = currentPath == item.path;
//                         return _buildDrawerItem(item, isActive);
//                       }),
//                     ],
//                   ],
//                 ),
//               ),
//
//               // Role Badge at bottom
//               Container(
//                 width: double.infinity,
//                 margin: const EdgeInsets.all(16),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 12,
//                 ),
//                 decoration: BoxDecoration(
//                   color: getRoleBadgeColor().withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(
//                     color: getRoleBadgeColor().withOpacity(0.3),
//                     width: 1,
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 10,
//                       height: 10,
//                       decoration: BoxDecoration(
//                         color: getRoleBadgeColor(),
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Text(
//                         getRoleBadgeText(),
//                         style: TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w600,
//                           color: getRoleBadgeColor(),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       )
//           : null,
//       body: widget.child,
//     );
//   }
//
//   Widget _buildDrawerItem(MenuItem item, bool isActive) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//       decoration: BoxDecoration(
//         color: isActive ? const Color(0xFF6366F1).withOpacity(0.1) : null,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: ListTile(
//         leading: Icon(
//           item.icon,
//           color: isActive ? const Color(0xFF6366F1) : Colors.grey.shade700,
//           size: 24,
//         ),
//         title: Text(
//           item.text,
//           style: TextStyle(
//             fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
//             fontSize: 15,
//             color: isActive ? const Color(0xFF6366F1) : Colors.grey.shade800,
//           ),
//         ),
//         onTap: () => _navigateTo(item.path),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//       ),
//     );
//   }
// }










import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../confirm_dialog.dart';
import '../../services/authentication_service.dart';

class AppLayout extends StatefulWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;

  const AppLayout({
    Key? key,
    required this.child,
    this.title,
    this.actions,
  }) : super(key: key);

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  String currentLocation = '';
  String userName = '';
  String userRole = 'Staff';
  Color roleColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('vf_user');

    if (userStr != null) {
      final user = jsonDecode(userStr);
      final roles = List<String>.from(user['roles'] ?? []);

      setState(() {
        currentLocation = user['locationName'] ?? '';
        userName = user['name'] ?? 'User';

        // Determine role and color
        if (roles.contains('SUPER_ADMIN')) {
          userRole = 'Super Admin';
          roleColor = const Color(0xFF6366F1);
        } else if (roles.contains('LOCATION_ADMIN')) {
          userRole = 'Location Admin';
          roleColor = const Color(0xFF14B8A6);
        } else if (roles.contains('DRIVER') || roles.contains('GATE_SCANNER')) {
          userRole = 'Driver';
          roleColor = const Color(0xFF059669);
        } else {
          userRole = 'Staff';
          roleColor = Colors.grey;
        }
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to continue.",
      confirmLabel: 'Log out',
      destructive: true,
    );

    if (!confirmed) return;

    final authService = AuthenticationService();
    await authService.logoutApi();

    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
            (route) => false,
      );
    }
  }

  List<Map<String, dynamic>> getMainMenuItems() {
    return [
      {
        'title': 'Valet Desk',
        'icon': Icons.directions_car,
        'route': '/dashboard',
      },
    ];
  }

  List<Map<String, dynamic>> getMasterMenuItems() {
    final items = <Map<String, dynamic>>[];

    if (userRole == 'Super Admin') {
      items.addAll([
        {
          'title': 'Create Company',
          'icon': Icons.business,
          'route': '/master/create-company',
        },
        {
          'title': 'Users',
          'icon': Icons.people,
          'route': '/master/create-user',
        },
        {
          'title': 'Vehicle Make',
          'icon': Icons.directions_car,
          'route': '/master/vehicle-make',
        },
        {
          'title': 'Vehicle Colours',
          'icon': Icons.palette,
          'route': '/master/vehicle-colours',
        },
        {
          'title': 'Parking List',
          'icon': Icons.list_alt,
          'route': '/master/parking-list',
        },
        {
          'title': 'Parking Charges',
          'icon': Icons.attach_money,
          'route': '/master/parking-charges',
        },
        {
          'title': 'Shops',
          'icon': Icons.store,
          'route': '/master/shops',
        },
        {
          'title': 'Switch Location',
          'icon': Icons.swap_horiz,
          'route': '/master/switch-location',
        },
        {
          'title': 'Complaints',
          'icon': Icons.feedback_outlined,
          'route': '/master/complaints',
        },
      ]);
    }

    if (userRole == 'Location Admin') {
      items.addAll([
        {
          'title': 'Company Details',
          'icon': Icons.info,
          'route': '/master/company-details',
        },
        {
          'title': 'Ticket Details',
          'icon': Icons.confirmation_number,
          'route': '/master/ticket-details',
        },
        {
          'title': 'Parking Charges',
          'icon': Icons.attach_money,
          'route': '/master/parking-charges',
        },
        {
          'title': 'Shops',
          'icon': Icons.store,
          'route': '/master/shops',
        },
        {
          'title': 'Complaints',
          'icon': Icons.feedback_outlined,
          'route': '/master/complaints',
        },
      ]);
    }

    if (userRole == 'Driver') {
      items.addAll([
        {
          'title': 'My Activity',
          'icon': Icons.bar_chart_outlined,
          'route': '/driver/activity',
        },
        {
          'title': 'Privacy & Policy',
          'icon': Icons.privacy_tip_outlined,
          'route': '/privacy-policy',
        },
      ]);
    }

    // Remove duplicates
    final uniqueItems = <Map<String, dynamic>>[];
    for (var item in items) {
      if (!uniqueItems.any((element) => element['route'] == item['route'])) {
        uniqueItems.add(item);
      }
    }

    return uniqueItems;
  }

  @override

  Widget build(BuildContext context) {
    final mainMenuItems = getMainMenuItems();
    final masterMenuItems = getMasterMenuItems();
    final hasMasterMenu = masterMenuItems.isNotEmpty;

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      await _handleLogout();
    },
    child: Scaffold(
    appBar: AppBar(
    title: Text(widget.title ?? 'Valet Fusion'),
    actions: [
    if (widget.actions != null) ...widget.actions!,
    IconButton(
    icon: const Icon(Icons.logout),
    onPressed: _handleLogout,
    tooltip: 'Logout',
    ),
    ],
    ),
    drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // User Profile Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      roleColor.withOpacity(0.8),
                      roleColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'V',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // User Info
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        userRole,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    if (currentLocation.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              currentLocation,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Menu Items
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Main Menu
                      if (mainMenuItems.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'MAIN MENU',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ...mainMenuItems.map((item) => _buildDrawerItem(item)),
                      ],

                      // Master Menu
                      if (hasMasterMenu) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            userRole == 'Super Admin' ? 'MASTER' : 'MANAGEMENT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ...masterMenuItems.map((item) => _buildDrawerItem(item)),
                      ],
                    ],
                  ),
                ),
              ),

              // App Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Valet Fusion v1.0.0',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '© 2024 All rights reserved',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: widget.child,
    ),
    );
  }

  Widget _buildDrawerItem(Map<String, dynamic> item) {
    return ListTile(
      leading: Icon(
        item['icon'] as IconData,
        color: Colors.grey.shade700,
      ),
      title: Text(
        item['title'] as String,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade800,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.pushNamed(context, item['route'] as String);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}