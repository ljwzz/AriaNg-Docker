#!/bin/bash

# 常量定义
readonly ARIANG_RELEASES_URL="https://api.github.com/repos/mayswind/AriaNg/releases/latest"
readonly DARKHTTPD_RELEASES_URL="https://api.github.com/repos/emikulic/darkhttpd/releases/latest"
readonly DOCKER_IMAGE_NAME="ljwzz/ariang"
readonly PACKAGE_DIR="packages"
readonly PACKAGE_PREFIX="ariang"

# 日志函数
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 错误处理函数
die() {
  log "错误: $1" >&2
  exit 1
}

# 转圈动画函数
spinner() {
  local pid=$1
  local delay=0.1
  local spin_chars=('|' '/' '-' '\')
  local i=0
  local text=$2

  # 隐藏光标
  tput civis

  while kill -0 "$pid" 2>/dev/null; do
    i=$(((i + 1) % 4))
    printf "\r%s%s" "$text" "${spin_chars[$i]}"
    sleep "$delay"
  done

  # 恢复光标并显示完成状态
  tput cnorm
  printf "\r%s%s\n" "$text" "完成"
}

# 获取最新版本号
get_latest_version() {
  local url=$1
  local version

  version=$(curl -sf "$url" |
    grep -m1 '"tag_name":' |
    sed -E 's/.*"(v?[^"]+)".*/\1/')

  [[ -z "$version" ]] && die "无法从 $url 获取版本号"
  echo "$version"
}

# 主流程
main() {
  # 依赖检查
  for cmd in docker curl; do
    if ! command -v "$cmd" &>/dev/null; then
      die "需要安装 $cmd"
    fi
  done

  # 解析参数
  local no_tar=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --no-tar)
      no_tar=true
      shift
      ;;
    *)
      shift
      ;;
    esac
  done

  log "开始构建流程"

  # 获取版本信息
  log "获取组件版本信息..."

  echo -n "获取AriaNg最新版本："
  exec 3< <(get_latest_version "$ARIANG_RELEASES_URL")
  spinner $! "获取AriaNg最新版本："
  ARIANG_VERSION=$(cat <&3)
  exec 3<&-

  log "AriaNg版本: $ARIANG_VERSION"

  echo -n "获取darkhttpd最新版本："
  exec 3< <(get_latest_version "$DARKHTTPD_RELEASES_URL")
  spinner $! "获取darkhttpd最新版本："
  DARKHTTPD_VERSION=$(cat <&3)
  exec 3<&-

  log "darkhttpd版本: $DARKHTTPD_VERSION"

  # 检查是否已存在镜像
  if docker image inspect "$DOCKER_IMAGE_NAME:$ARIANG_VERSION" &>/dev/null; then
    log "警告: 镜像 $DOCKER_IMAGE_NAME:$ARIANG_VERSION 已存在"
    read -rp "是否覆盖现有镜像？[y/N] " answer
    [[ "$answer" != "y" ]] && exit 0
  fi

  # 构建Docker镜像
  log "开始构建Docker镜像..."
  local build_args=(
    "--build-arg" "DARKHTTPD_VERSION=$DARKHTTPD_VERSION"
    "--build-arg" "ARIANG_VERSION=$ARIANG_VERSION"
    "--platform" "linux/amd64"
    "-t" "$DOCKER_IMAGE_NAME:$ARIANG_VERSION"
    "-t" "$DOCKER_IMAGE_NAME:latest"
    "-f" "Dockerfile"
    "."
  )

  if ! docker build "${build_args[@]}"; then
    die "Docker构建失败"
  fi

  log "构建成功完成！"
  log "可用镜像标签:"
  docker images --filter "reference=$DOCKER_IMAGE_NAME" --format "{{.Tag}}" | sort -u

  # 如果不指定--no-tar参数则执行打包
  if [[ "$no_tar" == false ]]; then
    # 打包镜像为tgz
    log "开始打包镜像..."
    mkdir -p "$PACKAGE_DIR"
    local package_name="${PACKAGE_PREFIX}-${ARIANG_VERSION}.tgz"

    echo -n "保存镜像到文件："
    exec 3< <(docker save "$DOCKER_IMAGE_NAME:$ARIANG_VERSION" | gzip >"${PACKAGE_DIR}/${package_name}")
    spinner $! "保存镜像到文件："
    exec 3<&-

    log "打包完成！镜像已保存到: ${PACKAGE_DIR}/${package_name}"
  else
    log "跳过打包步骤 (--no-tar参数已指定)"
  fi
}

main "$@"
