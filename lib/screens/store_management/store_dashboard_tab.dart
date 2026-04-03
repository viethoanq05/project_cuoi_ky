import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/store_management_models.dart';
import '../../services/store_management_service.dart';
import '../../widgets/store_management/stats_card.dart';
import 'store_management_formatters.dart';

class StoreDashboardTab extends StatelessWidget {
  const StoreDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<StoreManagementService>();

    return StreamBuilder<StoreStats>(
      stream: service.watchStats(),
      builder: (context, statsSnapshot) {
        if (statsSnapshot.hasError) {
          return Center(
            child: Text('Không tải được thống kê: ${statsSnapshot.error}'),
          );
        }

        if (!statsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = statsSnapshot.data ?? StoreStats.empty;

        return StreamBuilder<List<StoreTicket>>(
          stream: service.watchStoreTickets(),
          builder: (context, ticketsSnapshot) {
            if (ticketsSnapshot.hasError) {
              return Center(
                child: Text(
                  'Không tải được biểu đồ 7 ngày: ${ticketsSnapshot.error}',
                ),
              );
            }

            if (!ticketsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final tickets = ticketsSnapshot.data ?? const <StoreTicket>[];
            final sevenDayStats = _buildSevenDayStats(tickets);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatsSection(stats),
                const SizedBox(height: 16),
                _OverviewBarChartCard(stats: stats),
                const SizedBox(height: 16),
                _SevenDayBarChartCard(days: sevenDayStats),
              ],
            );
          },
        );
      },
    );
  }

  List<_DailyStat> _buildSevenDayStats(List<StoreTicket> tickets) {
    final now = DateTime.now();
    final endDay = DateTime(now.year, now.month, now.day);
    final startDay = endDay.subtract(const Duration(days: 6));

    final daily = <DateTime, _DailyStat>{};
    for (var i = 0; i < 7; i++) {
      final day = startDay.add(Duration(days: i));
      daily[day] = _DailyStat(day: day, revenue: 0, orderCount: 0);
    }

    for (final ticket in tickets) {
      final createdAt = ticket.createdAt;
      if (createdAt == null) {
        continue;
      }

      final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
      if (day.isBefore(startDay) || day.isAfter(endDay)) {
        continue;
      }

      final current = daily[day];
      if (current == null) {
        continue;
      }

      final revenue = ticket.status == StoreTicketStatus.completed
          ? current.revenue + ticket.totalAmount
          : current.revenue;

      daily[day] = _DailyStat(
        day: day,
        revenue: revenue,
        orderCount: current.orderCount + 1,
      );
    }

    return daily.values.toList()..sort((a, b) {
      final byWeekday = a.day.weekday.compareTo(b.day.weekday);
      if (byWeekday != 0) {
        return byWeekday;
      }
      return a.day.compareTo(b.day);
    });
  }

  Widget _buildStatsSection(StoreStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 880;
        final cards = <Widget>[
          StatsCard(
            title: 'Tổng doanh thu',
            value: formatStoreCurrency(stats.totalRevenue),
            icon: Icons.payments_outlined,
            color: const Color(0xFF0F766E),
          ),
          StatsCard(
            title: 'Tổng số đơn hàng',
            value: '${stats.totalTickets}',
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF1D4ED8),
          ),
          StatsCard(
            title: 'Đơn hàng trong ngày',
            value: '${stats.todayTickets}',
            icon: Icons.today_outlined,
            color: const Color(0xFFB45309),
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i != cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _OverviewBarChartCard extends StatelessWidget {
  const _OverviewBarChartCard({required this.stats});

  final StoreStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = <_MetricBarData>[
      _MetricBarData(
        label: 'Doanh thu',
        value: stats.totalRevenue,
        displayValue: formatStoreCurrency(stats.totalRevenue),
        color: const Color(0xFF0F766E),
      ),
      _MetricBarData(
        label: 'Tổng đơn',
        value: stats.totalTickets.toDouble(),
        displayValue: '${stats.totalTickets} đơn',
        color: const Color(0xFF1D4ED8),
      ),
      _MetricBarData(
        label: 'Đơn hôm nay',
        value: stats.todayTickets.toDouble(),
        displayValue: '${stats.todayTickets} đơn',
        color: const Color(0xFFB45309),
      ),
    ];

    final maxValue = metrics.fold<double>(
      1,
      (current, item) => math.max(current, item.value),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Biểu đồ cột tổng quan',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const SizedBox(height: 14),
            SizedBox(
              height: 210,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final item in metrics)
                    Expanded(
                      child: _MetricBar(item: item, maxValue: maxValue),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.item, required this.maxValue});

  final _MetricBarData item;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = maxValue <= 0 ? 0.0 : (item.value / maxValue);
    final displayRatio = ratio <= 0 ? 0.05 : ratio.clamp(0.05, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            item.displayValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: displayRatio,
                child: Tooltip(
                  message: '${item.label}: ${item.displayValue}',
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: item.color,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(item.label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _MetricBarData {
  const _MetricBarData({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.color,
  });

  final String label;
  final double value;
  final String displayValue;
  final Color color;
}

class _DailyStat {
  const _DailyStat({
    required this.day,
    required this.revenue,
    required this.orderCount,
  });

  final DateTime day;
  final double revenue;
  final int orderCount;
}

class _SevenDayBarChartCard extends StatelessWidget {
  const _SevenDayBarChartCard({required this.days});

  final List<_DailyStat> days;

  static const List<String> _weekdayLabels = <String>[
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxRevenue = days.fold<double>(
      1,
      (current, item) => math.max(current, item.revenue),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Biểu đồ doanh thu 7 ngày',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),

            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final item in days)
                    Expanded(
                      child: _SevenDayBar(
                        item: item,
                        maxRevenue: maxRevenue,
                        dayLabel: _weekdayLabels[item.day.weekday - 1],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SevenDayBar extends StatelessWidget {
  const _SevenDayBar({
    required this.item,
    required this.maxRevenue,
    required this.dayLabel,
  });

  final _DailyStat item;
  final double maxRevenue;
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = maxRevenue <= 0 ? 0.0 : (item.revenue / maxRevenue);
    final displayRatio = ratio <= 0 ? 0.04 : ratio.clamp(0.04, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            formatStoreCurrency(item.revenue),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: displayRatio,
                child: Tooltip(
                  message:
                      '$dayLabel: ${formatStoreCurrency(item.revenue)} • ${item.orderCount} đơn',
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(dayLabel, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
