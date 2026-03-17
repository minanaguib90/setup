# PBX Design Playbook

## Table Of Contents

- Discovery and sizing
- Platform selection
- Reference topologies
- Network and QoS
- Trunks, gateways, and numbering
- Dialplan, IVR, and queue design
- Security and operational controls
- High availability and recovery
- Deployment sequence
- Cutover and rollback
- Acceptance testing
- Design output template

## Discovery And Sizing

Start with the business, not the GUI.

Capture:

- total users
- expected simultaneous calls during busy hour
- number of sites
- remote worker count
- call center or queue requirements
- recording and compliance requirements
- business-hours routing and holiday logic
- expected growth
- branch survivability requirements
- preferred admin model and support team maturity

Translate the business inputs into telecom design constraints:

- concurrency drives SIP trunk sizing and SBC or firewall capacity
- site count drives WAN and NAT design
- queue load drives codec, recording, and storage strategy
- remote users drive TLS, VPN, SBC, or WebRTC decisions

## Platform Selection

Choose the platform based on control model, scale, and customization.

| Platform | Best fit | Strengths | Watch-outs |
| --- | --- | --- | --- |
| FreePBX | SMB and mid-market PBX where GUI administration matters | fast deployment, good module ecosystem, common admin skill set | generated config discipline, module sprawl, custom dialplan management |
| Raw Asterisk | Custom applications, carrier interop, advanced logic, edge signaling | maximum flexibility, deep protocol control | higher build and support effort |
| Yeastar | Appliance deployments with simple administration and known feature set | turnkey operations, lower admin burden | less freedom for deep custom logic or unusual carrier interop |
| GoIP | GSM breakout, SIM failover, least-cost routing edge use cases | simple GSM integration | codec, DTMF, registration, and radio quality constraints |

Selection heuristics:

- choose FreePBX when the team needs a fast, supportable GUI-backed PBX
- choose raw Asterisk when the differentiator is call logic or protocol behavior
- choose Yeastar when appliance simplicity is more valuable than deep customization
- use GoIP as an edge gateway, not as the design center of the PBX

## Reference Topologies

### Single-Site SMB

Recommended components:

- one PBX
- one primary SIP trunk
- one backup trunk or GSM path
- managed firewall
- voice VLAN
- optional SBC if the provider or edge requires it

### Multi-Site Enterprise

Recommended components:

- central PBX or clustered pair
- site-local survivability decision
- centralized or regional SIP trunks
- VPN or private WAN between sites
- voice VLANs per site
- centralized monitoring and backup

### PBX Plus GSM Breakout

Recommended components:

- PBX as the routing and policy brain
- GoIP only where GSM breakout or SIM-based failover is required
- explicit route logic for GSM usage
- call accounting that distinguishes SIP trunk vs GSM path

### High-Risk Carrier Edge

If the provider interop is strict or multi-carrier failover matters:

- add an SBC or carefully designed edge firewall policy
- keep the PBX behind a stable addressing layer
- anchor signaling and media policy in a predictable place

## Network And QoS

Voice quality depends on the network design as much as the PBX design.

Plan:

- voice VLANs
- QoS marking and trust boundaries
- WAN bandwidth reservation
- jitter and packet-loss tolerance
- separate management plane if appropriate

At minimum, document:

- where phones live
- where the PBX lives
- where gateways live
- where NAT is applied
- where public SIP trunks terminate

### NAT Strategy

State clearly:

- whether the PBX has a public address
- whether it sits behind static NAT
- whether remote users arrive through VPN, SBC, or direct Internet exposure
- whether media will anchor on the PBX or move end-to-end

Bad designs usually have an implicit NAT model instead of an explicit one.

### QoS

If QoS is in scope, specify:

- marking values
- which interfaces honor or rewrite them
- whether tunnels preserve markings
- how voice competes with bulk traffic

## Trunks, Gateways, And Numbering

### Trunk Strategy

Design for:

- primary carrier
- backup carrier
- failover route order
- emergency routing
- DID presentation and normalization
- authentication model: digest, IP auth, or both

For each trunk, define:

- transport
- codecs
- DTMF mode
- caller ID policy
- registration requirement
- failover behavior

### GoIP Placement

Use GoIP deliberately:

- route only the traffic that benefits from GSM breakout
- do not make GoIP the default for all traffic without cost and quality justification
- keep codec policy simple and compatible
- test DTMF and answer supervision early

