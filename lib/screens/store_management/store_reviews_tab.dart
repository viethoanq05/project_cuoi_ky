import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/store_management_models.dart';
import '../../services/store_management_service.dart';
import '../../widgets/store_management/review_tile.dart';

class StoreReviewsTab extends StatefulWidget {
  const StoreReviewsTab({super.key});

  @override
  State<StoreReviewsTab> createState() => _StoreReviewsTabState();
}

class _StoreReviewsTabState extends State<StoreReviewsTab> {
  final Map<String, TextEditingController> _replyControllers =
      <String, TextEditingController>{};
  final Set<String> _savingReviewIds = <String>{};
  _ReviewFilter _activeFilter = _ReviewFilter.all;

  @override
  void dispose() {
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.read<StoreManagementService>();

    return StreamBuilder<List<StoreReview>>(
      stream: service.watchReviews(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Không tải được đánh giá: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data!;
        if (reviews.isEmpty) {
          return Center(
            child: Text(
              'Chưa có đánh giá nào.',
              style: theme.textTheme.bodyMedium,
            ),
          );
        }

        final filteredReviews = _applyFilter(reviews);

        final averageRating = reviews.isEmpty
            ? 0.0
            : reviews
                      .map((item) => item.rating)
                      .reduce((left, right) => left + right) /
                  reviews.length;
        final repliedCount = reviews.where((item) => item.hasReply).length;
        final replyRate = reviews.isEmpty ? 0.0 : repliedCount / reviews.length;

        return Column(
          children: [
            _ReviewsSummaryHeader(
              averageRating: averageRating,
              totalReviews: reviews.length,
              repliedCount: repliedCount,
              replyRate: replyRate,
            ),
            _ReviewsFilterBar(
              activeFilter: _activeFilter,
              onFilterChanged: (next) {
                setState(() {
                  _activeFilter = next;
                });
              },
            ),
            Expanded(
              child: filteredReviews.isEmpty
                  ? Center(
                      child: Text(
                        'Không có đánh giá phù hợp với bộ lọc hiện tại.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filteredReviews.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final review = filteredReviews[index];
                        final controller = _controllerFor(review);

                        return ReviewTile(
                          review: review,
                          replyController: controller,
                          saving: _savingReviewIds.contains(review.id),
                          onSubmitReply: () => _submitReply(review),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  List<StoreReview> _applyFilter(List<StoreReview> source) {
    switch (_activeFilter) {
      case _ReviewFilter.all:
        return source;
      case _ReviewFilter.fiveStar:
        return source.where((item) => item.rating == 5).toList();
      case _ReviewFilter.fourStarUp:
        return source.where((item) => item.rating >= 4).toList();
      case _ReviewFilter.noReply:
        return source.where((item) => !item.hasReply).toList();
      case _ReviewFilter.lowRated:
        return source.where((item) => item.rating <= 2).toList();
    }
  }

  TextEditingController _controllerFor(StoreReview review) {
    final existing = _replyControllers[review.id];
    if (existing != null) {
      if (existing.text.trim().isEmpty && review.ownerReply.trim().isNotEmpty) {
        existing.text = review.ownerReply;
      }
      return existing;
    }

    final controller = TextEditingController(text: review.ownerReply);
    _replyControllers[review.id] = controller;
    return controller;
  }

  Future<void> _submitReply(StoreReview review) async {
    final controller = _replyControllers[review.id];
    if (controller == null) {
      return;
    }

    final reply = controller.text.trim();
    if (reply.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung phản hồi.')),
      );
      return;
    }

    setState(() {
      _savingReviewIds.add(review.id);
    });

    try {
      await context.read<StoreManagementService>().replyReview(
        reviewId: review.id,
        reply: reply,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi phản hồi cho đánh giá.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gửi phản hồi thất bại: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _savingReviewIds.remove(review.id);
        });
      }
    }
  }
}

enum _ReviewFilter { all, fiveStar, fourStarUp, noReply, lowRated }

class _ReviewsSummaryHeader extends StatelessWidget {
  const _ReviewsSummaryHeader({
    required this.averageRating,
    required this.totalReviews,
    required this.repliedCount,
    required this.replyRate,
  });

  final double averageRating;
  final int totalReviews;
  final int repliedCount;
  final double replyRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentLabel = (replyRate * 100).clamp(0, 100).toStringAsFixed(0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF15803D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact)
                Row(
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: List<Widget>.generate(5, (index) {
                        final filled = index < averageRating.round();
                        return Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 20,
                          color: Colors.white,
                        );
                      }),
                    ),
                    const Spacer(),
                    _ReviewCountBadge(totalReviews: totalReviews, theme: theme),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          averageRating.toStringAsFixed(1),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: List<Widget>.generate(5, (index) {
                              final filled = index < averageRating.round();
                              return Icon(
                                filled
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 20,
                                color: Colors.white,
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ReviewCountBadge(totalReviews: totalReviews, theme: theme),
                  ],
                ),
              const SizedBox(height: 10),
              Text(
                'Đã phản hồi $repliedCount/$totalReviews đánh giá ($percentLabel%)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: replyRate.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.26),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewCountBadge extends StatelessWidget {
  const _ReviewCountBadge({required this.totalReviews, required this.theme});

  final int totalReviews;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$totalReviews đánh giá',
        style: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewsFilterBar extends StatelessWidget {
  const _ReviewsFilterBar({
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final _ReviewFilter activeFilter;
  final ValueChanged<_ReviewFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = <(_ReviewFilter, String)>[
      (_ReviewFilter.all, 'Tất cả'),
      (_ReviewFilter.fiveStar, '5 sao'),
      (_ReviewFilter.fourStarUp, 'Từ 4 sao'),
      (_ReviewFilter.noReply, 'Chưa phản hồi'),
      (_ReviewFilter.lowRated, '1-2 sao'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = options[index];
          final selected = item.$1 == activeFilter;

          return ChoiceChip(
            label: Text(item.$2),
            selected: selected,
            onSelected: (_) => onFilterChanged(item.$1),
            side: BorderSide(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            labelStyle: TextStyle(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            selectedColor: theme.colorScheme.primaryContainer,
            backgroundColor: theme.colorScheme.surface,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}
