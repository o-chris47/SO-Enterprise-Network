# SO Enterprise Network | Cisco Packet Tracer

In this project, I designed and tested a Cisco Packet Tracer enterprise network demonstrating departmental network segmentation, inter VLAN routing, DHCP, access control lists, NAT overload, DNS, simulated web access, IP telephony, quality of service and access layer security.

> **Documentation scope:** I prepared this README using my device running configurations and Packet Tracer screenshots. I distinguish the results I verified from configuration observations that still require confirmation.

## Project overview

I built the network around **SO-R1** as the main site router, **ACC-SW1** as the access switch and **ISP-R2** as the ISP router. SO-R1 provides router on a stick inter VLAN routing, DHCP services, traffic filtering, NAT overload, Cisco telephony services and SSH management.

I verified the network using client addressing checks, ping tests, DNS lookup, browser access, NAT translation output, IP phone registration, port security output and switch QoS checks.

## Devices

| Device | Role |
|---|---|
| `SO-R1` | Main site router; inter VLAN routing, DHCP, ACLs, NAT, telephony and SSH management |
| `ACC-SW1` | Access switch; VLAN access ports, trunking, port security, BPDU Guard, QoS and SSH management |
| `ISP-R2` | ISP router; WAN addressing toward SO-R1 and the simulated DNS and web server network |
| End devices | Staff, finance, guest, management, printer and voice clients |
| Cisco 7960 phones | IP telephony endpoints |

## VLAN and IP addressing

All departmental networks use a `/27` subnet mask (`255.255.255.224`).

| VLAN | Function | Network | Default gateway | Addressing |
|---:|---|---|---|---|
| 10 | Staff | `192.168.10.0/27` | `192.168.10.1` | DHCP pool `staff` |
| 20 | Finance | `192.168.10.32/27` | `192.168.10.33` | DHCP pool `finance` |
| 30 | Printer | `192.168.10.64/27` | `192.168.10.65` | Static; printer at `192.168.10.66` |
| 40 | Guest | `192.168.10.96/27` | `192.168.10.97` | DHCP pool `guest` |
| 50 | Voice | `192.168.10.128/27` | `192.168.10.129` | DHCP pool `voice` |
| 99 | Management | `192.168.10.160/27` | `192.168.10.161` | DHCP pool `mgmt`; ACC-SW1 SVI `192.168.10.164` |
| 900 | Native VLAN | No IP address on router subinterface | — | Unused ports are parked here |

DHCP excluded addresses on SO-R1 are the six gateway addresses (`.1`, `.33`, `.65`, `.97`, `.129`, `.161`), `192.168.10.34`, `192.168.10.64`, the printer `192.168.10.66` and the ACC-SW1 management SVI `192.168.10.164`.

### WAN addressing

| Device | Interface | IPv4 address |
|---|---|---|
| SO-R1 | `G0/1` | `203.0.113.1/30` |
| ISP-R2 | `G0/0` | `203.0.113.2/30` |
| ISP-R2 | `G0/1` | `203.0.113.6/30` |

SO-R1 uses a default route via `203.0.113.2`. ISP-R2 has no static routes and only its two connected `/30` networks. Return traffic to the internal VLANs works because SO-R1 translates every internal source to `203.0.113.1`, which ISP-R2 reaches as a connected network. The simulated DNS and web server is `203.0.113.5`, and the DHCP pools hand it out as the DNS server.

## Implemented network features

### Inter VLAN routing

I implemented router on a stick on SO-R1. Its `GigabitEthernet0/0` interface has 802.1Q subinterfaces for VLANs 10, 20, 30, 40, 50 and 99, plus native VLAN 900 with no IP address. The `show ip route` output confirms all six departmental networks as directly connected and a static default route via `203.0.113.2`.

### DHCP

I configured DHCP pools on SO-R1 for staff, finance, guest, voice and management. The voice pool includes DHCP Option 150 pointing to `192.168.10.129`. VLAN 30 has no pool because the printer VLAN uses static addressing.

### Access control lists

I configured five filtering ACLs on SO-R1. A sixth, `nat-inside`, selects the NAT sources and is described in the NAT section:

