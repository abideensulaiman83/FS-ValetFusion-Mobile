// lib/services/desk_links.dart
//
// "Open this ticket on the desk" from anywhere (the notifications inbox today). The desk
// (DashboardPage) listens and looks the ticket up as if it had been scanned.
import 'package:flutter/material.dart';

class DeskLinks {
  DeskLinks._();

  /// A ticket waiting to be opened on the desk; the desk clears it once handled.
  static final ValueNotifier<String?> pendingTicket = ValueNotifier<String?>(null);

  /// Takes the user to the desk (the one already in the stack if there is one) and opens [ticketNo].
  static void openTicket(NavigatorState navigator, String ticketNo) {
    pendingTicket.value = ticketNo;
    var foundDesk = false;
    navigator.popUntil((route) {
      if (route.settings.name == '/dashboard') foundDesk = true;
      return foundDesk || route.isFirst;
    });
    if (!foundDesk) navigator.pushNamed('/dashboard');
  }

  /// Returns and clears the pending ticket.
  static String? take() {
    final t = pendingTicket.value;
    pendingTicket.value = null;
    return t;
  }
}
