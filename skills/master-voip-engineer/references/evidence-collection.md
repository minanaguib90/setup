# Evidence Collection

## Table Of Contents

- Collection principles
- Minimum evidence bundles
- Asterisk and FreePBX commands
- SIP and RTP capture recipes
- Network and firewall state
- GoIP and gateway evidence
- Organizing large incidents
- Subagent workflows
- Bundled script usage
- Safety and production notes

## Collection Principles

Collect only what moves the case forward.
Avoid generic "send everything" requests when a tighter bundle can decide the issue.

Use this order:

1. identify the symptom and call direction
2. lock the timestamps and correlation keys
3. collect the smallest decisive artifacts
4. expand only if the first pass leaves material ambiguity

Always record:

- timezone
- server hostname
- affected number or extension
- trunk or endpoint name
- source and destination IP:port if known
- whether the failure is reproducible

If the environment is live and busy, prefer bounded captures and focused log windows.

## Minimum Evidence Bundles

### Registration Failure

Request:

- recent Asterisk CLI output
- `pjsip show registrations` or equivalent
- SIP ladder for REGISTER exchange
- relevant trunk or endpoint config
- NAT or transport settings if the PBX is not directly public

### Call Setup Failure

Request:

- SIP trace around the failing INVITE
- route or dialplan config
- endpoint or trunk registration status
- exact called number after normalization
- any relevant provider rejection headers

### Post-Answer Drop

Request:

- SIP ladder including `200 OK`, `ACK`, `BYE`, and timers
- RTP debug or packet capture if media stops first
- Asterisk full log for the same timestamp window

### One-Way Or No Audio

Request:

- SIP trace with full SDP
- RTP debug or `pcap`
- NAT or firewall summary
- transport and RTP settings
- whether direct media is enabled

### DTMF Failure

Request:

- endpoint, PBX, trunk, and gateway DTMF mode
- SIP trace proving `telephone-event` or SIP INFO
- codec in use during the test call

### GoIP Or GSM Failure

Request:

- GoIP SIP server settings
- codec and DTMF configuration
- GSM registration and signal state
- one successful and one failing test case if possible

## Asterisk And FreePBX Commands

Use the exact commands that fit the stack.

### Core Asterisk

```bash
asterisk -rvvvvv
core show channels
core show channels concise
core show uptime
```

### PJSIP

```bash
pjsip set logger on
pjsip show transports
pjsip show endpoints
pjsip show aors
pjsip show auths
pjsip show registrations
```

### Legacy `chan_sip`

```bash
sip set debug on
sip show peers
sip show registry
```

### RTP Debug

```bash
rtp set debug on
```

Turn it off after the controlled test so logs do not explode.

### FreePBX-Oriented Evidence

Collect the relevant parts of:

- trunk settings
- outbound route patterns and trunk order
- inbound route DID matches
- extension or device settings
- codec policy
- Asterisk SIP settings or NAT settings

Useful files often include:

- `/etc/asterisk/pjsip.conf`
- `/etc/asterisk/pjsip.endpoint*.conf`
- `/etc/asterisk/pjsip.transports*.conf`
- `/etc/asterisk/extensions.conf`
- `/etc/asterisk/extensions_additional.conf`
- `/etc/asterisk/extensions_custom.conf`
- `/etc/asterisk/rtp.conf`
- `/etc/asterisk/rtp_custom.conf`

If the system is FreePBX-managed, prefer the generated custom or additional files that reflect the live configuration.

## SIP And RTP Capture Recipes

### Broad SIP Plus RTP Capture

Bound the runtime whenever possible:

```bash
timeout 45s tcpdump -ni any -s 0 -w /tmp/voip-call.pcap 'udp port 5060 or portrange 10000-20000'
```

### Narrow To A Host

```bash
timeout 45s tcpdump -ni any -s 0 -w /tmp/voip-call.pcap 'host 198.51.100.20 and (udp port 5060 or portrange 10000-20000)'
```

### Narrow To TLS Or Alternate SIP Port

```bash
timeout 45s tcpdump -ni any -s 0 -w /tmp/voip-call.pcap 'host 198.51.100.20 and (tcp port 5061 or udp port 5060 or portrange 10000-20000)'
```

### Interactive SIP Inspection

If available:

```bash
sngrep
```

Use `sngrep` for rapid ladder inspection and `tcpdump` for durable evidence.

### RTP-Only Focus

```bash
timeout 30s tcpdump -ni any -s 0 -w /tmp/rtp-only.pcap 'portrange 10000-20000'
```

