# Troubleshooting Playbook

## Table Of Contents

- Core model
- Symptom-to-suspect matrix
- Signaling failure patterns
- SDP and media patterns
- NAT and firewall patterns
- Codec and transcoding patterns
- DTMF patterns
- GoIP and GSM patterns
- FreePBX and Asterisk patterns
- Provider and carrier escalation patterns
- Verification checklists

## Core Model

Treat every incident as four overlapping paths:

1. signaling path
2. media path
3. configuration path
4. time path

The signaling path explains whether the session is negotiated.
The media path explains whether audio actually flows.
The configuration path explains why the device behaved that way.
The time path explains whether state, keepalive, or session timers caused a delayed failure.

Always capture the correlation keys before reading large artifacts:

- timestamp with timezone
- `Call-ID`
- Asterisk `uniqueid` if present
- endpoint, trunk, queue, or route name
- source and destination IP:port
- called number and caller ID after normalization

If the user supplies many logs, build a short incident timeline first.

## Symptom-To-Suspect Matrix

| Symptom | First suspects | Usually decisive evidence |
| --- | --- | --- |
| REGISTER loops on `401` or `407` | wrong auth username, wrong realm, digest mismatch, stale nonce handling | SIP ladder showing repeated challenge and resubmission |
| `403 Forbidden` on register or invite | ACL, IP auth mismatch, wrong credentials, provider account policy | provider response headers, trunk auth method, source IP |
| `404 Not Found` | wrong dialed format, wrong DID match, wrong context or route | route config, normalized number, inbound DID |
| `480` or `503` | far-end unreachable, registration missing, route exhaustion, provider fault | ladder plus endpoint or trunk state |
| `200 OK` but call drops quickly | missing `ACK`, session timer mismatch, RTP timeout | SIP ladder after answer plus RTP logs |
| Calls connect but no audio | codec incompatibility, blocked RTP, wrong media address | SDP plus RTP packet direction |
| One-way audio | NAT, direct media, firewall asymmetry, wrong `c=` address | capture proving one direction only |
| Audio works internally but fails externally | NAT, public address, port forwarding, ALG | transport settings plus external trace |
| DTMF fails only through one trunk or gateway | RFC2833 vs SIP INFO vs inband mismatch | gateway config plus SDP or trace |
| Intermittent registration | NAT pinhole timeout, qualify interval, provider rate limits, packet loss | timed incident log plus keepalive behavior |
| All calls lose audio after a change | `strictrtp`, RTP range, firewall policy, changed media address | global RTP config and packet capture |

## Signaling Failure Patterns

### REGISTER Authentication Loops

Common causes:

- wrong auth username while the displayed trunk name looks correct
- digest realm mismatch
- identify match by IP missing while auth is disabled
- provider expects IP auth but PBX is sending digest auth
- NAT rewrites the Contact in a way the provider rejects

Clues:

- repeated `401` or `407` with no final success
- Asterisk logs mentioning `Forbidden`, `No matching endpoint found`, or auth failure
- provider rejecting only from one source IP after a firewall or WAN change

### `403 Forbidden`

Do not reduce this to "bad password" automatically.
It can also mean:

- source IP not whitelisted
- caller ID or CLI policy violation
- digest accepted but account or route blocked
- provider requires a different transport or realm
- account registration state invalid upstream

### `404 Not Found`

Often caused by:

- DID normalization mismatch
- inbound route expecting the full DID while provider sends only the user part
- outbound route pattern miss
- incorrect context in `pjsip.conf` or `extensions.conf`
- trunk sequence selecting the wrong carrier

### `480 Temporarily Unavailable`

Interpret in context:

- called endpoint unregistered
- destination route valid but no device available
- provider far-end unreachable
- queue or ring group has no available members

### `488 Not Acceptable Here`

Usually points to interop or media negotiation:

- no common codec
- SRTP mismatch
- fmtp or ptime incompatibility
- fax or T.38 expectations not met

### Missing `ACK` After `200 OK`

This is a classic post-answer failure.
Expect symptoms like:

- caller hears ringing then call drops
- one side hears audio briefly then disconnects
- provider sends BYE after timer expiry

Check:

- whether the `200 OK` reaches the caller
- whether the `ACK` returns on the same signaling path
- Contact and Record-Route handling
- NAT between the answering side and the side sending `ACK`

