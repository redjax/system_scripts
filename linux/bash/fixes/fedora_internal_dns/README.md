# Fix Fedora Internal DNS Resolution

I host my own DNS server (AdGuard/Technitium/Blocky), and my desktop machine occasionally loses the ability to lookup internal addresses/rewrites, i.e. `some-hostname.home`. I have found the following 3 commands fix the problem, assuming you see a connection named `Writed connection 1` when running `sudo nmcli connection show`:

```shell
sudo nmcli connection modify "Wired connection 1" ipv4.dns "192.168.1.xxx"
sudo nmcli connection modify "Wired connection 1" ipv4.ignore-auto-dns yes
sudo nmcli connection up "Wired connection 1"
```

The [`fix-internal-dns.sh` script](./fix-internal-dns.sh) runs these commands with guards to ensure the connection name exists and the command can complete successfully.