If the environment uses a different RTP range, adjust it before capture.

## Network And Firewall State

Collect network state close to the incident window.

### Interfaces And Routes

```bash
ip addr
ip route
ss -lunp
ss -tunp
```

### Firewall

Use what exists on the host:

```bash
ufw status verbose
iptables -S
nft list ruleset
firewall-cmd --list-all
```

Do not assume all of these are present.

### System Logs

```bash
journalctl -u asterisk --since '2026-03-16 14:20:00'
```

or, if using the full log:

```bash
tail -n 400 /var/log/asterisk/full
```

Prefer a bounded time slice when timestamps are known.

## GoIP And Gateway Evidence

When GoIP is involved, gather both SIP-side and GSM-side facts.

Request:

- gateway SIP server and registration state
- codec list and preferred order
- DTMF mode
- firmware version
- SIM registration state
- signal quality or RSSI
- failed and successful dial examples

If the GoIP UI is the only place holding the truth, ask the user for screenshots or config exports of the relevant pages.

## Organizing Large Incidents

For large artifact sets:

1. make a short case header
2. list all files and time ranges
3. isolate one failing call
4. extract the `Call-ID` and Asterisk identifiers
5. align all artifacts to the same window

A good case header looks like:

```text
Case: Outbound trunk failure to carrier A
Timezone: UTC
Window: 14:20:00-14:24:00
PBX: 203.0.113.10
Carrier SBC: 198.51.100.20
Endpoint: 101
Call-ID: abc123@example
```

If there are multiple failing calls, decide whether they share the same signature before treating them as one issue.

## Subagent Workflows

Use subagents when the workload naturally splits.

### Good Parallel Splits

- one subagent on SIP ladder reconstruction
- one subagent on RTP, NAT, and firewall behavior
- one subagent on FreePBX or Asterisk config and logs
- one subagent on GoIP or provider-specific behavior

### Return Contracts

Require each subagent to return:

- the exact artifacts reviewed
- the top findings only
- the most likely failing hop
- the next artifact needed if confidence is not high

### Example Subagent Prompt For Logs

```text
Use $master-voip-engineer at /home/sangoma/.cursor/skills/master-voip-engineer to review these Asterisk and FreePBX logs. Return the lines that best explain why the outbound route or endpoint failed, the most likely root cause, and one next check if uncertainty remains.
```

### Example Subagent Prompt For SIP

```text
Use $master-voip-engineer at /home/sangoma/.cursor/skills/master-voip-engineer to reconstruct this SIP trace by Call-ID. Return the failing hop, missing or abnormal messages, and whether the primary issue is signaling, SDP, or policy.
```

### Example Subagent Prompt For Trace Capture

```text
Use $master-voip-engineer at /home/sangoma/.cursor/skills/master-voip-engineer to plan a bounded SIP and RTP capture for this PBX. Return the exact commands, capture duration, output paths, and what success or failure would look like.
```

If subagent findings conflict, resolve them against timestamps and actual wire evidence.

## Bundled Script Usage

### `scripts/asterisk-voip-snapshot.sh`

Use when you need one snapshot directory containing:

- Asterisk version and status
- PJSIP objects
- RTP settings
- recent logs
- interface and routing state
- firewall summary if readable

Example:

```bash
./scripts/asterisk-voip-snapshot.sh --label carrier403 --output /tmp/voip-evidence
```

### `scripts/capture-sip-rtp-trace.sh`

Use when you want a bounded `pcap` instead of an open-ended capture.

Example:

```bash
./scripts/capture-sip-rtp-trace.sh --iface any --host 198.51.100.20 --duration 45 --output /tmp/carrier-a.pcap
```

### `scripts/call-timeline.sh`

Use when you have a `Call-ID`, endpoint name, trunk, number, or other anchor and want a quick call-centered log extract.

Example:

```bash
./scripts/call-timeline.sh --term 'abc123@example' --log /var/log/asterisk/full --context 6
```

## Safety And Production Notes

- prefer `timeout` or a fixed duration for live captures
- confirm available disk space before long `pcap` runs
- note that packet captures may contain sensitive signaling or media metadata
- disable verbose debugging after the test
- avoid changing unrelated security controls during evidence collection
- if root or `sudo` is needed, say so explicitly

## Escalation-Ready Evidence Pack

When escalating to an ISP, carrier, or upstream vendor, include:

- case header
- exact timestamps
- source and destination IPs
- affected numbers
- `Call-ID`
- decisive SIP messages
- concise summary of local checks already completed

Keep the escalation package short and reproducible.
