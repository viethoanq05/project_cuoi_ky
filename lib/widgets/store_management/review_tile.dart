import 'package:flutter/material.dart';

import '../../models/store_management_models.dart';

class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.review,
    required this.replyController,
    required this.saving,
    required this.onSubmitReply,
  });

  final StoreReview review;
  final TextEditingController replyController;
  final bool saving;
  final Future<void> Function() onSubmitReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initials(review.customerName);
    final dateLabel = _formatDateLabel(review.createdAt);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final ratingBadge = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFF15803D),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${review.rating}/5',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF15803D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            initials,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!compact) ratingBadge,
                      ],
                    ),
                    if (compact) ...[const SizedBox(height: 8), ratingBadge],
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: List<Widget>.generate(5, (index) {
                final filled = index < review.rating;
                return Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                    color: filled
                        ? const Color(0xFF22C55E)
                        : theme.colorScheme.outline,
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(review.content, style: theme.textTheme.bodyMedium),
            ),
            if (review.hasReply) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Phản hồi cửa hàng: ${review.ownerReply}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: replyController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Trả lời đánh giá',
                hintText: 'Nhập phản hồi của cửa hàng',
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: saving ? null : onSubmitReply,
                icon: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.reply_rounded),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                label: Text(saving ? 'Đang lưu...' : 'Gửi phản hồi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return 'KH';
    }

    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }

    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _formatDateLabel(DateTime? date) {
    if (date == null) {
      return 'Không rõ thời gian';
    }

    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} giờ trước';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}
