import 'package:equatable/equatable.dart';

/// Credit from completed deliveries or debit from payouts.
enum LedgerEntryKind { credit, debit }

/// One row in the rider earnings history (mock).
class LedgerEntry extends Equatable {
  /// Unique id for list keys.
  final String id;

  /// Credit or debit.
  final LedgerEntryKind kind;

  /// Short title shown in the list.
  final String title;

  /// Subtitle or reference.
  final String subtitle;

  /// ISO date string for display.
  final String dateLabel;

  /// Formatted amount (e.g. ₦12,500.00).
  final String amountLabel;

  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.dateLabel,
    required this.amountLabel,
  });

  @override
  List<Object?> get props =>
      [id, kind, title, subtitle, dateLabel, amountLabel];
}
