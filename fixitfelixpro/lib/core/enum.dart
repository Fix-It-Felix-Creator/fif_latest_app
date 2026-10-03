enum AccountCategoryType { tradesman, business, customer }

enum VerificationStatus { waiting, verified, unverified, rejected }

enum SubscriptionPlan { none, free, plus, pro, business }

enum BillingCycle { monthly, annual, yearly }

enum BusinessRole { owner, admin, customerSupport }

enum DocumentType { passport, idCard, driverLicense }

enum SubscriptionStatus { active, expired, cancelled, trial, pending }

// `plus` is what the launch campaign now calls Pro. Both are accepted: the
// database constraint still allows plus so any historical row keeps
// validating, and every plan config now ships as pro.
enum PlanType { standard, pro, plus, advance, vip }

enum WorkStatus { available, busy, offline }

enum TradesmanDocumentType { invoice, quotation }

enum InvoiceStatus { draft, sent, paid, overdue, cancelled }

enum JobUrgency { low, normal, high, emergency }

enum CommissionType { percentage, fixed }

enum JobStatus {
  pending,
  matching,
  negotiating,
  accepted,
  inProgress,
  completed,
  pendingPayment,
  cancelled,
}

enum PaymentMethod { cash, card }

enum PaymentStatus { pending, confirmed, disputed }

enum ChatMessageType { text, invoice, quotation, image, document, video, scheduleRequest }

enum ScheduleRequestStatus { pending, accepted, rejected, expired }

enum ChatPhase { interest, questions, scheduling, confirmed, active }
