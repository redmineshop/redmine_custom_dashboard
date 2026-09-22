# Screenshots — Redmine Custom Dashboard

Captured by Playwright against demo Redmine.

Refresh is **private-monorepo only** (`redmineshop/redmineshop` harness). A public clone of this plugin cannot run that job.

Output:

- `kpi-cards.png` — full project page: top menu, project tabs, five KPI cards (including Due soon), assignee table
- `dashboard-overview.png` and `assignee-breakdown.png` — same image as `kpi-cards.png` (older README paths)
- `kpi-drilldown.png` — filtered issue list after the Overdue card
- `kpi-drilldown-overdue.png` — same image as `kpi-drilldown.png`
- `admin-plugins.png` — Administration → Plugins page (no Configure link)
- `empty-state.png` — not captured this run (optional; the seeded project has issues)

This harness covers the project Dashboard UI. It is **one** demo Redmine image, not a 5.1 / 6.x matrix.
