# SO Enterprise Network Project: Troubleshooting Log

## 1. Purpose

I created this log to document the network problems I encountered while configuring and testing my SO enterprise network in Cisco Packet Tracer. For each incident, I recorded the observed problem, the troubleshooting action, the correction applied and the result after the correction.

The entries below are based on the troubleshooting details I provided and the device configurations and screenshots available for this project. Where the exact triggering event or command sequence was not recorded, I have identified that limitation rather than assuming details.

## 2. Incident Summary

| ID | Issue | Cause identified during troubleshooting | Corrective action | Outcome |
|---|---|---|---|---|
| SO-01 | Port security violation | A connected device triggered the switch port security policy | Checked the affected port and its learned or configured MAC address, then corrected the port security condition | Port security issue resolved |
| SO-02 | BPDU Guard violation | A BPDU was received on a port protected by BPDU Guard | Checked the affected connection and restored the port after addressing the BPDU condition | BPDU Guard issue resolved |
| SO-03 | DNS names did not resolve | Clients were configured to use DNS `1.1.1.1` instead of the DNS server in the project network | Changed the DNS setting to `203.0.113.5` | DNS name resolution worked |
| SO-04 | Staff and guest clients did not obtain DHCP addresses | DHCP traffic was not being permitted by the relevant access control policy | Added a DHCP permission for client and server UDP ports | Staff and guest DHCP allocation worked |
| SO-05 | IP phones did not obtain the required telephony configuration | DHCP Option 150 was missing from the voice DHCP pool | Added Option 150 pointing to `192.168.10.129` | Phones obtained voice network addresses and registered |

## 3. Detailed Troubleshooting Records

### SO-01: Port Security Violation

**Problem observed**

I encountered a port security violation on an access switch port. Port security was enabled on the access switch to restrict which MAC addresses could use protected access ports.

**Configuration context**

The supplied ACC SW1 configuration uses sticky MAC learning on many access ports. For example:

```cisco
interface FastEthernet0/1
 switchport access vlan 10
 switchport mode access
 switchport port-security
 switchport port-security mac-address sticky
 spanning-tree portfast
 spanning-tree bpduguard enable
```

Sticky learning allows the switch to learn a connected device MAC address and retain it in the port security configuration.

**Troubleshooting approach**

I checked the affected switch interface and its port security state to identify the violation and determine whether the connected device MAC address matched the address permitted by the port security configuration.

Useful verification commands:

```cisco
show port-security
show port-security interface FastEthernet0/1
show port-security address
show interfaces status
show running-config interface FastEthernet0/1
```

**Correction**

I addressed the port security condition on the affected interface and restored the port for the authorised device. The exact interface, violation mode and corrective commands were not included in the evidence supplied, so I have not attributed a specific MAC address or recovery command to this incident.

**Outcome**

The port security violation was resolved and the port could be used again as intended.

**Lesson learned**

Port security must reflect the devices expected to connect to each access port. When a device is replaced or moved, the learned sticky MAC address may need to be reviewed and updated through the appropriate port security procedure.

---

### SO-02: BPDU Guard Violation

**Problem observed**

I encountered a BPDU Guard violation on an access switch port.

**Configuration context**

ACC SW1 enables PortFast and BPDU Guard on access ports. For example:

```cisco
interface FastEthernet0/1
 spanning-tree portfast
 spanning-tree bpduguard enable
```

PortFast allows an access port to move rapidly to the forwarding state. BPDU Guard protects such edge ports by placing a port into an error disabled state if it receives a spanning tree BPDU.

**Troubleshooting approach**

I checked the interface state and spanning tree information to identify the affected port and investigate the connection.

Useful verification commands:

```cisco
show interfaces status
show spanning-tree
show spanning-tree inconsistentports
show logging
```

**Correction**

I checked the connection responsible for the BPDU condition and restored the affected access port after addressing that condition. The supplied evidence does not identify the exact device or connection that sent the BPDU, the affected interface, or the precise recovery commands used.

**Outcome**

The BPDU Guard violation was resolved and the affected port was restored to service.

**Lesson learned**

BPDU Guard is a protective mechanism, not simply a connectivity setting. I should not disable it just to bring a port online. I must first check why a BPDU reached an edge port and remove any unintended switch connection or Layer 2 loop before restoring the port.

---

### SO-03: DNS Name Resolution Failure

**Problem observed**

I found that DNS names were not resolving on client devices.

**Cause identified**

The clients were using `1.1.1.1` as their DNS server. This was not the DNS server configured for the project network. The DHCP pools on SO R1 specify `203.0.113.5`.

**Troubleshooting**

I checked the client DNS configuration and compared it with the DNS server address specified in the router DHCP pools.

The relevant DHCP configuration is:

```cisco
ip dhcp pool staff
 network 192.168.10.0 255.255.255.224
 default-router 192.168.10.1
 dns-server 203.0.113.5

ip dhcp pool finance
 network 192.168.10.32 255.255.255.224
 default-router 192.168.10.33
 dns-server 203.0.113.5

ip dhcp pool guest
 network 192.168.10.96 255.255.255.224
 default-router 192.168.10.97
 dns-server 203.0.113.5
```

**Correction**

I changed the client DNS setting from:

```text
1.1.1.1
```

to:

