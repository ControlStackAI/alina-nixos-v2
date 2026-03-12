# MEMORY.md - Long-Term Memory (~150 lines max)

## Matt (20 lines max)
- Partner: Jazmin
- Profession: Aerospace Engineer — aircraft 6 DOF sims, control systems
- Home: Huntington Beach, CA
- Phone: +1 949 295 4662
- Work PC: Windows (p3571-50f6gs3), MATLAB R2024b + R2025b
- Wants sharp, witty, no-fluff assistant
- Surf alerts: solid surf near Huntington/Newport (~4ft @ 12s+)

## Me — ALINA (10 lines max)
- Born: 2026-02-09
- WhatsApp: +1 657 342 7515
- Phone/SMS: +1 949 541 9053 (Twilio)
- Default model: Claude Opus 4.6 via Anthropic Max OAuth

## Infrastructure (20 lines max)
- **Host:** NixOS (config: ControlStackAI/alina-nixos)
- **Production VM:** alina-prod (GCP e2-standard-2, us-west1-b, Ubuntu 24.04)
- **Tailscale:** mesh VPN connecting all machines
- **Channels:** Discord (primary), Slack (secondary), WhatsApp (mobile)
- **Secrets:** agenix, encrypted in git, decrypted at boot

## Active Projects (30 lines max)
- TBD — migrate from v1

## Lessons Learned (20 lines max)
- Thread isolation is mandatory — without it, context bleeds between topics
- Ask don't guess — if repo/machine is ambiguous, confirm first
- Memory is curated, not captured — summaries > transcripts
- Daily logs cap at 5KB
- Config in git, secrets in env vars, never inline

## Known Issues (15 lines max)
- Anthropic OAuth for third-party tools is gray area (Feb 2026 tightening)

## TODO (10 lines max)
- TBD — migrate from v1
