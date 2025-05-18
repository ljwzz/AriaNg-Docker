# AriaNg Docker

## Build

```
sh make.sh
```

## Run with Docker

```bash
docker run -d \
    --name ariang \
    --log-opt max-size=1m \
    --restart unless-stopped \
    -p 6880:80 \
    ljwzz/ariang:latest
```

## Docker Compose

```yaml
version: '3.8'
services:
  AriaNg:
    container_name: ariang
    image: ljwzz/ariang:latest
    network_mode: bridge
    ports:
      - '127.0.0.1:6880:80'
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: 1m
```

## Credits

- [mayswind/AriaNg⁠](https://github.com/mayswind/AriaNg)
- [emikulic/darkhttpd⁠](https://github.com/emikulic/darkhttpd)
