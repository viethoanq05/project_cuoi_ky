import 'package:flutter/foundation.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository_interface.dart';

enum OrderHistoryState { loading, loaded, error, empty }

class OrderHistoryProvider extends ChangeNotifier {
  final OrderRepositoryInterface _orderRepository;

  OrderHistoryProvider({required OrderRepositoryInterface orderRepository})
      : _orderRepository = orderRepository;

  OrderHistoryState _state = OrderHistoryState.loading;
  List<OrderEntity> _orders = [];
  String _errorMessage = '';

  OrderHistoryState get state => _state;
  List<OrderEntity> get orders => _orders;
  String get errorMessage => _errorMessage;

  bool get isLoading => _state == OrderHistoryState.loading;
  bool get isError => _state == OrderHistoryState.error;
  bool get isEmpty => _state == OrderHistoryState.empty;
  bool get isLoaded => _state == OrderHistoryState.loaded;

  Future<void> fetchUserOrders(String userId) async {
    _state = OrderHistoryState.loading;
    notifyListeners();

    try {
      _orders = await _orderRepository.getUserOrders(userId);

      if (_orders.isEmpty) {
        _state = OrderHistoryState.empty;
      } else {
        _state = OrderHistoryState.loaded;
      }
      _errorMessage = '';
    } catch (e) {
      _state = OrderHistoryState.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<void> refreshOrders(String userId) async {
    await fetchUserOrders(userId);
  }
}