```text
203.0.113.5
```

**Verification**

I tested name resolution using:

```text
nslookup www.office.com
```

The later test returned a DNS response from `203.0.113.5`.

The Packet Tracer simulation returned `203.0.113.5` as the address for `www.office.com`. This confirms the simulated DNS response; it does not represent the real public address of that website.

**Outcome**

DNS name resolution worked after I changed the DNS server setting to `203.0.113.5`.

**Lesson learned**

Clients must use the DNS server address provided for the simulated network. A DNS server address that is valid in another environment does not necessarily provide name resolution in this Packet Tracer topology.

---

### SO-04: Staff and Guest Clients Not Receiving DHCP Addresses

**Problem observed**

Staff and guest clients were not obtaining IPv4 addresses through DHCP.

**Cause identified during troubleshooting**

DHCP traffic was being blocked by the relevant access control policy. DHCP clients initially use UDP source port 68, known as `bootpc`, and destination port 67, known as `bootps`. The DHCP server response uses the reverse direction.

**Correction**

I added a DHCP permit statement to allow the client DHCP request and server DHCP response traffic through the relevant ACL:

```cisco
permit udp any eq bootpc any eq bootps
```

The supplied SO R1 configuration contains this form of DHCP permission in the guest and voice ACLs.

**Technical note**

The protocol for DHCP is UDP. The correct Cisco ACL syntax for the client to server direction is:

```cisco
permit udp any eq bootpc any eq bootps
```

It is not `permit tcp`. If the command was entered as TCP during troubleshooting, it would not match DHCP packets because DHCP uses UDP.

**Verification**

I checked client addressing with:

```text
ipconfig /all
```

The later staff client received:

```text
IPv4 Address: 192.168.10.4
Subnet Mask: 255.255.255.224
Default Gateway: 192.168.10.1
DNS Server: 203.0.113.5
```

A later guest client received:

```text
IPv4 Address: 192.168.10.98
Subnet Mask: 255.255.255.224
Default Gateway: 192.168.10.97
```

**Outcome**

Staff and guest clients were able to obtain DHCP addresses after the DHCP traffic permission was corrected.

**Lesson learned**

When DHCP fails on a network using ACLs, I must check whether the ACL permits the required UDP DHCP traffic. I must also verify the correct source and destination ports and the direction in which the ACL is applied.

---

### SO-05: IP Phones Not Obtaining the Required Telephony Configuration

**Problem observed**

The IP phones were not obtaining the required telephony configuration.

**Cause identified**

The voice DHCP pool was missing DHCP Option 150. Cisco IP phones use this option to discover the TFTP server from which they can obtain configuration files.

**Initial voice DHCP pool context**

The voice subnet is:

- Network: `192.168.10.128/27`
- Default gateway: `192.168.10.129`

**Correction**

I added Option 150 to the voice DHCP pool, pointing to the telephony service address:

```cisco
ip dhcp pool voice
 network 192.168.10.128 255.255.255.224
 default-router 192.168.10.129
 option 150 ip 192.168.10.129
 dns-server 203.0.113.5
```

**Verification**

The SO R1 DHCP binding output showed the phone addresses:

| Phone | IP address | MAC address |
|---|---|---|
| Phone 1 | `192.168.10.130` | `00D0.FF38.A686` |
| Phone 2 | `192.168.10.131` | `00D0.9773.7427` |

The router phone registration output showed both phones as registered:

```text
ephone-1 IP:192.168.10.130
DeviceType:Phone has registered.

ephone-2 IP:192.168.10.131
DeviceType:Phone has registered.
```

The configured extensions were `1001` and `1002`.

**Outcome**

After I added DHCP Option 150, the phones obtained addresses and registered with the telephony service.

**Lesson learned**

For Cisco IP telephony, assigning an IP address and default gateway is not sufficient by itself. The phone also needs the correct TFTP server information through DHCP Option 150 so that it can obtain its configuration.

---

## 4. Final Verification Summary

| Service or control | Final evidence | Result |
|---|---|---|
| Port security | Port security violation addressed | Resolved, exact interface details not recorded |
| BPDU Guard | BPDU Guard violation addressed | Resolved, exact triggering connection not recorded |
| DNS | `nslookup` received a response from `203.0.113.5` | Working |
| Staff DHCP | Client received `192.168.10.4/27` | Working in captured test |
| Guest DHCP | Client received `192.168.10.98/27` | Working in later captured test |
| Voice DHCP | Phone leases `.130` and `.131` appeared | Working |
| DHCP Option 150 | Voice pool points to `192.168.10.129` | Configured |
| IP telephony | Both phones reported registered | Working |

## 5. Overall Reflection

During troubleshooting, I learned that connectivity problems can originate from different layers and services even when the physical topology is correct. Port security and BPDU Guard protect the access layer, but their violations can interrupt endpoint connectivity. ACLs can unintentionally block DHCP if the required UDP traffic is not permitted. DNS resolution depends on clients using the DNS server configured for the simulated network. Cisco IP phones also require DHCP Option 150 to discover their TFTP server.

I used configuration checks and end device tests to verify the corrections. The later evidence showed successful client addressing, DNS resolution and IP phone registration. I have retained the incidents as part of the project history so that the troubleshooting process and the final verified behaviour are documented.
