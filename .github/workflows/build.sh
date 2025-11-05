#!/bin/bash

# 配置变量 - 根据你的需求修改
REPO_URL="https://github.com/ddouweb/lede"
REPO_BRANCH="master"
FEEDS_CONF="feeds.conf.default"
CONFIG_FILE=".ledeconfig"
DIY_P1_SH="diy-part1.sh"
DIY_P2_SH="diy-part2.sh"
WORK_DIR="/workdir/openwrt"  # 可以修改为你的路径
TZ="Asia/Shanghai"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 1. 初始化环境
init_environment() {
    log "初始化编译环境..."
    
    # 检查系统
    if [ ! -f /etc/debian_version ]; then
        warn "非 Debian/Ubuntu 系统，可能需要手动安装依赖"
    else
        sudo apt update
        sudo apt install -y $(curl -fsSL https://raw.githubusercontent.com/P3TERX/Actions-OpenWrt/main/depends-ubuntu-2004 2>/dev/null || echo "build-essential libncurses5-dev gawk git libssl-dev gettext zlib1g-dev rsync wget")
    fi
    
    # 创建编译目录
    mkdir -p $(dirname $WORK_DIR)
    export TZ=$TZ
}

# 2. 克隆源代码
clone_source() {
    log "克隆源代码..."
    
    if [ -d "$WORK_DIR" ]; then
        log "源码已存在，拉取更新..."
        cd "$WORK_DIR"
        git pull origin $REPO_BRANCH
    else
        git clone $REPO_URL -b $REPO_BRANCH "$WORK_DIR"
    fi
    
    cd "$WORK_DIR"
}

# 3. 加载自定义配置
load_custom_feeds() {
    log "加载自定义 feeds 配置..."
    
    cd "$WORK_DIR"
    
    # 加载自定义 feeds.conf
    if [ -f "$GITHUB_WORKSPACE/$FEEDS_CONF" ]; then
        cp "$GITHUB_WORKSPACE/$FEEDS_CONF" feeds.conf.default
    fi
    
    # 执行自定义脚本1
    if [ -f "$GITHUB_WORKSPACE/$DIY_P1_SH" ]; then
        chmod +x "$GITHUB_WORKSPACE/$DIY_P1_SH"
        "$GITHUB_WORKSPACE/$DIY_P1_SH"
    fi
}

# 4. 更新和安装 feeds
update_feeds() {
    log "更新 feeds..."
    cd "$WORK_DIR"
    ./scripts/feeds update -a
    
    log "安装 feeds..."
    ./scripts/feeds install -a
}

# 5. 加载自定义配置
load_custom_config() {
    log "加载自定义配置..."
    
    cd "$WORK_DIR"
    
    # 复制文件目录
    if [ -d "$GITHUB_WORKSPACE/files" ]; then
        cp -r "$GITHUB_WORKSPACE/files" .
    fi
    
    # 复制配置文件
    if [ -f "$GITHUB_WORKSPACE/$CONFIG_FILE" ]; then
        cp "$GITHUB_WORKSPACE/$CONFIG_FILE" .config
    fi
    
    # 执行自定义脚本2
    if [ -f "$GITHUB_WORKSPACE/$DIY_P2_SH" ]; then
        chmod +x "$GITHUB_WORKSPACE/$DIY_P2_SH"
        "$GITHUB_WORKSPACE/$DIY_P2_SH"
    fi
}

# 6. 下载软件包
download_packages() {
    log "下载软件包..."
    cd "$WORK_DIR"
    
    make defconfig
    make download -j$(nproc)
    
    # 清理无效的小文件
    find dl -size -1024c -delete
}

# 7. 编译固件
compile_firmware() {
    log "开始编译固件..."
    cd "$WORK_DIR"
    
    echo "$(nproc) 线程编译"
    
    # 编译策略：先多线程，失败后单线程，最后详细模式
    if ! make -j$(nproc); then
        warn "多线程编译失败，尝试单线程编译..."
        if ! make -j1; then
            error "单线程编译失败，尝试详细模式..."
            make -j1 V=s
        fi
    fi
    
    log "编译完成！"
}

# 8. 整理文件
organize_files() {
    log "整理输出文件..."
    cd "$WORK_DIR/bin/targets"/*/*
    
    # 删除 packages 目录（可选）
    rm -rf packages
    
    FIRMWARE_DIR=$(pwd)
    log "固件输出目录: $FIRMWARE_DIR"
    
    # 显示生成的文件
    find . -type f -name "*.bin" -o -name "*.img" -o -name "*.gz" | sort
}

# 9. 上传功能（本地版本）
upload_files() {
    log "准备上传文件..."
    
    # 这里可以添加本地文件处理逻辑
    # 比如复制到指定目录、生成MD5等
    
    local target_dir="/tmp/openwrt_build_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$target_dir"
    cp $FIRMWARE_DIR/* "$target_dir/" 2>/dev/null || true
    
    log "文件已复制到: $target_dir"
    echo "固件位置: $target_dir"
}

# 主执行流程
main() {
    log "开始 OpenWrt 编译流程..."
    
    # 设置错误处理
    set -e
    
    # 执行各个步骤
    init_environment
    clone_source
    load_custom_feeds
    update_feeds
    load_custom_config
    download_packages
    compile_firmware
    organize_files
    upload_files
    
    log "编译流程全部完成！"
}

# 运行主函数
main "$@"
