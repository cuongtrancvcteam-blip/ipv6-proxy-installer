# Vultr IPv6 Pool Pack

Ready-to-run scripts for Ubuntu/Debian when your Vultr instance has a routed IPv6 `/64`.

## What this pack does

- Generates a deterministic pool of many IPv6 addresses from your Vultr subnet
- Adds them to your network interface
- Saves the generated list so apps or proxies can reuse it
- Generates a `3proxy` config that binds one proxy port to one IPv6
- Installs a `systemd` boot service so the pool comes back after reboot

## Files

- `ipv6_pool.conf.example`: config template
- `add_ipv6_pool.sh`: generate and assign the IPv6 pool
- `remove_ipv6_pool.sh`: remove the assigned IPv6 pool
- `generate_3proxy_cfg.sh`: build a `3proxy` config and export endpoint list
- `install_boot_service.sh`: create a boot-time `systemd` unit
- `install_all.sh`: one-command installer for Ubuntu/Debian
- `quick_setup.sh`: interactive one-command setup wizard
- `bootstrap.sh`: single-file loader for curl-based installs
- `auto_detect_config.sh`: detect the main interface, IPv6, and routed `/64` automatically
- `zero_input_install.sh`: zero-input installer for GitHub and curl workflows
- `setup_download_link.sh`: expose the exported txt file over HTTP and print a direct link

## Before you run it

On the VPS, confirm that Vultr already assigned an IPv6 network:

```bash
ip -6 addr
ip -6 route
```

You should see a routed IPv6 subnet and at least one global IPv6.

## Setup

Copy the folder to your VPS, then:

```bash
cd vultr_ipv6
cp ipv6_pool.conf.example ipv6_pool.conf
nano ipv6_pool.conf
```

Edit at least these values:

- `INTERFACE`: usually `eth0`
- `IPV6_SUBNET`: your Vultr routed subnet, for example `2001:19f0:1234:5678::/64`
- `PRIMARY_IPV6`: optional, your main IPv6 if you want the generator to avoid it
- `COUNT`: how many extra IPv6 to add
- `RANDOM_SEED`: any private string, used to generate a stable pool
- `DOWNLOAD_EXPORT_PATH`: where to place the ready-to-download `ip:port:user:pass` text file

## One-command install

If you want the closest thing to "len VPS chay 1 lenh la xong", use this:

```bash
cd vultr_ipv6
sudo bash zero_input_install.sh
```

It will:

- auto-detect the main network interface
- auto-detect the primary IPv6
- auto-detect the routed IPv6 `/64`
- generate random `user` and `pass`
- install required packages
- generate and add the IPv6 pool
- configure startup persistence
- generate the `3proxy` config
- create and start a dedicated `systemd` service for `3proxy`
- copy a ready-to-download text file such as `/root/proxy_endpoints.txt`
- print a direct download URL such as `http://your-vps-ip:8080/proxy_endpoints.txt`

The exported file format is:

```text
ipv6:port:user:pass
```

You can still override defaults when needed:

```bash
sudo COUNT=5000 START_PORT=40000 SHARE_PORT=9090 bash zero_input_install.sh
```

If you prefer editing the config manually instead of using the wizard:

```bash
cd vultr_ipv6
cp ipv6_pool.conf.example ipv6_pool.conf
nano ipv6_pool.conf
sudo bash install_all.sh ./ipv6_pool.conf
```

## Single curl command

If you want to paste one command into a fresh VPS, host:

- `bootstrap.sh`
- a tarball of this folder, for example `vultr_ipv6.tar.gz`

Then run:

```bash
curl -fsSL https://raw.githubusercontent.com/cuongtrancvcteam-blip/ipv6-proxy-installer/main/bootstrap.sh | sudo bash
```

That is the shortest command for this repo because `bootstrap.sh` already knows the GitHub tarball URL.

You can still override the tarball source manually if needed:

