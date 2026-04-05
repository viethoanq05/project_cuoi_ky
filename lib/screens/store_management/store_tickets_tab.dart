import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/store_management_models.dart';
import '../../services/store_management_service.dart';
import '../../widgets/store_management/store_ticket_status_chip.dart';
import 'store_management_formatters.dart';

class StoreTicketsTab extends StatefulWidget {
  const StoreTicketsTab({super.key});

  @override
  State<StoreTicketsTab> createState() => _StoreTicketsTabState();
}

class _StoreTicketsTabState extends State<StoreTicketsTab> {
  final Set<String> _updatingTicketIds = <String>{};
  final TextEditingController _searchController = TextEditingController();
  StoreTicketStatus? _statusFilter;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.read<StoreManagementService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Tìm theo mã đơn',
                  hintText: 'Nhập mã đơn cần tìm',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<StoreTicketStatus?>(
                initialValue: _statusFilter,
                decoration: InputDecoration(
                  labelText: 'Lọc theo trạng thái',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem<StoreTicketStatus?>(
                    value: null,
                    child: Text('Tất cả trạng thái'),
                  ),
                  ...StoreTicketStatus.values.map((status) {
                    return DropdownMenuItem<StoreTicketStatus?>(
                      value: status,
                      child: Text(status.label),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<StoreTicket>>(
            stream: service.watchStoreTickets(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Không tải được danh sách đơn: ${snapshot.error}',
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tickets = snapshot.data!;
              final filteredTickets = tickets.where((ticket) {
                final statusMatched =
                    _statusFilter == null || ticket.status == _statusFilter;
                final codeMatched =
                    _searchQuery.isEmpty ||
                    ticket.id.toLowerCase().contains(_searchQuery);
                return statusMatched && codeMatched;
              }).toList();

              if (filteredTickets.isEmpty) {
                return Center(
                  child: Text(
                    _searchQuery.isEmpty && _statusFilter == null
                        ? 'Chưa có đơn hàng nào.'
                        : 'Không có đơn hàng phù hợp với bộ lọc hiện tại.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filteredTickets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final ticket = filteredTickets[index];
                  final isSaving = _updatingTicketIds.contains(ticket.id);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Mã đơn: ${ticket.id}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              StoreTicketStatusChip(status: ticket.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Khách hàng: ${ticket.customerName}'),
                          const SizedBox(height: 4),
                          Text(
                            'Tổng tiền: ${formatStoreCurrency(ticket.totalAmount)}',
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<StoreTicketStatus>(
                            initialValue: ticket.status,
                            decoration: const InputDecoration(
                              labelText: 'Cập nhật trạng thái đơn',
                            ),
                            items: StoreTicketStatus.values.map((status) {
                              return DropdownMenuItem<StoreTicketStatus>(
                                value: status,
                                child: Text(status.label),
                              );
                            }).toList(),
                            onChanged: isSaving
                                ? null
                                : (newStatus) {
                                    if (newStatus == null ||
                                        newStatus == ticket.status) {
                                      return;
                                    }
                                    _updateStatus(ticket.id, newStatus);
                                  },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _updateStatus(String ticketId, StoreTicketStatus status) async {
    setState(() {
      _updatingTicketIds.add(ticketId);
    });

    try {
      await context.read<StoreManagementService>().updateTicketStatus(
        ticketId: ticketId,
        status: status,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật trạng thái đơn hàng.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cập nhật thất bại: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _updatingTicketIds.remove(ticketId);
        });
      }
    }
  }
}