### `BYE` Right After Answer

Determine who sent the `BYE` first.
That decides the investigation:

- caller or provider side: focus on missing `ACK`, session timers, fraud or policy
- PBX side: focus on dialplan hangup logic, RTP timeout, queue application, or codec failure
- phone or gateway side: focus on local timer, transport, media, or GSM leg release

### Re-INVITE, UPDATE, And Session Timers

If the call survives setup but fails later:

- inspect `Session-Expires`, `Min-SE`, and refresher role
- inspect re-INVITEs or UPDATEs that alter Contact or SDP
- inspect direct media attempts that move media off the PBX unexpectedly
- inspect NAT pinhole lifetime against timer cadence

## SDP And Media Patterns

### What To Parse First

Start with:

- `m=audio`
- `c=IN IP4`
- `a=rtpmap`
- `a=fmtp`
- `a=ptime`
- `a=sendrecv`

Then answer:

1. Which side offered which codecs?
2. Which codec won?
3. Does the selected codec actually exist on both sides?
4. Is transcoding required?
5. Is the `c=` media address reachable from the far end?
6. Did a later re-INVITE change the media address?

### Private IP Leakage

If you see private space in external call SDP, suspect NAT immediately:

- `10.0.0.0/8`
- `172.16.0.0/12`
- `192.168.0.0/16`

Examples:

```text
c=IN IP4 192.168.1.20
Contact: <sip:100@10.0.0.15:5060>
```

In a public-trunk scenario, these values usually indicate wrong external media or signaling settings, a bad SBC assumption, or direct media escaping to the wrong side.

### Hold And Resume

Not every strange SDP means a fault.
On hold, expect:

- `a=sendonly`
- `a=inactive`
- zeroed connection address in some implementations

Do not flag hold behavior as a failure unless it is unexpected for the scenario.

### Early Media

When the call shows `183 Session Progress`:

- determine whether audio is expected before answer
- ensure RTP policy permits it
- distinguish ringback generation from far-end announcements

## NAT And Firewall Patterns

### Core NAT Settings To Audit

For PJSIP, inspect concepts such as:

- `external_signaling_address`
- `external_media_address`
- `local_net`
- `rewrite_contact`
- `force_rport`
- `rtp_symmetric`
- `direct_media`

For legacy `chan_sip`, inspect equivalents such as:

- `externip` or `externaddr`
- `localnet`
- `nat`
- `canreinvite` or `directmedia`

### Media Anchoring Pitfalls

Common failure modes:

- PBX advertises a private `c=` address to a public carrier
- PBX receives RTP on a different source port and `strictrtp` rejects it
- direct media bypasses the PBX even though endpoints cannot reach each other
- firewall allows `5060` but blocks the RTP range
- provider sends to a stale public IP after WAN changes

### `strictrtp` And RTP Source Learning

If audio disappears globally after a config change, inspect:

- `strictrtp`
- `rtpchecksums`
- RTP port range
- recent RTP logs

`strictrtp` can be correct in stable topologies, but it can also reject legitimate media when source ports shift behind NAT or gateways behave asymmetrically.

### `bind=0.0.0.0` Nuances

Some deployments show correct external media settings but still leak a local interface in SDP because the chosen binding or routing decision does not match the intended egress path.

If you see:

- correct `external_media_address`
- but wrong local IP in actual SDP

check:

- transport bind behavior
- multi-homed server routing
- NAT traversal settings in FreePBX GUI vs generated config
- later re-INVITEs rewriting the path

### SIP ALG And Helpers

Suspect ALG when:

- headers are rewritten unexpectedly
- Contact or Via values mutate in flight
- registration is unstable only through one router
- the same PBX behaves correctly behind one firewall and incorrectly behind another

If ALG is suspected, disable it at the edge and retest before changing PBX logic.

### Firewall And Conntrack Clues

Look for:

- RTP in one direction only
- packet flow stops after 30-60 seconds
- registration renewals fail after idle time
- only remote workers behind a certain NAT type fail

Inspect:

- state timeouts
- helper modules
- asymmetric routes
- allowed RTP range

## Codec And Transcoding Patterns

### Common Codec Reality

Typical defaults:

