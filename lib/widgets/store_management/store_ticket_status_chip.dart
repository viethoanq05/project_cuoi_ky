import 'package:flutter/material.dart';

import '../../models/store_management_models.dart';

class StoreTicketStatusChip extends StatelessWidget {
  const StoreTicketStatusChip({super.key, required this.status});

  final StoreTicketStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColor(Theme.of(context), status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: colors.foreground,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  ({Color background, Color foreground}) _resolveColor(
    ThemeData theme,
    StoreTicketStatus status,
  ) {
    switch (status.value) {
      case 'pending':
        return (
          background: theme.colorScheme.secondaryContainer,
          foreground: theme.colorScheme.onSecondaryContainer,
        );
      case 'preparing':
        return (
          background: const Color(0xFFFFF3CD),
          foreground: const Color(0xFF7A4A00),
        );
      case 'delivering':
        return (
          background: const Color(0xFFD7F0FF),
          foreground: const Color(0xFF004E7A),
        );
      case 'completed':
        return (
          background: const Color(0xFFD6F5E3),
          foreground: const Color(0xFF0B5D2A),
        );
      case 'cancelled':
        return (
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.onErrorContainer,
        );
      default:
        return (
          background: theme.colorScheme.secondaryContainer,
          foreground: theme.colorScheme.onSecondaryContainer,
        );
    }
  }
}
