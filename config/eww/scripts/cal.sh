#!/usr/bin/env bash
# Month grid for the dashboard calendar.
#   cal.sh [offset]   offset = months from the current one (0 = this month)
# Emits {title, weeks:[[{label,dim,today}, x7], ...]}
exec python3 - "${1:-0}" <<'PY'
import calendar, json, sys
from datetime import date

offset = int(sys.argv[1])
today = date.today()
m = today.month - 1 + offset
year, month = today.year + m // 12, m % 12 + 1

cal = calendar.Calendar(firstweekday=6)          # weeks start on Sunday
weeks = []
for week in cal.monthdatescalendar(year, month):
    weeks.append([{
        "label": str(d.day),
        "iso":   d.isoformat(),
        "dim":   d.month != month,
        "today": d == today,
    } for d in week])

print(json.dumps({
    "title": f"{calendar.month_name[month]} {year}",
    "weeks": weeks,
}))
PY
