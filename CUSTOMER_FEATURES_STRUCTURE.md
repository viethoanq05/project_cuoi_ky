PROJECT FOLDER STRUCTURE
=======================

New files created for Customer Features:

lib/
  domain/
    entities/
      order_entity.dart
      review_entity.dart
      user_profile_entity.dart
    repositories/
      order_repository_interface.dart
      user_repository_interface.dart
      review_repository_interface.dart
  
  data/
    models/
      order_model.dart
      user_profile_model.dart
      review_model.dart
    datasources/
      firestore_datasource.dart
    repositories/
      order_repository.dart
      user_repository.dart
      review_repository.dart
  
  presentation/
    providers/
      cart_provider.dart
      checkout_provider.dart
      order_history_provider.dart
      order_tracking_provider.dart
      review_provider.dart
      user_profile_provider.dart
    screens/
      checkout_screen.dart
      order_history_screen.dart
      order_tracking_screen.dart
      review_order_screen.dart
      profile_screen.dart

DEPENDENCIES REQUIRED (already in project):
- cloud_firestore
- provider
- geolocator
- geocoding
- firebase_auth

ARCHITECTURE OVERVIEW
====================

Clean Architecture with 3 layers:

1. DOMAIN LAYER (Business Logic)
   - Entities: Pure business objects
   - Repositories: Abstract interfaces

2. DATA LAYER (External Data)
   - Models: Serializable objects with fromJson/toJson
   - Datasources: Firestore operations
   - Repositories: Implementation of interfaces

3. PRESENTATION LAYER (UI)
   - Providers: State management (ChangeNotifier)
   - Screens: UI implementation
   - No business logic in UI

KEY FEATURES IMPLEMENTED
=======================

1. PAYMENT (Checkout)
   - COD payment (immediate order creation)
   - Wallet payment (with transaction/balance validation)
   - Order total calculation with delivery fees
   - Error handling and retry capability

2. ORDER HISTORY
   - Real-time list of user orders
   - Sorted by created_at descending
   - Status badges
   - Empty/error states

3. ORDER TRACKING (REALTIME)
   - Real-time Firestore stream listening
   - Visual timeline of order status
   - Auto-update UI on status changes
   - Cancel order capability

4. REVIEW ORDER
   - Duplicate review prevention
   - 5-star rating system
   - Comment feedback
   - Only available after order completion
   - Load existing reviews

5. USER PROFILE MANAGEMENT
   - Display profile info
   - Edit name, phone, address
   - Get current location via Geolocator
   - Reverse geocoding for addresses
   - Wallet balance display
   - Input validation

STATE MANAGEMENT PATTERNS
========================

1. CartProvider
   - Manage cart items
   - Update quantities
   - Clear cart
   - Track store ID

2. CheckoutProvider
   - State: initial/processing/success/error
   - Wallet validation
   - Order creation
   - Error messages

3. OrderHistoryProvider
   - State: loading/loaded/error/empty
   - Fetch user orders
   - Real-time refresh

4. OrderTrackingProvider
   - Real-time order watching
   - Status to timeline conversion
   - Cancel order handling

5. ReviewProvider
   - Check if already reviewed
   - Submit review with validation
   - Prevent duplicates
   - Load existing review

6. UserProfileProvider
   - Load/watch user profile
   - Update profile
   - Input validation
   - Wallet balance access

DATA FLOW
=========

Order Creation:
Cart → CheckoutScreen → CheckoutProvider → OrderRepository → Firestore

Order Tracking:
OrderTrackingScreen → OrderTrackingProvider → Firestore (Stream)

Review:
ReviewOrderScreen → ReviewProvider → ReviewRepository → Firestore

Profile Update:
ProfileScreen → UserProfileProvider → UserRepository → Firestore

FIRESTORE COLLECTIONS SCHEMA
============================

users:
  {
    id: string
    name: string
    phone: string
    address: string
    wallet_balance: double
    lat: double
    lng: double
  }

orders:
  {
    id: string
    user_id: string
    store_id: string
    driver_id: string | null
    items: array[
      {
        food_id: string
        food_name: string
        quantity: int
        price: double
        subtotal: double
      }
    ]
    total_price: double
    status: string (pending|confirmed|preparing|delivering|completed|cancelled)
    payment_method: string (cod|wallet)
    delivery_address: string
    created_at: iso8601
    updated_at: iso8601
  }

reviews:
  {
    id: string
    order_id: string
    user_id: string
    store_id: string
    rating: int (1-5)
    comment: string
    created_at: iso8601
  }

ERROR HANDLING
==============

All Firebase calls wrapped in try/catch
Proper error messages displayed to users
Retry mechanisms for failed operations
Validation before operations
Transaction support for wallet operations

USAGE IN main.dart
==================

final firebaseDatasource = FirestoreDatasource();
final orderRepository = OrderRepository(datasource: firebaseDatasource);
final userRepository = UserRepository(datasource: firebaseDatasource);
final reviewRepository = ReviewRepository(datasource: firebaseDatasource);

MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => CartProvider()),
    ChangeNotifierProvider(
      create: (_) => CheckoutProvider(
        orderRepository: orderRepository,
        userRepository: userRepository,
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => OrderHistoryProvider(
        orderRepository: orderRepository,
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => OrderTrackingProvider(
        orderRepository: orderRepository,
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => ReviewProvider(
        reviewRepository: reviewRepository,
      ),
    ),
    ChangeNotifierProvider(
      create: (_) => UserProfileProvider(
        userRepository: userRepository,
      ),
    ),
  ],
  child: MyApp(),
)

Screens usage:
- CheckoutScreen(userId: userId)
- OrderHistoryScreen(userId: userId)
- OrderTrackingScreen(orderId: orderId, userId: userId)
- ReviewOrderScreen(orderId: orderId, storeId: storeId, userId: userId)
- ProfileScreen(userId: userId)