| ACL | Applied | Behaviour |
|---|---|---|
| `guest-isolation` | `Gi0/0.40` inbound | Permits DHCP client traffic, denies guest access to the staff, finance, printer, voice and management subnets, permits other guest traffic |
| `voice-isolation` | `Gi0/0.50` inbound | Permits DHCP client traffic, denies voice access to the printer host `192.168.10.66` and to the finance subnet, permits other voice traffic |
| `finance-protection` | `Gi0/0.10` and `Gi0/0.99` inbound | For traffic entering from the staff and management VLANs, permits only TCP replies (ACK or RST flags) and ICMP echo replies to the finance subnet, denies other traffic to finance, permits everything else |
| `printer-access` | `Gi0/0.30` outbound | Permits staff and finance to the printer on TCP 9100, 631 and 515, permits management to the VLAN 30 subnet over TCP, denies other traffic to VLAN 30, permits everything else |
| `mgmt-ssh` | VTY lines on SO-R1 and ACC-SW1 | Standard ACL permitting only the management subnet `192.168.10.160/27` |

The `established` keyword in `finance-protection` checks TCP ACK or RST flags. It does not provide stateful firewall inspection. The finance subinterface itself has no ACL applied.

### NAT and PAT

I configured NAT overload on SO-R1 using `GigabitEthernet0/1`. The `nat-inside` standard ACL includes the six internal `/27` subnets. All six router subinterfaces are configured as NAT inside and `GigabitEthernet0/1` as NAT outside.

### IP telephony

I configured Cisco telephony service on SO-R1 with source address `192.168.10.129` on port `2000`. Two directory numbers are configured, extension `1001` and extension `1002`, and two Cisco 7960 phones are defined by MAC address. The voice DHCP pool supplies Option 150 pointing to the telephony service address.

### Access switching, port security and QoS

I assigned ACC-SW1 access ports as follows:

| Ports | VLAN | Notes |
|---|---|---|
| `Fa0/1` to `Fa0/10` | 10 (Staff) | Port security with sticky MAC learning |
| `Fa0/11`, `Fa0/12` | 20 (Finance) | Port security with sticky MAC learning |
| `Fa0/13`, `Fa0/14` | 99 (Management) | Port security with sticky MAC learning |
| `Fa0/15` to `Fa0/20` | 900 (unused) | Administratively shut down |
| `Fa0/21`, `Fa0/22` | 10 (Staff) with voice VLAN 50 | Phone ports; port security maximum 2; `mls qos trust cos` |
| `Fa0/23` | 30 (Printer) | Port security with sticky MAC learning |
| `Fa0/24` | 40 (Guest) | Guest Wi-Fi access point port; no port security by design |

All 24 FastEthernet access ports use PortFast and BPDU Guard. Port security uses the default violation mode, which is shutdown, with a maximum of one MAC address per port except on the phone ports. `GigabitEthernet0/1` is the trunk to SO-R1 with native VLAN 900 and allowed VLANs 10, 20, 30, 40, 50, 99 and 900. `GigabitEthernet0/2` is shut down. The switch runs rapid PVST.

I left port security off `Fa0/24` deliberately. A wireless access point presents many client MAC addresses, so a one address limit would cause repeated violations. Guest traffic is instead contained by the `guest-isolation` ACL on SO-R1.

### Device management

SO-R1 and ACC-SW1 use SSH version 2 only with the domain name `so.local`, a local `admin` account, `login local` on the console and VTY lines, a 5 minute exec timeout, an `enable secret`, password encryption for other passwords and the `mgmt-ssh` ACL on the VTY lines (lines 0 to 4 on SO-R1, lines 0 to 15 on ACC-SW1). ACC-SW1 has a management SVI (`Vlan99`, `192.168.10.164/27`) with default gateway `192.168.10.161`.

## Verification and troubleshooting evidence

The following table summarises the results I recorded in my Packet Tracer screenshots.

