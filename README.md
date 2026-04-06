# IPv6 Proxy Installer

## Dung Cho Cai Gi

- VPS co routed IPv6 `/64`
- Dung duoc cho nhieu nha cung cap, khong chi rieng Vultr
- OS khuyen dung: `Ubuntu 22.04 x64`

## Truoc Khi Chay

1. Tao VPS `Ubuntu 22.04`
2. Bat hoac gan IPv6 network cho VPS trong panel cua nha cung cap
3. Dam bao VPS co routed IPv6 `/64`

## Lenh Mac Dinh

SSH vao VPS roi chay:

```bash
curl -fsSL https://raw.githubusercontent.com/cuongtrancvcteam-blip/ipv6-proxy-installer/main/bootstrap.sh | sudo bash
```

## No Se Tu Lam

- tu detect interface
- tu detect IPv6 `/64`
- tu random `user`
- tu random `pass`
- tu tao `2000` proxy mac dinh
- tu tao file txt
- tu in link tai file

## Ket Qua

Sau khi chay xong, no se in ra:

- `Proxy username`
- `Proxy password`
- `Download URL`

Link tai thuong dang:

```text
http://IP_VPS:8080/proxy_endpoints.txt
```

File txt co dang:

```text
ipv6:port:user:pass
```

## Luu Y

- Chi can VPS co routed IPv6 `/64` la dung duoc
- Vultr chi la mot vi du, khong phai dieu kien bat buoc
- Neu VPS khong co IPv6 `/64` thi script khong chay duoc
- Mac dinh hien tai la `2000` proxy
