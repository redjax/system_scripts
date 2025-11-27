# Wireshark

[Wireshark](https://www.wireshark.org/download.html) is a network monitoring/packet capture/packet inspection tool. [tshark](https://tshark.dev/setup/install/) is included with the `wireshark` package, and is the CLI utility for non-GUI environments. [dumpcap]() is also installed with Wireshark; it is a tool for collecting package captures with minimal overhead, no live/real-time analysis, and you must open the capture files in Wireshark or tshark to view them. It can monitor multiple interfaces at once, rotate files to avoid filling up the disk, & more.

## Wireshark Usage

## Tshark Usage

| Command                                         | Description                                              |
| ----------------------------------------------- | -------------------------------------------------------- |
| `tshark -D`                                     | List available interfaces.                               |
| `sudo tshark -i <interface>`                    | Start capture on a given interface.                      |
| `sudo tshark -i <interface> -f "port 22"`       | Filter to only monitoring traffic on port 22.            |
| `sudo tshark -r capture_name.pcap -V`           | Capture to a `.pcap` file; `-V` for verbose view.        |
| `sudo tshark -i <interface> -q -z ip_hosts`     | Show "top talkers" by IP.                                |
| `sudo tshark -i <interface> -q -z io,phs`       | Show summary by protocol.                                |
| `sudo tshark -i <interface> -q -z conv,tc`      | Show bytes per conversation.                             |
| `sudo tshark -i <interface> -f "host 10.0.0.5"` | Capture & display only packets containing a specific IP. |
| `sudo tshark -i <interface> -f "tcp"`           | Show only TCP traffic.                                   |

## Dumpcap Usage

`dumpcap` is installed by the Wireshark package, and is the scanning backend for Wireshark.

| Command / Option                                                                      | Description / Example                                               |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `dumpcap -v`                                                                          | Show version info                                                   |
| `dumpcap -h`                                                                          | Show help and all options                                           |
| `dumpcap -D`                                                                          | List all network interfaces available for capture                   |
| `sudo dumpcap -i eth0 -w capture.pcap`                                                | Capture packets on `eth0` to `capture.pcap`                         |
| `sudo dumpcap -i eth0 -i tailscale0 -w combined.pcap`                                 | Capture on multiple interfaces simultaneously                       |
| `sudo dumpcap -c 1000 -i eth0 -w capture.pcap`                                        | Stop after 1000 packets                                             |
| `sudo dumpcap -b filesize:100000 -b files:10 -i eth0 -w capture`                      | Rotate capture files: 10 files, 100 MB each                         |
| `sudo dumpcap -a duration:60 -i eth0 -w capture.pcap`                                 | Capture for 60 seconds and stop automatically                       |
| `sudo dumpcap -f "port 22" -i eth0 -w ssh.pcap`                                       | Capture only SSH traffic (BPF filter)                               |
| `sudo dumpcap -f "tcp port 80 or tcp port 443" -i eth0 -w http_https.pcap`            | Capture HTTP and HTTPS traffic                                      |
| `sudo dumpcap -f "host 10.0.0.5" -i eth0 -w host_capture.pcap`                        | Capture all traffic to/from a specific host                         |
| `sudo dumpcap -b filesize:100000 -b files:10 -a duration:3600 -i eth0 -w capture`     | Continuous capture for 1 hour with file rotation (10×100MB files)   |
| `dumpcap -r capture.pcap`                                                             | Display packets from a capture file (limited analysis)              |
| `dumpcap -q -i eth0 -w capture.pcap`                                                  | Quiet mode (no output to terminal)                                  |
| `tshark -r capture.pcap -q -z conv,ip`                                                | Analyze capture file for IP conversations                           |
| `tshark -r capture.pcap -q -z io,stat,5`                                              | Show bandwidth per 5-second interval from capture                   |
| `tshark -r capture.pcap -q -z io,phs`                                                 | Show protocol hierarchy summary from capture                        |
| `sudo usermod -aG wireshark $USER`                                                    | Allows packet capture without root privileges                       |
| `-b filesize:<size>` and `-b files:<count>`                                           | Ensure long-term captures don’t fill disk; used for ring buffer     |
| `dumpcap -i eth0 -i tailscale0 -b filesize:50000 -b files:5 -w /tmp/combined_capture` | Capture on multiple interfaces simultaneously with rotation         |
| `sudo dumpcap -f "not broadcast and not multicast" -i eth0 -w capture.pcap`           | Capture only unicast traffic (filter out broadcast/multicast noise) |
| `dumpcap -i eth0 -a filesize:100000 -a files:10 -w capture.pcap`                      | Another example of rotating capture files automatically             |
| `tshark -r capture.pcap -q -z endpoints`                                              | Show statistics for all hosts in the capture                        |
| `tshark -r capture.pcap -q -z conv,tcp`                                               | Show TCP conversation statistics                                    |
| `watch -n 2 'tshark -r /path/to/capture.pcap -q -z conv,ip                            | tail -n 20'`                                                        | Live-read a `dumpcap` file with `tshark` |

## Examples

### Dumpcap + tshark or Wireshark

To determine the source of uknown traffic, you can use `dumpcap` to capture packets, & `tshark` to view them live.

```shell
## Start monitor on multiple interfaces
sudo dumpcap -i enp2s0 -i eth0 -b filesize:100000 -b files:10 -w /tmp/combined_capture

## In another session, open the pcap for live analysis
tshark -r /tmp/combined_capture_00001_20251126.pcap -q -z conv,ip
```
