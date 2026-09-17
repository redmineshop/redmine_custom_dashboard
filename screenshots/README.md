# Screenshots — Redmine Custom Dashboard

Captured by the plugin quality harness (Playwright) against demo Redmine.

Refresh (RedmineShop monorepo, not this public plugin repo):

```bash
./demo/scripts/run-plugin-e2e.sh
```

Output:

- `admin-plugins.png` — Administration → Plugins row (no Configure link)
- `dashboard-overview.png` — project Dashboard tab with period filter, KPIs, assignee table
- `kpi-cards.png` — five live KPI cards
- `assignee-breakdown.png` — team throughput table including Unassigned
- `kpi-drilldown-overdue.png` — Overdue card opening the filtered issues list

This harness covers the project Dashboard UI. It is **one** demo Redmine image, not a 5.1 / 6.x matrix.
