# Changelog — Redmine Custom Dashboard

All notable changes to this plugin.

## [Unreleased]

### Changed

- Community install is **GitHub-first** (`git clone https://github.com/redmineshop/redmine_custom_dashboard.git`). Email-funnel packages are no longer the documented download path.
- README: Last maintained date, screenshots, and untested compatibility cells. Install path is GitHub clone.

### Added

- Plugin quality harness on the RedmineShop demo stack: Playwright E2E for the project Dashboard tab, KPI cards, period filter, and overdue drill-down, plus README screenshots.

### Notes

- Do not treat the harness as a Redmine 5.1 / 6.x matrix.

## [1.1.0] — 2026-07-18

UX polish and operational drill-down (Community).

### Added

- Clickable KPI cards linking to filtered issue lists
- Due soon (7 days) KPI
- Delta vs previous period / period start under each KPI
- Unassigned row in assignee breakdown
- Visible date range next to period selector (`from – to`)

### Fixed

- Project menu highlights Dashboard (`menu_item`)
- Period control touch target (≥ 44px)
- Period hint contrast (removed duplicate low-contrast “Last N days” in H2)
- Overdue KPI drill-down 404 — Redmine rejects `op[due_date]=<`; use `<=` with yesterday


## [1.0.0] — 2026-09-07

First community release via RedmineShop email funnel.

### Added

- Per-project Dashboard tab with live KPI cards (open / resolved in period / overdue / in progress)
- Period filter: last 7, 30, or 90 days (GET `period` param)
- Assignee throughput table from real issue assignments
- `view_custom_dashboard` role permission (`authorize` on controller)
- No DB schema — install is extract + restart + enable module
- English + Vietnamese locales
- Unit tests for `DashboardStats` and functional tests for controller (200 / 403 / period)

[1.1.0]: https://github.com/redmineshop/redmine_custom_dashboard/releases/tag/v1.1.0
[1.0.0]: https://github.com/redmineshop/redmine_custom_dashboard/releases/tag/v1.0.0
