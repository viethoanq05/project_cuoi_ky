enum UserRole { customer, store, driver }

extension UserRoleDisplay on UserRole {
  String get key => name;

  String get label {
    switch (this) {
      case UserRole.customer:
        return 'Khach hang';
      case UserRole.store:
        return 'Cua hang';
      case UserRole.driver:
        return 'Tai xe';
    }
  }

  static UserRole fromKey(String? key) {
    switch (key?.trim().toLowerCase()) {
      case 'customer':
        return UserRole.customer;
      case 'store':
        return UserRole.store;
      case 'driver':
        return UserRole.driver;
      default:
        return UserRole.customer;
    }
  }

  static UserRole fromAny(dynamic value) {
    if (value is String) {
      return fromKey(value);
    }
    return UserRole.customer;
  }
}
