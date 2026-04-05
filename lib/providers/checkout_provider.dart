import 'package:flutter/foundation.dart';
import '../domain/entities/order_entity.dart';
import '../domain/repositories/order_repository_interface.dart';
import '../domain/repositories/user_repository_interface.dart';

enum CheckoutState { initial, processing, success, error }

class CheckoutProvider extends ChangeNotifier {
  final OrderRepositoryInterface _orderRepository;
  final UserRepositoryInterface _userRepository;

  CheckoutProvider({
    required OrderRepositoryInterface orderRepository,
    required UserRepositoryInterface userRepository,
  })  : _orderRepository = orderRepository,
        _userRepository = userRepository;

  CheckoutState _state = CheckoutState.initial;
  String _errorMessage = '';
  OrderEntity? _createdOrder;
  double _walletBalance = 0.0;
  bool _walletCheckPassed = false;
  String _paymentMethod = 'cod';
  double _processingProgress = 0.0;

  CheckoutState get state => _state;
  String get errorMessage => _errorMessage;
  OrderEntity? get createdOrder => _createdOrder;
  double get walletBalance => _walletBalance;
  String get paymentMethod => _paymentMethod;
  double get processingProgress => _processingProgress;

  bool get isProcessing => _state == CheckoutState.processing;
  bool get isSuccess => _state == CheckoutState.success;
  bool get isError => _state == CheckoutState.error;
  bool get walletCheckPassed => _walletCheckPassed;

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  Future<void> fetchWalletBalance(String userId) async {
    try {
      final profile = await _userRepository.getUserProfile(userId);
      _walletBalance = profile.walletBalance;
      _walletCheckPassed = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to fetch wallet balance: $e';
      _walletBalance = 0.0;
      notifyListeners();
    }
  }

  Future<bool> validateWalletBalance(String userId, double amount) async {
    try {
      final isValid = await _userRepository.validateWalletBalance(userId, amount);
      _walletCheckPassed = isValid;
      if (!isValid) {
        _errorMessage = 'Số dư ví không đủ';
      }
      notifyListeners();
      return isValid;
    } catch (e) {
      _errorMessage = 'Error validating wallet: $e';
      _walletCheckPassed = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> processCheckout({
    required String userId,
    required String storeId,
    required List<OrderItemEntity> items,
    required double totalPrice,
    required String paymentMethod,
    required String deliveryAddress,
    DateTime? scheduledTime,
  }) async {
    _state = CheckoutState.processing;
    _errorMessage = '';
    _paymentMethod = paymentMethod;
    notifyListeners();

    try {
      switch (paymentMethod) {
        case 'wallet':
          await _processWalletPayment(
            userId: userId,
            storeId: storeId,
            items: items,
            totalPrice: totalPrice,
            deliveryAddress: deliveryAddress,
            scheduledTime: scheduledTime,
          );
          break;

        case 'online':
          await _processOnlinePayment(
            userId: userId,
            storeId: storeId,
            items: items,
            totalPrice: totalPrice,
            deliveryAddress: deliveryAddress,
            scheduledTime: scheduledTime,
          );
          break;

        case 'cod':
        default:
          await _processCODPayment(
            userId: userId,
            storeId: storeId,
            items: items,
            totalPrice: totalPrice,
            deliveryAddress: deliveryAddress,
            scheduledTime: scheduledTime,
          );
          break;
      }

      _state = CheckoutState.success;
      _errorMessage = '';
    } catch (e) {
      _state = CheckoutState.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<void> _processCODPayment({
    required String userId,
    required String storeId,
    required List<OrderItemEntity> items,
    required double totalPrice,
    required String deliveryAddress,
    DateTime? scheduledTime,
  }) async {
    _createdOrder = await _orderRepository.createOrder(
      userId: userId,
      storeId: storeId,
      items: items,
      totalPrice: totalPrice,
      paymentMethod: 'cod',
      deliveryAddress: deliveryAddress,
      scheduledTime: scheduledTime,
    );
  }

  Future<void> _processWalletPayment({
    required String userId,
    required String storeId,
    required List<OrderItemEntity> items,
    required double totalPrice,
    required String deliveryAddress,
    DateTime? scheduledTime,
  }) async {
    final isValid =
        await _userRepository.validateWalletBalance(userId, totalPrice);
    if (!isValid) {
      throw Exception('Số dư ví không đủ');
    }

    _createdOrder = await _orderRepository.createOrder(
      userId: userId,
      storeId: storeId,
      items: items,
      totalPrice: totalPrice,
      paymentMethod: 'wallet',
      deliveryAddress: deliveryAddress,
      scheduledTime: scheduledTime,
    );
  }

  Future<void> _processOnlinePayment({
    required String userId,
    required String storeId,
    required List<OrderItemEntity> items,
    required double totalPrice,
    required String deliveryAddress,
    DateTime? scheduledTime,
  }) async {
    // Simulate payment processing with progress animation
    _processingProgress = 0.0;
    notifyListeners();

    // Simulate processing delay (2-3 seconds total)
    final steps = 5;
    final delayPerStep = Duration(milliseconds: 400 + DateTime.now().microsecond % 200);

    for (int i = 0; i < steps; i++) {
      await Future.delayed(delayPerStep);
      _processingProgress = (i + 1) / steps;
      notifyListeners();
    }

    // Simulate 95% success rate
    final isPaymentSuccessful = DateTime.now().millisecond % 100 > 4;

    if (!isPaymentSuccessful) {
      throw Exception('Giao dịch thất bại. Vui lòng thử lại');
    }

    _createdOrder = await _orderRepository.createOrder(
      userId: userId,
      storeId: storeId,
      items: items,
      totalPrice: totalPrice,
      paymentMethod: 'online',
      deliveryAddress: deliveryAddress,
      scheduledTime: scheduledTime,
    );

    _processingProgress = 1.0;
    notifyListeners();
  }

  void resetState() {
    _state = CheckoutState.initial;
    _errorMessage = '';
    _createdOrder = null;
    _walletCheckPassed = false;
    _processingProgress = 0.0;
    _paymentMethod = 'cod';
    notifyListeners();
  }
}