| Area | Evidence | Result | Screenshot |
|---|---|---|---|
| Routing | `show ip route` listed six connected `/27` networks and `S* 0.0.0.0/0 via 203.0.113.2` | Verified | [10-ip-route.png](screenshots/10-ip-route.png) |
| Staff DHCP | Staff PC13 showed `192.168.10.2/27`, gateway `192.168.10.1`, DNS `203.0.113.5` | Successful for captured client | [01-dhcp-assignment.png](screenshots/01-dhcp-assignment.png) |
| Finance DHCP | Finance PC6 received `192.168.10.35/27`, gateway `192.168.10.33`, DNS `203.0.113.5` | Successful for captured client | [08-dns-resolution-success.png](screenshots/08-dns-resolution-success.png) |
| Guest DHCP | A guest laptop received `192.168.10.98/27`, gateway `192.168.10.97` | Successful in later capture | [07-dns-sever-config-error.png](screenshots/07-dns-sever-config-error.png) |
| Management DHCP | A binding for `192.168.10.163` appeared in the DHCP table, matching the sticky MAC on `Fa0/13` | Lease observed | [05-dhcp-binding.png](screenshots/05-dhcp-binding.png) |
| Voice DHCP | Bindings showed `192.168.10.130` and `192.168.10.131` | Successful | [20-ip-phone-registration.png](screenshots/20-ip-phone-registration.png) |
| Phone registration | `show ephone` reported both phones registered with extensions 1001 and 1002 | Successful | [20-ip-phone-registration.png](screenshots/20-ip-phone-registration.png) |
| Voice ACL | Voice client reached `192.168.10.2`; tests to `192.168.10.66` and `192.168.10.35` were unreachable | Consistent with configured restrictions | [16-voice-isolation.png](screenshots/16-voice-isolation.png) |
| Guest ACL | Guest client reached gateway `192.168.10.97` and ISP address `203.0.113.2`; tests to `192.168.10.2`, `192.168.10.36` and `192.168.10.66` were unreachable | Consistent with guest isolation | [15-guest-isolation.png](screenshots/15-guest-isolation.png), [07-dns-unccessceful-ping.png](screenshots/07-dns-unccessceful-ping.png) |
| ACL counters | `show access-lists` showed matches on the guest deny and permit lines and on the voice permit line | ACLs processing traffic | [1-acl.png](screenshots/1-acl.png) |
| Printer ACL | `show run` excerpt listed the `printer-access` rules; no traffic test through it was captured | Configuration shown | [14-acl.png](screenshots/14-acl.png) |
| NAT/PAT | Later output showed six dynamic translations (DNS, HTTP and HTTPS from `192.168.10.2` to `203.0.113.5`) and 86 hits | Translation activity confirmed | [21-intitial-nat-stat.png](screenshots/21-intitial-nat-stat.png), [22-nat-translation.png](screenshots/22-nat-translation.png) |
| DNS | `nslookup www.office.com` received a response from `203.0.113.5` | Successful in Packet Tracer simulation | [08-dns-resolution-success.png](screenshots/08-dns-resolution-success.png) |
| HTTP | Staff browser displayed the Packet Tracer welcome page for `www.office.com` | Simulated web access confirmed | [09-http-connectivity.png](screenshots/09-http-connectivity.png) |
| Port security | `show port-security` listed ports `Fa0/1` to `Fa0/14`, `Fa0/21`, `Fa0/22` and `Fa0/23`, with maximum 2 on the phone ports | Verified | [13-port-security-recovery.png](screenshots/13-port-security-recovery.png) |
| Port security violation | `Fa0/22` entered secure-shutdown after MAC `0060.2F9E.9501` appeared in VLAN 50, with a violation count of 1; port restored after clearing | Violation behaviour demonstrated | [11-port-security-violation.png](screenshots/11-port-security-violation.png), [13-port-security-recovery.png](screenshots/13-port-security-recovery.png) |
| QoS | `show mls qos interface fa0/21` and `fa0/22` showed CoS trust enabled | Verified | [23-qos-cos-trust.png](screenshots/23-qos-cos-trust.png) |

### DNS and simulated web service note

The Packet Tracer DNS response mapped `www.office.com` to `203.0.113.5`. This is the result of the simulated environment and is not evidence of access to the real Microsoft website.

## Configuration observations for review

During my configuration review, I identified the following observations. I have not treated all of them as confirmed operational faults.

