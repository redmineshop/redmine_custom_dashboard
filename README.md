# Redmine Custom Dashboard

**Free, open source. Download the official package at [redmineshop.com/products/redmine-custom-dashboard](https://redmineshop.com/products/redmine-custom-dashboard).**

Employee performance dashboard for Redmine — KPI cards and assignee throughput per project, with a date-range filter. Built for team leads who need a quick view without exporting spreadsheets.

## Features

- Per-project **Dashboard** tab (enable the module on each project)
- KPI cards from live issue data: open / resolved (period) / overdue / in progress / due soon (7d)
- Click a KPI to open the matching filtered issues list
- Delta vs previous period (resolved) or period start (stock KPIs)
- Period filter: last 7, 30, or 90 days + visible date range
- Assignee breakdown with **Unassigned** row when relevant
- Permission: `view_custom_dashboard`
- Redmine 5.0.x, 5.1.x, and 6.x
- No database tables — no plugin migration required
- English + Vietnamese UI strings

## Compatibility

| Redmine | Ruby | Database | Status |
|---------|------|----------|--------|
| 6.x     | 3.2+ | MySQL 8 / PostgreSQL | Primary QA |
| 5.1.x   | 3.1+ | MySQL 8 / PostgreSQL | Targeted |
| 5.0.x   | 3.0+ | MySQL 8 / PostgreSQL | Targeted |

## Installation

**Estimated time: 5–10 minutes.**

### 1. Download

Get the official package (SHA256 checksum included) at:
**[redmineshop.com/products/redmine-custom-dashboard](https://redmineshop.com/products/redmine-custom-dashboard)**

### 2. Extract

```bash
cd plugins
tar -xzf redmine_custom_dashboard-1.0.0.tar.gz
```

### 3. Restart Redmine

This plugin does not add database tables. Restart is enough:

```bash
# systemd example
sudo systemctl restart redmine
```

### 4. Enable module and permission

1. **Administration → Roles and permissions** — grant **View custom dashboard**
2. Per project: **Settings → Modules → Custom Dashboard**

## Uninstall

Remove the plugin folder and restart Redmine. No `plugins:migrate VERSION=0` step is required.

## Demo seed (RedmineShop demo stack)

```bash
docker cp demo/scripts/seed-custom-dashboard-demo.rb \
  redmineshop_demo_redmine:/tmp/seed-custom-dashboard-demo.rb
docker exec -e RAILS_ENV=development redmineshop_demo_redmine \
  bundle exec rails runner /tmp/seed-custom-dashboard-demo.rb
```

## Tests

```bash
bundle exec rake redmine:plugins:test NAME=redmine_custom_dashboard RAILS_ENV=test
# or (depending on Redmine version):
bundle exec rake test:plugins PLUGIN=redmine_custom_dashboard RAILS_ENV=test
```

## Community support

- [Open an issue on GitHub](https://github.com/redmineshop/redmine_custom_dashboard/issues)
- [Product page](https://redmineshop.com/products/redmine-custom-dashboard)

## License

MIT License. See [LICENSE](LICENSE).
