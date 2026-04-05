import 'package:flutter/foundation.dart';
import '../domain/entities/order_entity.dart';
import '../domain/repositories/order_repository_interface.dart';

enum OrderTrackingState { initial, loading, loaded, error }

class OrderTrackingProvider extends ChangeNotifier {
  final OrderRepositoryInterface _orderRepository;

  OrderTrackingProvider({required OrderRepositoryInterface orderRepository})
    : _orderRepository = orderRepository;

  OrderTrackingState _state = OrderTrackingState.initial;
  OrderEntity? _order;
  String _errorMessage = '';
  String _currentOrderId = '';

  OrderTrackingState get state => _state;
  OrderEntity? get order => _order;
  String get errorMessage => _errorMessage;

  bool get isLoading => _state == OrderTrackingState.loading;
  bool get isError => _state == OrderTrackingState.error;
  bool get isLoaded => _state == OrderTrackingState.loaded;

  String get timelineStatus {
    if (_order == null) return '';
    switch (_order!.status) {
      case 'pending':
        return 'Waiting for confirmation';
      case 'confirmed':
      case 'preparing':
        return 'Store preparing';
      case 'delivering':
        return 'Driver delivering';
      case 'completed':
        return 'Done';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  bool get canCancel {
    return _order != null &&
        (_order!.status == 'pending' || _order!.status == 'confirmed');
  }

  void watchOrder(String orderId, String userId) {
    if (_currentOrderId == orderId) return;

    _currentOrderId = orderId;
    _state = OrderTrackingState.loading;
    notifyListeners();

    _orderRepository
        .watchOrderFromUser(orderId, userId)
        .listen(
          (order) {
            _order = order;
            if (order != null) {
              _state = OrderTrackingState.loaded;
              _errorMessage = '';
            } else {
              _state = OrderTrackingState.error;
              _errorMessage = 'Order not found';
            }
            notifyListeners();
          },
          onError: (e) {
            _state = OrderTrackingState.error;
            _errorMessage = e.toString();
            notifyListeners();
          },
        );
  }

  Future<void> cancelOrder() async {
    if (!canCancel) {
      _errorMessage = 'Order cannot be cancelled in current status';
      notifyListeners();
      return;
    }

    try {
      await _orderRepository.cancelOrder(_currentOrderId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _currentOrderId = '';
    super.dispose();
  }
}