1. **Guest DNS difference:** One guest laptop capture shows DNS `1.1.1.1` and a failed lookup of `www.office.com`, while the guest DHCP pool specifies `203.0.113.5`. The screenshots do not establish whether the client held a stale or manually entered DNS value.
2. **Guest APIPA event:** One client received an APIPA address (`169.254.44.141/16`) before a separate guest client was shown with a valid lease. The exact cause and corrective action are not established by the available screenshots.
3. **Staff address difference:** Staff PC13 shows `192.168.10.2` in its `ipconfig` capture and in the NAT translations, while a later DHCP binding table lists its MAC address with `192.168.10.4`. This is consistent with a renewed lease, but the screenshots do not confirm it.
4. **Duplicate lease MAC:** The DHCP binding table lists MAC `0002.1657.B698` with both `192.168.10.3` and `192.168.10.132`. This is consistent with a test PC being moved between VLANs, which I have not confirmed.
5. **ISP-R2 routing:** ISP-R2 has no static route to the `192.168.10.0/24` networks. Connectivity works only because SO-R1 translates internal sources to `203.0.113.1`.
6. **ISP-R2 administration:** The VTY lines use `login` without a configured line password or local user, so remote administration is not usable and authentication has not been set up. The router also does not use `service password-encryption`.
7. **Finance ACL:** `finance-protection` uses stateless TCP flag filtering, not stateful inspection.
8. **Untested functions:** The supplied screenshots do not show the printer ACL permitting staff or finance to the printer, an SSH session through the `mgmt-ssh` ACL, or traffic through `Fa0/23` and `Fa0/24`.

## Useful verification commands

### SO-R1

```cisco
show ip interface brief
show ip route
show ip dhcp binding
show ip dhcp pool
show access-lists
show ip nat translations
show ip nat statistics
show ephone
```

### ACC-SW1

```cisco
show vlan brief
show interfaces trunk
show interfaces status err-disabled
show port-security
show port-security interface fa0/22
show spanning-tree
show mac address-table
show mls qos interface fa0/21
show mls qos interface fa0/22
```

### ISP-R2

```cisco
show ip interface brief
show ip route
```

### End devices

```text
ipconfig /all
ping <destination>
nslookup www.office.com
```

## Repository contents

```text
SO-Enterprise-Network/
├── .github/
│   └── workflows/
│       └── ci.yml
├── configs/
│   ├── ACC-SW1.txt
│   ├── ISP-R2.txt
│   └── SO-R1.txt
├── screenshots/
│   ├── 01-dhcp-assignment.png
│   ├── 05-dhcp-binding.png
│   ├── 07-dns-sever-config-error.png
│   ├── 07-dns-unccessceful-ping.png
│   ├── 08-dns-resolution-success.png
│   ├── 09-http-connectivity.png
│   ├── 10-ip-route.png
│   ├── 11-port-security-violation.png
│   ├── 13-port-security-recovery.png
│   ├── 14-acl.png
│   ├── 15-guest-isolation.png
│   ├── 16-voice-isolation.png
│   ├── 1-acl.png
│   ├── 20-ip-phone-registration.png
│   ├── 21-intitial-nat-stat.png
│   ├── 22-nat-translation.png
│   └── 23-qos-cos-trust.png
├── scripts/
│   └── check-repo.sh
├── .editorconfig
├── .gitattributes
├── .gitignore
├── .markdownlint.json
├── LICENSE
├── README.md
├── SO_Troubleshooting_Log.md
└── so-network.pkt
```

- [`so-network.pkt`](so-network.pkt) is the Cisco Packet Tracer project file. Open it in Packet Tracer to run the topology and repeat the tests.
- Device running configurations: [`SO-R1.txt`](configs/SO-R1.txt), [`ACC-SW1.txt`](configs/ACC-SW1.txt) and [`ISP-R2.txt`](configs/ISP-R2.txt). The `enable secret` and `username` password hashes are replaced with `<redacted>`.
- [`SO_Troubleshooting_Log.md`](SO_Troubleshooting_Log.md) records the symptoms, diagnostic commands, observed results and verified outcomes for each incident.
- [`screenshots/`](screenshots/) holds the Packet Tracer captures cited in the verification table above.
- [`scripts/check-repo.sh`](scripts/check-repo.sh) and the [CI workflow](.github/workflows/ci.yml) check that README links resolve, every screenshot is referenced and no password hashes appear in the configs.

## Conclusion

Through my testing, I demonstrated DHCP operation for the captured staff, finance, guest, management and voice clients; successful registration of two IP phones; NAT overload translation activity; DNS resolution and simulated HTTP access; CoS trust on both phone access ports; port security violation and recovery behaviour; and ACL behaviour consistent with the guest and voice restrictions I tested.

I prepared this README from the device configurations and Packet Tracer screenshots available for this project. My tests cover the functions listed above; I have not claimed that every device, VLAN, protocol or possible failure condition has been exhaustively tested.

## License

This project is released under the [MIT License](LICENSE).
