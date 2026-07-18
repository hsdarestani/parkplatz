import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../booking/data/repositories.dart';

class TrustOverview {
  const TrustOverview({
    required this.pendingVerifications,
    required this.openReports,
    required this.verifiedSpaces,
    required this.isAdmin,
    required this.supportEmail,
  });

  final int pendingVerifications;
  final int openReports;
  final int verifiedSpaces;
  final bool isAdmin;
  final String supportEmail;

  factory TrustOverview.fromJson(Map<String, dynamic> json) => TrustOverview(
        pendingVerifications: json['pending_verifications'] as int? ?? 0,
        openReports: json['open_reports'] as int? ?? 0,
        verifiedSpaces: json['verified_spaces'] as int? ?? 0,
        isAdmin: json['is_admin'] == true,
        supportEmail: json['support_email'] as String? ?? 'support@freiraum.app',
      );
}

class VerificationRecord {
  const VerificationRecord({
    required this.id,
    required this.parkingSpaceId,
    required this.statement,
    required this.status,
    required this.createdAt,
    this.reviewNote,
    this.userEmail,
    this.userName,
    this.parkingTitle,
    this.parkingAddress,
  });

  final String id;
  final String parkingSpaceId;
  final String statement;
  final String status;
  final DateTime createdAt;
  final String? reviewNote;
  final String? userEmail;
  final String? userName;
  final String? parkingTitle;
  final String? parkingAddress;

  factory VerificationRecord.fromJson(Map<String, dynamic> json) =>
      VerificationRecord(
        id: json['id'].toString(),
        parkingSpaceId: json['parking_space_id'].toString(),
        statement: json['statement'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        reviewNote: json['review_note'] as String?,
        userEmail: json['user_email'] as String?,
        userName: json['user_name'] as String?,
        parkingTitle: json['parking_title'] as String?,
        parkingAddress: json['parking_address'] as String?,
      );
}

class SafetyReportRecord {
  const SafetyReportRecord({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.parkingSpaceId,
    this.bookingId,
    this.resolutionNote,
    this.userEmail,
    this.userName,
  });

  final String id;
  final String category;
  final String description;
  final String status;
  final DateTime createdAt;
  final String? parkingSpaceId;
  final String? bookingId;
  final String? resolutionNote;
  final String? userEmail;
  final String? userName;

  factory SafetyReportRecord.fromJson(Map<String, dynamic> json) =>
      SafetyReportRecord(
        id: json['id'].toString(),
        category: json['category'] as String,
        description: json['description'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        parkingSpaceId: json['parking_space_id']?.toString(),
        bookingId: json['booking_id']?.toString(),
        resolutionNote: json['resolution_note'] as String?,
        userEmail: json['user_email'] as String?,
        userName: json['user_name'] as String?,
      );
}

class AdminTrustQueue {
  const AdminTrustQueue({
    required this.verifications,
    required this.reports,
  });

  final List<VerificationRecord> verifications;
  final List<SafetyReportRecord> reports;

  factory AdminTrustQueue.fromJson(Map<String, dynamic> json) => AdminTrustQueue(
        verifications: (json['verifications'] as List? ?? const [])
            .map(
              (value) => VerificationRecord.fromJson(
                value as Map<String, dynamic>,
              ),
            )
            .toList(),
        reports: (json['reports'] as List? ?? const [])
            .map(
              (value) => SafetyReportRecord.fromJson(
                value as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
}

class TrustRepository {
  const TrustRepository(this.api);

  final ApiClient api;

  Future<TrustOverview> overview() async => TrustOverview.fromJson(
        await api.get('/trust/overview') as Map<String, dynamic>,
      );

  Future<List<VerificationRecord>> verifications() async =>
      (await api.get('/trust/verifications') as List)
          .map(
            (value) => VerificationRecord.fromJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList();

  Future<VerificationRecord> submitVerification({
    required String parkingSpaceId,
    required String statement,
  }) async =>
      VerificationRecord.fromJson(
        await api.post(
          '/trust/verifications',
          body: {
            'parking_space_id': parkingSpaceId,
            'statement': statement,
          },
        ) as Map<String, dynamic>,
      );

  Future<List<SafetyReportRecord>> reports() async =>
      (await api.get('/trust/reports') as List)
          .map(
            (value) => SafetyReportRecord.fromJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList();

  Future<SafetyReportRecord> submitReport({
    String? parkingSpaceId,
    String? bookingId,
    required String category,
    required String description,
  }) async =>
      SafetyReportRecord.fromJson(
        await api.post(
          '/trust/reports',
          body: {
            if (parkingSpaceId != null && parkingSpaceId.isNotEmpty)
              'parking_space_id': parkingSpaceId,
            if (bookingId != null && bookingId.isNotEmpty)
              'booking_id': bookingId,
            'category': category,
            'description': description,
          },
        ) as Map<String, dynamic>,
      );

  Future<AdminTrustQueue> adminQueue() async => AdminTrustQueue.fromJson(
        await api.get('/admin/trust/queue') as Map<String, dynamic>,
      );

  Future<void> reviewVerification(
    String id, {
    required String status,
    String note = '',
  }) async {
    await api.patch(
      '/admin/trust/verifications/$id',
      body: {'status': status, 'note': note},
    );
  }

  Future<void> reviewReport(
    String id, {
    required String status,
    String note = '',
  }) async {
    await api.patch(
      '/admin/trust/reports/$id',
      body: {'status': status, 'note': note},
    );
  }
}

final trustRepositoryProvider = Provider<TrustRepository>(
  (ref) => TrustRepository(ref.watch(apiClientProvider)),
);
