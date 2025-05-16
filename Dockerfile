# 使用多阶段构建整合所有步骤
ARG DARKHTTPD_VERSION=v1.16
ARG ARIANG_VERSION=1.3.10

# 第一阶段：构建 darkhttpd
FROM alpine AS darkhttpd-builder
ENV CFLAGS=" \
  -static                                 \
  -O2                                     \
  -flto                                   \
  -D_FORTIFY_SOURCE=2                     \
  -fstack-clash-protection                \
  -fstack-protector-strong                \
  -pipe                                   \
  -Wall                                   \
  -Werror=format-security                 \
  -Werror=implicit-function-declaration   \
  -Wl,-z,defs                             \
  -Wl,-z,now                              \
  -Wl,-z,relro                            \
  -Wl,-z,noexecstack                      \
"
WORKDIR /src
ARG DARKHTTPD_VERSION
RUN apk add --no-cache build-base curl && \
    curl -sSL "https://github.com/emikulic/darkhttpd/archive/${DARKHTTPD_VERSION}.tar.gz" | \
    tar xz --strip-components=1 && \
    make darkhttpd && \
    strip darkhttpd

# 第二阶段：下载 AriaNg
FROM alpine AS ariang-downloader
ARG ARIANG_VERSION
RUN apk add --no-cache curl && \
    mkdir -p /ariang && \
    curl -sSL "https://github.com/mayswind/AriaNg/releases/download/${ARIANG_VERSION}/AriaNg-${ARIANG_VERSION}-AllInOne.zip" -o ariang.zip && \
    unzip ariang.zip -d /ariang && \
    rm ariang.zip

# 第三阶段：生成运行时文件
FROM alpine AS runtime-preparer
RUN mkdir -p /etc && \
    echo 'nobody:x:65534:65534:nobody:/nonexistent:/sbin/nologin' > /etc/passwd && \
    echo 'nobody:x:65534:' > /etc/group

# 最终镜像
FROM scratch
WORKDIR /ariang

# 复制 darkhttpd 二进制
COPY --from=darkhttpd-builder --chown=0:0 /src/darkhttpd /darkhttpd

# 复制系统文件
COPY --from=runtime-preparer --chown=0:0 /etc/passwd /etc/passwd
COPY --from=runtime-preparer --chown=0:0 /etc/group /etc/group

# 复制 AriaNg
COPY --from=ariang-downloader /ariang/index.html .

EXPOSE 80
ENTRYPOINT ["/darkhttpd"]
CMD [".", "--chroot", "--uid", "nobody", "--gid", "nobody"]
