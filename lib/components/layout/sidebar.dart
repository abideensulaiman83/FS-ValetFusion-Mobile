// lib/components/layout/sidebar.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MenuItem {
  final String text;
  final IconData icon;
  final String path;

  MenuItem({
    required this.text,
    required this.icon,
    required this.path,
  });
}

class Sidebar extends StatefulWidget {
  const Sidebar({Key? key}) : super(key: key);

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool isExpanded = true;
  bool masterMenuOpen = true;
  bool isSuperAdmin = false;
  bool isLocationAdmin = false;
  String currentPath = '/dashboard';

  @override
  void initState() {
    super.initState();
    _loadUserRoles();
  }

  Future<void> _loadUserRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('vf_user');

    if (userStr != null) {
      final user = jsonDecode(userStr);
      final roles = List<String>.from(user['roles'] ?? []);

      setState(() {
        isSuperAdmin = roles.contains('SUPER_ADMIN');
        isLocationAdmin = roles.contains('LOCATION_ADMIN');
      });
    }
  }

  List<MenuItem> get menuItems => [
    MenuItem(
      text: 'Dashboard',
      icon: Icons.dashboard,
      path: '/dashboard',
    ),
  ];

  List<MenuItem> get superAdminMasterMenuItems => [
    MenuItem(
      text: 'Create Company',
      icon: Icons.location_on,
      path: '/master/create-company',
    ),
    MenuItem(
      text: 'Users',
      icon: Icons.person_add,
      path: '/master/create-user',
    ),
    MenuItem(
      text: 'Vehicle Make',
      icon: Icons.car_repair,
      path: '/master/vehicle-make',
    ),
    MenuItem(
      text: 'Vehicle Colours',
      icon: Icons.palette,
      path: '/master/vehicle-colours',
    ),
    MenuItem(
      text: 'Parking List',
      icon: Icons.confirmation_number,
      path: '/master/parking-list',
    ),
    MenuItem(
      text: 'Parking Charges',
      icon: Icons.attach_money,
      path: '/master/parking-charges',
    ),
    MenuItem(
      text: 'Shops',
      icon: Icons.storefront,
      path: '/master/shops',
    ),
    MenuItem(
      text: 'Switch Location',
      icon: Icons.swap_horiz,
      path: '/master/switch-location',
    ),
  ];

  List<MenuItem> get locationAdminMenuItems => [
    MenuItem(
      text: 'Company Details',
      icon: Icons.info,
      path: '/master/company-details',
    ),
    MenuItem(
      text: 'Ticket Details',
      icon: Icons.confirmation_number,
      path: '/master/ticket-details',
    ),
    MenuItem(
      text: 'Parking Charges',
      icon: Icons.attach_money,
      path: '/master/parking-charges',
    ),
    MenuItem(
      text: 'Shops',
      icon: Icons.storefront,
      path: '/master/shops',
    ),
  ];

  List<MenuItem> getMasterMenuItems() {
    final items = <MenuItem>[];

    if (isSuperAdmin) {
      items.addAll(superAdminMasterMenuItems);
    }

    if (isLocationAdmin) {
      for (final locationItem in locationAdminMenuItems) {
        final exists = items.any((item) => item.path == locationItem.path);
        if (!exists) {
          items.add(locationItem);
        }
      }
    }

    return items;
  }

  String getMasterMenuLabel() {
    if (isSuperAdmin) return 'Master';
    if (isLocationAdmin) return 'Management';
    return 'Master';
  }

  String getRoleBadgeText() {
    if (isSuperAdmin && isLocationAdmin) {
      return 'Super Admin + Location Admin';
    } else if (isSuperAdmin) {
      return 'Super Admin';
    } else if (isLocationAdmin) {
      return 'Location Admin';
    }
    return 'Staff';
  }

  void _navigateTo(String path) {
    setState(() {
      currentPath = path;
    });
    Navigator.of(context).pushNamed(path);
  }

  @override
  Widget build(BuildContext context) {
    final expandedWidth = 240.0;
    final collapsedWidth = 70.0;
    final masterMenuItems = getMasterMenuItems();
    final showMasterMenu = isSuperAdmin || isLocationAdmin;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isExpanded ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isExpanded) ...[
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'VF',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Valet Fusion',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                  ),
                ] else
                  Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          isExpanded = !isExpanded;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Toggle Button (floating)
          Padding(
            padding: const EdgeInsets.only(top: 16, right: 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Transform.translate(
                offset: const Offset(15, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      isExpanded ? Icons.chevron_left : Icons.chevron_right,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'MAIN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                // Dashboard and other main menu items
                ...menuItems.map((item) {
                  final isActive = currentPath == item.path ||
                      (item.path == '/dashboard' && currentPath == '/');

                  return _buildMenuItem(
                    item: item,
                    isActive: isActive,
                    isExpanded: isExpanded,
                  );
                }),

                // Master Menu
                if (showMasterMenu && masterMenuItems.isNotEmpty) ...[
                  _buildMasterMenuItem(isExpanded),
                  if (isExpanded && masterMenuOpen)
                    ...masterMenuItems.map((item) {
                      final isActive = currentPath == item.path;
                      return _buildSubMenuItem(
                        item: item,
                        isActive: isActive,
                      );
                    }),
                ],
              ],
            ),
          ),

          // Role Badge at bottom
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSuperAdmin
                      ? const Color(0xFF6366F1).withOpacity(0.08)
                      : const Color(0xFF14B8A6).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isSuperAdmin
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF14B8A6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        getRoleBadgeText(),
                        style: TextStyle(
                          fontSize: (isSuperAdmin && isLocationAdmin) ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required MenuItem item,
    required bool isActive,
    required bool isExpanded,
  }) {
    final content = InkWell(
      onTap: () => _navigateTo(item.path),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isExpanded ? 16 : 8,
          vertical: 12,
        ),
        color: isActive ? Colors.grey.shade200 : null,
        child: Row(
          mainAxisAlignment:
          isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade700,
              size: 24,
            ),
            if (isExpanded) ...[
              const SizedBox(width: 16),
              Text(
                item.text,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!isExpanded) {
      return Tooltip(
        message: item.text,
        child: content,
      );
    }

    return content;
  }

  Widget _buildMasterMenuItem(bool isExpanded) {
    final content = InkWell(
      onTap: () {
        if (!isExpanded) {
          setState(() {
            isExpanded = true;
          });
        }
        setState(() {
          masterMenuOpen = !masterMenuOpen;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isExpanded ? 16 : 8,
          vertical: 12,
        ),
        child: Row(
          mainAxisAlignment:
          isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              color: Color(0xFF6366F1),
              size: 24,
            ),
            if (isExpanded) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  getMasterMenuLabel(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
              Icon(
                masterMenuOpen ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey.shade700,
              ),
            ],
          ],
        ),
      ),
    );

    if (!isExpanded) {
      return Tooltip(
        message: getMasterMenuLabel(),
        child: content,
      );
    }

    return content;
  }

  Widget _buildSubMenuItem({
    required MenuItem item,
    required bool isActive,
  }) {
    return InkWell(
      onTap: () => _navigateTo(item.path),
      child: Container(
        padding: const EdgeInsets.only(
          left: 32,
          right: 16,
          top: 12,
          bottom: 12,
        ),
        color: isActive
            ? const Color(0xFF6366F1).withOpacity(0.08)
            : null,
        child: Row(
          children: [
            Icon(
              item.icon,
              color: isActive ? const Color(0xFF6366F1) : Colors.grey.shade700,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              item.text,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}