```bash
curl -fsSL https://raw.githubusercontent.com/cuongtrancvcteam-blip/ipv6-proxy-installer/main/bootstrap.sh | sudo PACK_URL=https://your-host.example.com/vultr_ipv6.tar.gz bash
```

This does not require GitHub specifically. Any reachable URL works.

Easy hosting options:

- GitHub repo with raw file URLs
- GitHub Gist for `bootstrap.sh` plus any file host for the tarball
- your own web server
- object storage with public link

GitHub easiest pattern:

- create a dedicated repo that contains these files
- upload `bootstrap.sh` and the rest of the pack
- use GitHub raw URL for `bootstrap.sh`
- use GitHub repo tarball URL for `PACK_URL`

Example:

```bash
curl -fsSL https://raw.githubusercontent.com/cuongtrancvcteam-blip/ipv6-proxy-installer/main/bootstrap.sh | sudo bash
```

That command now defaults to zero-input mode.

If you want the old prompt-based mode:

```bash
curl -fsSL https://raw.githubusercontent.com/cuongtrancvcteam-blip/ipv6-proxy-installer/main/bootstrap.sh | sudo INSTALL_MODE=interactive bash
```

## Direct download link after install

By default, the installer also starts a tiny HTTP file server for the exported txt file.

Default link format:

```text
http://YOUR_VPS_IPV4:8080/proxy_endpoints.txt
```

Related config values:

- `ENABLE_HTTP_SHARE="yes"`
- `SHARE_PORT=8080`
- `SHARE_DIR="/opt/vultr-ipv6-share"`
- `SHARE_FILE_NAME="proxy_endpoints.txt"`

If you use the Vultr firewall or UFW, open `SHARE_PORT` and your proxy port range.

## Add the IPv6 pool

```bash
sudo bash add_ipv6_pool.sh ./ipv6_pool.conf
ip -6 addr show dev eth0 | grep inet6 | wc -l
```

The generated IPv6 list is saved to `ADDR_LIST_FILE`, default:

```bash
/var/lib/vultr-ipv6-pool/ipv6_pool.txt
```

## Make it persistent after reboot

```bash
sudo bash install_boot_service.sh ./ipv6_pool.conf
sudo systemctl start vultr-ipv6-pool.service
sudo systemctl status vultr-ipv6-pool.service
```

## Generate 3proxy bindings

Install `3proxy` first:

```bash
sudo apt update
sudo apt install -y 3proxy
```

Then generate the config:

```bash
sudo bash generate_3proxy_cfg.sh ./ipv6_pool.conf
sudo systemctl restart 3proxy-vultr-ipv6.service
sudo systemctl status 3proxy-vultr-ipv6.service
```

Generated files:

- `PROXY_CFG_PATH`: default `/etc/3proxy/3proxy.cfg`
- `PROXY_EXPORT_PATH`: default `/var/lib/vultr-ipv6-pool/proxy_endpoints.txt`
- `DOWNLOAD_EXPORT_PATH`: default `/root/proxy_endpoints.txt`

Each line in `proxy_endpoints.txt` looks like:

```text
ipv6:port:login:password
```

## Bind your own app to a specific IPv6

The simplest pattern is to read one IP from the pool file and pass it as the source address in your app.

Examples:

```bash
curl --interface 2001:19f0:1234:5678:1111:2222:3333:4444 https://api64.ipify.org
```

In Python:

```python
import socket

source_ip = "2001:19f0:1234:5678:1111:2222:3333:4444"
sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
sock.bind((source_ip, 0, 0, 0))
```

## Remove the pool

```bash
sudo bash remove_ipv6_pool.sh ./ipv6_pool.conf
```

## Notes

- This pack assumes a routed IPv6 `/64`. It will not work if your VPS only has a single `/128`.
- `nodad` is used when adding IPs so bulk assignment finishes much faster.
- If you change `RANDOM_SEED`, the generated IPv6 set changes too.
- Test with a smaller `COUNT` like `50` before jumping to `2000` or more.
- The simplest OS choice for this pack is Ubuntu 22.04/24.04 or Debian 12.
