import 'package:flutter/material.dart';

import '../../models/store_management_models.dart';
import '../../services/store_management_service.dart';
import '../../widgets/store_management/review_tile.dart';

class StoreReviewsTab extends StatefulWidget {
  const StoreReviewsTab({super.key, required this.service});

  final StoreManagementService service;

  @override
  State<StoreReviewsTab> createState() => _StoreReviewsTabState();
}

class _StoreReviewsTabState extends State<StoreReviewsTab> {
  final Map<String, TextEditingController> _replyControllers =
      <String, TextEditingController>{};
  final Set<String> _savingReviewIds = <String>{};

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

    return StreamBuilder<List<StoreReview>>(
      stream: widget.service.watchReviews(),
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

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final review = reviews[index];
            final controller = _controllerFor(review);

            return ReviewTile(
              review: review,
              replyController: controller,
              saving: _savingReviewIds.contains(review.id),
              onSubmitReply: () => _submitReply(review),
            );
          },
        );
      },
    );
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
      await widget.service.replyReview(reviewId: review.id, reply: reply);
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
