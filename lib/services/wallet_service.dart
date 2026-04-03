class WalletService {
  static String? validateWithdrawal(double currentBalance, double withdrawAmount) {
    if (withdrawAmount <= 0) {
      return 'Số tiền rút phải lớn hơn 0đ';
    }
    if (withdrawAmount < 10000) {
      return 'Số tiền rút tối thiểu là 10.000đ';
    }
    if (withdrawAmount > currentBalance) {
      return 'Số dư ví không đủ để thực hiện giao dịch';
    }
    return null;
  }

  static String? validateDeposit(double depositAmount) {
    if (depositAmount <= 0) {
      return 'Số tiền nạp phải lớn hơn 0đ';
    }
    if (depositAmount < 10000) {
      return 'Số tiền nạp tối thiểu là 10.000đ';
    }
    return null;
  }

  static double calculateNewBalance(double currentBalance, double amount, bool isAddition) {
    if (isAddition) {
      return currentBalance + amount;
    } else {
      return currentBalance - amount;
    }
  }
}
