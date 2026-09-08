import 'package:equatable/equatable.dart';

/// Bank account details for withdrawals (mock persistence).
class BankDetails extends Equatable {
  /// Bank name.
  final String bankName;

  /// Account holder name.
  final String accountName;

  /// Account number.
  final String accountNumber;

  /// Bank code.
  final String? bankCode;

  const BankDetails({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.bankCode,
  });

  @override
  List<Object?> get props => [bankName, accountName, accountNumber, bankCode];
}
