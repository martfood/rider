import 'bank_details.dart';

/// Represents a bank account update/linking request submitted by a partner (rider or vendor)
/// awaiting administrative review and approval.
class BankRequest {
  final String id;
  final String riderId;
  final String userType;
  final String riderName;
  final String riderEmail;
  final String riderPhone;
  final String businessName;
  final BankDetails? currentBank;
  final BankDetails requestedBank;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  const BankRequest({
    required this.id,
    required this.riderId,
    this.userType = 'rider',
    required this.riderName,
    required this.riderEmail,
    required this.riderPhone,
    this.businessName = 'Rider Partner',
    this.currentBank,
    required this.requestedBank,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory BankRequest.fromMap(String id, Map<String, dynamic> data) {
    BankDetails? parseBank(dynamic bankData) {
      if (bankData is Map<String, dynamic>) {
        return BankDetails(
          bankName: bankData['bankName'] ?? '',
          accountName: bankData['accountName'] ?? '',
          accountNumber: bankData['accountNumber'] ?? '',
          bankCode: bankData['bankCode'],
        );
      }
      return null;
    }

    DateTime parseDate(dynamic dateVal) {
      if (dateVal == null) return DateTime.now();
      if (dateVal is String) {
        return DateTime.tryParse(dateVal) ?? DateTime.now();
      }
      try {
        // Handle Firestore Timestamp if applicable
        return (dateVal as dynamic).toDate();
      } catch (_) {
        return DateTime.now();
      }
    }

    final reqBank = parseBank(data['requestedBank']) ??
        const BankDetails(
          bankName: '',
          accountName: '',
          accountNumber: '',
        );

    return BankRequest(
      id: id,
      riderId: (data['riderId'] ?? data['vendorId'] ?? '').toString(),
      userType: (data['userType'] ?? 'rider').toString(),
      riderName: (data['riderName'] ?? data['vendorName'] ?? 'Rider Partner').toString(),
      riderEmail: (data['riderEmail'] ?? data['vendorEmail'] ?? '').toString(),
      riderPhone: (data['riderPhone'] ?? data['vendorPhone'] ?? '').toString(),
      businessName: (data['businessName'] ?? 'Rider Partner').toString(),
      currentBank: parseBank(data['currentBank']),
      requestedBank: reqBank,
      status: (data['status'] ?? 'pending').toString(),
      createdAt: parseDate(data['createdAt']),
      reviewedAt: data['reviewedAt'] != null ? parseDate(data['reviewedAt']) : null,
      reviewedBy: data['reviewedBy']?.toString(),
      rejectionReason: data['rejectionReason']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'userType': userType,
      'riderName': riderName,
      'riderEmail': riderEmail,
      'riderPhone': riderPhone,
      'businessName': businessName,
      'currentBank': currentBank != null
          ? {
              'bankName': currentBank!.bankName,
              'accountName': currentBank!.accountName,
              'accountNumber': currentBank!.accountNumber,
              'bankCode': currentBank!.bankCode,
            }
          : null,
      'requestedBank': {
        'bankName': requestedBank.bankName,
        'accountName': requestedBank.accountName,
        'accountNumber': requestedBank.accountNumber,
        'bankCode': requestedBank.bankCode,
      },
      'status': status,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (reviewedAt != null) 'reviewedAt': reviewedAt!.toUtc().toIso8601String(),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
  }
}

