/// Translates between the `usage_counters` row shape (snake_case) and the
/// camelCase JSON `UserUsageModel.fromJson` already speaks.
///
/// Same approach as ProfileMapper: adapt at the boundary so the model and
/// every screen reading it stay untouched.
class UsageMapper {
  const UsageMapper._();

  /// Column name for each `UsageCountType` field name used by the RTDB
  /// version. Derived from `_getCountFieldName`, which is the authoritative
  /// list — `resetUsage()` omits three of them.
  static const Map<String, String> fieldToColumn = {
    'addressCount': 'address_count',
    'invoiceCount': 'invoice_count',
    'quotationCount': 'quotation_count',
    'templateCount': 'template_count',
    'serviceCount': 'service_count',
    'customerCount': 'customer_count',
    'jobCount': 'job_count',
    'jobApplicationsThisMonth': 'job_applications_this_month',
    'completedJobsCount': 'completed_jobs_count',
    'staffCount': 'staff_count',
    'branchCount': 'branch_count',
    'projectsThisMonth': 'projects_this_month',
    'photoUploadCount': 'photo_upload_count',
    'videoUploadCount': 'video_upload_count',
    'voiceSecondsUsedThisMonth': 'voice_seconds_used',
    'suggestionsUsedThisMonth': 'suggestions_used',
    'cancellationsThisMonth': 'cancellations_this_month',
    'tradesmanCancellationsThisMonth': 'tradesman_cancellations_this_month',
    'leadsViewedThisMonth': 'leads_viewed',
    'scheduledVisitsCount': 'scheduled_visits_count',
    'freelanceHiresThisMonth': 'freelance_hires_this_month',
  };

  /// Postgres row -> the JSON `UserUsageModel.fromJson` expects.
  ///
  /// `limits` is intentionally absent: it is not stored on the counters row,
  /// and the repository merges it in from the subscription config.
  static Map<String, dynamic> rowToModelJson(Map<String, dynamic>? row) {
    if (row == null) return const {};
    final out = <String, dynamic>{};
    fieldToColumn.forEach((field, column) {
      out[field] = (row[column] as num?)?.toInt() ?? 0;
    });
    return out;
  }

  /// camelCase model JSON -> a `usage_counters` row.
  ///
  /// Only the counter columns are emitted; `owner_id` is added by the caller
  /// and `period_start` / `reset_at` are managed by reset_usage().
  static Map<String, dynamic> modelJsonToRow(Map<String, dynamic> json) {
    final row = <String, dynamic>{};
    fieldToColumn.forEach((field, column) {
      if (json.containsKey(field)) {
        row[column] = (json[field] as num?)?.toInt() ?? 0;
      }
    });
    return row;
  }

  /// Column for one RTDB field name, or null when it has no counter column.
  static String? columnFor(String fieldName) => fieldToColumn[fieldName];
}
