
❌ 2. Large Widgets Being Built All at Once

Your dashboard renders:

Full gradient header

Quick actions

Schedule / Approvals

Orders

Notifications / Charts

All in one synchronous build. If any of these has async ref.watch(...), Flutter may delay frame painting until it's all done.

✅ Fix: Split large sections into small widgets, like:
class DashboardHeader extends ConsumerWidget { ... }
class QuickActions extends StatelessWidget { ... }
class OrdersSection extends ConsumerWidget { ... }
class NotificationsSection extends ConsumerWidget { ... }


Each one can handle its own loading/errors, and Flutter can render faster and more incrementally.

❌ 3. Potentially Heavy JSON or UI Logic in build()

Example:

final withEff = <(WorkOrder, DateTime?)>[for (final wo in items) (wo, eff(wo))];
todayRelevant.sort((a, b) => a.$2!.compareTo(b.$2!));


This sorting and date logic (while not extreme) can slow the main isolate if the list is large.

✅ Fix: Move processing to a separate method or compute isolate if needed:
final todayRelevant = useMemoized(() => processOrders(items, now));


Or even use compute(...) if the list grows large.

✅ Quick Wins to Try First

✅ Move all ref.watch(...) calls into Consumer widgets near their usage.

✅ Break DashboardPage into smaller StatelessWidget or ConsumerWidget sections.

✅ Wrap sections in RepaintBoundary (you already do this in some places — good job).

✅ Avoid unnecessary sorting and filtering in the build() method if possible.