class TransactionModel {
  final String id;
  final String ownerId;
  final String? organizationId;
  final String? sourceId;
  final int amountCents;
  final String currency;
  final String direction; // INCOME, EXPENSE, TRANSFER_IN, TRANSFER_OUT, REFUND, LOAN_DISBURSEMENT
  final String category;
  final String? description;
  final String? merchantOrPayee;
  final String paymentMethod;
  final DateTime dateTime;
  final String entryOrigin;
  final String verificationStatus;
  final String createdById;
  final int version;

  TransactionModel({
    required this.id,
    required this.ownerId,
    this.organizationId,
    this.sourceId,
    required this.amountCents,
    this.currency = 'INR',
    required this.direction,
    required this.category,
    this.description,
    this.merchantOrPayee,
    required this.paymentMethod,
    required this.dateTime,
    required this.entryOrigin,
    required this.verificationStatus,
    required this.createdById,
    required this.version,
  });

  double get amount => amountCents / 100.0;

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      organizationId: json['organization_id'],
      sourceId: json['source_id'],
      amountCents: json['amount_cents'] ?? 0,
      currency: json['currency'] ?? 'INR',
      direction: json['direction'] ?? 'EXPENSE',
      category: json['category'] ?? 'Unclassified',
      description: json['description'],
      merchantOrPayee: json['merchant_or_payee'],
      paymentMethod: json['payment_method'] ?? 'OTHER',
      dateTime: DateTime.tryParse(json['date_time'] ?? '') ?? DateTime.now(),
      entryOrigin: json['entry_origin'] ?? 'MANUAL',
      verificationStatus: json['verification_status'] ?? 'CONFIRMED',
      createdById: json['created_by_id'] ?? '',
      version: json['version'] ?? 1,
    );
  }
}
