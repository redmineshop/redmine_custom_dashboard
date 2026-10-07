# Changelog — Redmine Custom Dashboard

All notable changes to this plugin.

## [Unreleased]

### Changed

- Public CI checks out Redmine 7.0.1, installs this plugin, runs migrations, and runs the MiniTest suite on MySQL 8.0. Ruby syntax and the standalone period/label checks on Ruby 3.2 and 3.3 stay as a separate job.
- KPI and assignee counts include only issues the current user can see on that project. A private issue stays out of the totals when the viewer cannot open it.
- Community install is **GitHub-first** (`git clone https://github.com/redmineshop/redmine_custom_dashboard.git`). Email-funnel packages are no longer the documented download path.
- README: Last maintained date, screenshots, and untested compatibility cells. Install path is GitHub clone.
- In-progress KPI matches open statuses whose name is Redmine's default in-progress label (English `In Progress`, Vietnamese `Đang thực hiện`, plus `default_issue_status_in_progress` from installed locales), compared case-insensitively. A closed status with that name is not counted.
- Period query values outside `7`, `30`, and `90` still fall back to 30 days. Surrounding whitespace is ignored.
- Resolved and overdue counts use bound ActiveRecord predicates (no string SQL).

### Added

- Tests for open / resolved / overdue counts, 7 vs 30 day periods, permission and module denial, project isolation, drill-down links, and HTML escaping of assignee names.

### Notes

- Redmine 5.x and 6.x stay declared and untested. Playwright was not run again. Screenshot files were not regenerated.

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
