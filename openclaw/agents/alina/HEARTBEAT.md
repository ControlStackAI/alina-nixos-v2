# HEARTBEAT.md

## Always Do First: Context Save
- Review if there's unsaved work context from recent conversation
- Write summary to `memory/daily/YYYY-MM-DD.md` if needed

## Checks (rotate through, 2-4 per heartbeat)
Track state in `memory/state/heartbeat-state.json`.

### 📧 Email — Check both accounts for urgent unread (last 30 min)
### 📅 Calendar — Upcoming events in next 2 hours
### 🌤️ Weather — Once per 8 hours, only notify if significant
### 💻 System Health — Once per 4 hours, only notify if issues

## Rules
- **Quiet hours (23:00-08:00):** Only truly urgent items
- **Batch checks:** 2-3 per heartbeat, rotate through all
- **Don't repeat:** Don't re-notify about known items
- **Update state:** Always update heartbeat-state.json
