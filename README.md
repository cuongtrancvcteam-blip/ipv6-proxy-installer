# IPv6 Proxy Installer

## Requirements

- Any VPS with a routed IPv6 `/64`
- Not limited to Vultr
- Recommended OS: `Ubuntu 22.04 x64`

## Before You Run It

1. Create a VPS with `Ubuntu 22.04`
2. Enable or assign IPv6 in your provider panel
3. Make sure the VPS has a routed IPv6 `/64`

## Default Command

SSH into the VPS and run:

```bash
curl -fsSL https://raw.githubusercontent.com/cuongtrancvcteam-blip/ipv6-proxy-installer/main/bootstrap.sh | sudo bash
```

## What The Default Command Does

- auto-detects the main network interface
- auto-detects the routed IPv6 `/64`
- generates a random proxy username and password
- creates `2000` proxies by default
- exports a txt file
- prints a direct download link
- opens the needed UFW ports automatically if UFW is active

## Default Output

After it finishes, it prints:

- `Proxy username`
- `Proxy password`
- `Download URL`

The txt file format is:

```text
ipv4_of_vps:port:user:pass
```

The download link usually looks like:

```text
http://YOUR_VPS_IPV4:8080/proxy_endpoints.txt
```

That link now forces a `.txt` download in the browser instead of just opening the text in a tab.

## If You Want More Proxies

Run this command and replace `3000` with the number you want:

```bash
curl -fsSL https://raw.githubusercontent.com/cuongtrancvcteam-blip/ipv6-proxy-installer/main/bootstrap.sh | sudo COUNT=3000 bash
```

Explanation:

- the default command keeps `2000` proxies
- that default is a balance between quantity and reliability
- if you want more, set `COUNT` to a higher number

## Notes

- This works only if the VPS really has a routed IPv6 `/64`
- If the provider gives only one IPv6 or a `/128`, this will not work