### Numbering Plan

A good numbering plan is:

- memorable
- scalable
- route-friendly

Example shape:

- `100-199` office staff
- `200-299` support or queue agents
- `300-349` shared devices and rooms
- `400-499` service or test extensions

Also define:

- DID mapping
- short codes
- emergency dialing
- outbound caller ID rules

## Dialplan, IVR, And Queue Design

Design the user experience before touching configuration screens.

### IVR

Specify:

- entry points
- business-hours logic
- holiday logic
- fallback destinations
- timeout and invalid-selection behavior

### Queues

Specify:

- ring strategy
- agent membership
- overflow path
- announcement cadence
- voicemail policy
- recording policy

### Ring Groups And Hunt Logic

Specify:

- simultaneous vs sequential ringing
- no-answer behavior
- failover destinations

### Special Logic

Explicitly design:

- voicemail
- call recording
- paging
- conferences
- caller ID normalization
- per-department policies
- after-hours routing

If custom dialplan is needed, keep the boundary between GUI-managed and custom logic explicit.

## Security And Operational Controls

Security must be part of the initial design, not a patch.

Require:

- strong SIP secrets
- anonymous SIP disabled unless deliberately required
- endpoint and trunk ACLs where possible
- geo restrictions where appropriate
- Fail2Ban or equivalent protection
- limited management exposure
- documented admin roles

Where the environment supports it, consider:

- TLS for signaling
- SRTP for media
- VPN for remote phones
- SBC for Internet-facing deployments

Operational controls should include:

- backup schedule
- restore test cadence
- firmware and patch policy
- config change logging
- monitoring for registration state, disk, CPU, call quality, and trunk alarms

## High Availability And Recovery

Design availability based on business need, not wishful thinking.

Decide:

- whether a standby PBX is required
- whether carrier diversity is required
- whether branch survivability is required
- whether GSM failover is a real requirement or just a convenience

Recovery planning should include:

- full config backups
- recording storage protection
- restore procedures
- spare hardware or VM strategy
- rollback criteria for changes

### Minimum Resilience Pattern

For many environments, a practical minimum is:

- one primary PBX
- one backup trunk or GSM path
- automated backups
- tested restore process

### Higher Resilience Pattern

For stricter environments, add:

- secondary PBX or warm standby
- dual WAN or diverse carriers
- clearer failover automation
- formal incident response runbooks

## Deployment Sequence

Use a staged rollout instead of a one-shot cutover.

Recommended sequence:

1. prepare network, firewall, DNS, NTP, and certificates
2. deploy the PBX baseline
3. configure one test trunk
4. create test extensions and devices
5. validate inbound, outbound, hold, transfer, voicemail, and recording
6. build IVR, routes, queues, and business-hours logic
7. add backup trunks and failover
8. harden security controls
9. pilot with a small user set
10. cut over the remaining users

## Cutover And Rollback

A cutover plan should state:

- pre-cutover checklist
- exact change window
- carrier dependencies
- user communication plan
- rollback trigger
- rollback owner

Pre-cutover checklist:

- trunks registered or reachable
- numbers normalized correctly
- sample DIDs tested
- failover tested
- recordings and storage verified
- monitoring active

Rollback checklist:

- old trunk or PBX still intact
- route reversal steps documented
- config snapshots taken
- test numbers available to verify rollback

## Acceptance Testing

Never call the system done without a telecom-focused test plan.

Test at least:

- internal to internal calls
- inbound DID to extension
- inbound DID to IVR to queue
- outbound local and international formats if applicable
- hold and resume
- attended and blind transfer
- voicemail deposit and retrieval
- queue answer and overflow
- DTMF through trunks and gateways
- failover route behavior
- remote phone behavior if supported

For GoIP deployments, also test:

- GSM breakout call success
- GSM signal stability
- DTMF across the GSM path
- caller ID behavior

## Design Output Template

Use this structure when presenting a design:

1. assumptions and requirements
2. recommended platform and topology
3. trunk and numbering plan
4. IVR, queue, and route design
5. security and operations controls
6. HA and backup strategy
7. deployment sequence
8. cutover and rollback plan
9. acceptance test plan
10. open decisions and risks

Keep the design specific enough that an engineer could implement it without re-inventing the topology.
