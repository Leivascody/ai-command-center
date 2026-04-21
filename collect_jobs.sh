#!/bin/bash
# Collect local scheduled jobs into jobs.json for the dashboard
# Run: bash collect_jobs.sh > jobs.json
# Or set up a cron to auto-update: */5 * * * * cd ~/ollama-dashboard && bash collect_jobs.sh > jobs.json

OUTPUT="["
FIRST=true

# ── Cron jobs ──
while IFS= read -r line; do
  [[ "$line" =~ ^# ]] && continue
  [[ -z "$line" ]] && continue

  # Parse cron schedule
  SCHED=$(echo "$line" | awk '{print $1,$2,$3,$4,$5}')
  CMD=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

  # Try to get a friendly name
  NAME="Cron: $CMD"
  if echo "$CMD" | grep -q "triage"; then NAME="Email Triage"; fi
  if echo "$CMD" | grep -q "briefing"; then NAME="Morning Briefing"; fi
  if echo "$CMD" | grep -q "backup"; then NAME="Backup"; fi
  if echo "$CMD" | grep -q "collect_jobs"; then NAME="Dashboard Refresh"; fi

  # Truncate command for display
  CMD_SHORT=$(echo "$CMD" | head -c 120)

  if [ "$FIRST" = true ]; then FIRST=false; else OUTPUT="$OUTPUT,"; fi
  OUTPUT="$OUTPUT{\"type\":\"cron\",\"name\":\"$NAME\",\"schedule\":\"$SCHED\",\"command\":\"$CMD_SHORT\",\"status\":\"active\"}"

done < <(crontab -l 2>/dev/null)

# ── LaunchAgents ──
for plist in ~/Library/LaunchAgents/*.plist; do
  [ -f "$plist" ] || continue

  LABEL=$(/usr/libexec/PlistBuddy -c "Print :Label" "$plist" 2>/dev/null || echo "unknown")
  PROGRAM=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "$plist" 2>/dev/null || echo "")
  KEEPALIVE=$(/usr/libexec/PlistBuddy -c "Print :KeepAlive" "$plist" 2>/dev/null || echo "false")
  RUNATLOAD=$(/usr/libexec/PlistBuddy -c "Print :RunAtLoad" "$plist" 2>/dev/null || echo "false")

  # Check if loaded
  STATUS="inactive"
  if launchctl list 2>/dev/null | grep -q "$LABEL"; then
    STATUS="active"
  fi

  # Friendly name
  NAME="$LABEL"
  if echo "$LABEL" | grep -qi "ollama"; then NAME="Ollama Server"; fi

  if [ "$FIRST" = true ]; then FIRST=false; else OUTPUT="$OUTPUT,"; fi
  OUTPUT="$OUTPUT{\"type\":\"launchagent\",\"name\":\"$NAME\",\"label\":\"$LABEL\",\"program\":\"$PROGRAM\",\"keepAlive\":$KEEPALIVE,\"runAtLoad\":$RUNATLOAD,\"status\":\"$STATUS\",\"plist\":\"$(basename "$plist")\"}"

done

# ── Ollama status ──
OLLAMA_STATUS="offline"
OLLAMA_MODELS=""
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
  OLLAMA_STATUS="online"
  OLLAMA_MODELS=$(curl -s http://localhost:11434/api/tags | python3 -c "import sys,json; models=json.load(sys.stdin).get('models',[]); print(','.join(m['name'] for m in models))" 2>/dev/null)
fi

if [ "$FIRST" = true ]; then FIRST=false; else OUTPUT="$OUTPUT,"; fi
OUTPUT="$OUTPUT{\"type\":\"service\",\"name\":\"Ollama\",\"status\":\"$OLLAMA_STATUS\",\"models\":\"$OLLAMA_MODELS\",\"url\":\"http://localhost:11434\"}"

# ── System info ──
UPTIME=$(uptime | sed 's/.*up //' | sed 's/,.*//')
LOAD=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')
MEM_USED=$(vm_stat 2>/dev/null | awk '/Pages active/ {print $3}' | tr -d '.')
MEM_TOTAL=$(sysctl -n hw.memsize 2>/dev/null)

if [ "$FIRST" = true ]; then FIRST=false; else OUTPUT="$OUTPUT,"; fi
OUTPUT="$OUTPUT{\"type\":\"system\",\"uptime\":\"$UPTIME\",\"loadAvg\":\"$LOAD\",\"memTotal\":\"$MEM_TOTAL\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"

OUTPUT="$OUTPUT]"
echo "$OUTPUT"
