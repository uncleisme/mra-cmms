import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/work_orders_repository.dart';
import '../../repositories/leaves_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../models/work_order.dart';
import '../../models/leave.dart';
import '../../models/profile.dart';
import '../../models/activity_notification.dart';

final _workOrdersRepoProvider = Provider((ref) => WorkOrdersRepository());
final _leavesRepoProvider = Provider((ref) => LeavesRepository());
final _profilesRepoProvider = Provider((ref) => ProfilesRepository());
final _notificationsRepoProvider = Provider((ref) => NotificationsRepository());

final kpisProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.read(_workOrdersRepoProvider);
  return repo.getKpis();
});

final todaysOrdersProvider = FutureProvider<List<WorkOrder>>((ref) async {
  final repo = ref.read(_workOrdersRepoProvider);
  return repo.getTodaysAssigned();
});

// Work orders waiting for admin approval (status = 'Review')
final pendingReviewsProvider = FutureProvider<List<WorkOrder>>((ref) async {
  final repo = ref.read(_workOrdersRepoProvider);
  return repo.getPendingReviews(limit: 20);
});

final todaysLeavesProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  final repo = ref.read(_leavesRepoProvider);
  return repo.getTodaysLeaves();
});

/// Admin: pending leaves needing approval
final pendingLeavesForApprovalProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  final repo = ref.read(_leavesRepoProvider);
  return repo.getPendingForApproval(limit: 100);
});


final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final repo = ref.read(_profilesRepoProvider);
  return repo.getMyProfile();
});

// Recent notifications for current user (RLS-aware via repository)
final recentNotificationsProvider = FutureProvider<List<ActivityNotification>>((ref) async {
  final repo = ref.read(_notificationsRepoProvider);
  // Global feed so all users see the same recent updates
  return repo.getAll(limit: 20);
});

// Admin scope chart removed per request

// Per-user aggregation removed per request

// General notifications provider (family) to mirror leaves/orders provider style
final notificationsForCurrentUserProvider = FutureProvider.family<List<ActivityNotification>, int>((ref, limit) async {
  final repo = ref.read(_notificationsRepoProvider);
  return repo.getForCurrentUser(limit: limit);
});