- providers often expect `PCMA` or `PCMU`
- GoIP commonly supports `PCMA`, `PCMU`, and sometimes `G729`
- endpoints may prefer `OPUS` or `G722` internally

If the external side accepts only `G711` and the endpoint offers only `OPUS`, you either need transcoding or a codec policy change.

### When Codec Is Really The Problem

Treat codec as primary only when one or more of these are true:

- SDP shows no overlap
- the far side responds with `488`
- Asterisk logs show `No compatible codecs`
- the selected codec requires transcoding that is unavailable
- fmtp or packetization prevents interop

### When Codec Is Not The Primary Problem

Do not blame codec if:

- the `ACK` is missing
- RTP never starts
- only one direction of RTP is absent
- a firewall is clearly dropping the media flow

### G729 And Licensing Or Support

If `G729` is involved, verify:

- endpoint support
- gateway support
- PBX support
- provider allowance

Do not assume all legs can transcode it.

## DTMF Patterns

Check every leg for the same mode:

- RFC2833 or `telephone-event`
- SIP INFO
- inband

Common failure patterns:

- gateway sends RFC2833 but provider expects INFO
- inband digits lost by compressed codec
- SDP lacks the expected telephone-event mapping
- Asterisk and gateway both configured correctly, but the trunk rewrites or strips DTMF signaling

For GoIP, DTMF mismatches are common when the GSM leg, SIP leg, and PBX all have different assumptions.

## GoIP And GSM Patterns

### Registration And Trunking

Audit:

- SIP server and port
- auth user and password
- registration refresh
- codec list and order
- DTMF mode
- NAT or keepalive settings

### GSM Side Health

Audit:

- SIM registered or barred
- RSSI or signal quality
- module lock state
- roaming or carrier restrictions
- answer supervision and release timing

### GoIP Failure Signatures

| Symptom | Likely causes |
| --- | --- |
| Registers but no outbound call | dialed format, CLI policy, GSM registration, route choice |
| Audio missing after answer | NAT, wrong media IP, codec mismatch, RTP blocked |
| DTMF broken | mode mismatch or inband compression |
| Intermittent failures | unstable GSM signal, overloaded gateway, NAT keepalive |

When GoIP is involved, think in two networks at once:

- SIP side toward the PBX
- GSM side toward the cellular carrier

## FreePBX And Asterisk Patterns

### PJSIP Object Relationships

For PJSIP, remember the chain:

- transport
- endpoint
- AOR
- auth
- identify

If the call or registration hits the wrong endpoint, inspect `identify` matches and source IP expectations before changing codecs or dialplan.

### FreePBX Route Logic

Check:

- inbound route DID normalization
- trunk sequence order
- outbound route precedence
- prepend or prefix behavior
- extension or device registration state
- time conditions, business-hours routing, and announcement logic

Route mismatches often look like provider failure until the normalized number is compared with the actual route patterns.

### Channel And Application Clues

Pay attention to:

- queue applications
- Local channels
- call forwarding
- follow-me
- ring groups
- custom destinations

These can introduce re-INVITEs, extra dialplan branches, or hangup logic that hides the true failing hop.

## Provider And Carrier Escalation Patterns

Escalate to a carrier only after the PBX-side case is coherent.

A strong escalation package includes:

- exact timestamp with timezone
- source public IP
- destination IP or FQDN
- `Call-ID`
- called and calling numbers as sent on the wire
- failing response code
- short statement of what was already proven internally

Good escalation statement:

`At 2026-03-16 14:23:18 UTC, INVITE for DID X from PBX public IP Y reached your SBC Z and was rejected with 403. PBX auth, route choice, and dialed format were verified locally. Please confirm account policy or source IP authorization for this call.`

## Verification Checklists

### Registration

- final REGISTER receives `200 OK`
- trunk state stable across refreshes
- Contact reachable and not obviously rewritten wrong

### Call Setup

- INVITE ladder reaches `200 OK`
- `ACK` arrives on time
- no unexpected `CANCEL` or `BYE`

### Media

- negotiated codec matches expectation
- RTP present both directions
- source and destination ports stable enough for the topology

### NAT

- external and local network settings match real topology
- public calls do not expose unusable private media addresses
- direct media is disabled where endpoints cannot reach each other

### GoIP

- SIP side registered
- GSM side healthy
- DTMF works in both test directions
- selected codec is supported on every leg
