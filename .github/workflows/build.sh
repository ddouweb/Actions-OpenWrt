#!/bin/bash

# WSL 专用 OpenWrt 编译脚本
# 配置变量 - 根据你的需求修改
REPO_URL="https://github.com/ddouweb/lede"
REPO_BRANCH="master"
FEEDS_CONF="feeds.conf.default"
CONFIG_FILE=".ledeconfig"
DIY_P1_SH="diy-part1.sh"
DIY_P2_SH="diy-part2.sh"
WORK_DIR="$HOME/openwrt-build"  # 使用家目录
BUILD_DIR="$WORK_DIR/openwrt"
TZ="Asia/Shanghai"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# 检测 WSL 版本
detect_wsl() {
    if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
        log "检测到 WSL 环境"
        return 0
    else
        warn "未检测到 WSL 环境，继续执行..."
        return 1
    fi
}

# 1. 初始化环境
init_environment() {
    log "初始化 WSL 编译环境..."
    
    # 检查磁盘空间
    local available_space=$(df $WORK_DIR | awk 'NR==2 {print $4}')
    if [ $available_space -lt 10485760 ]; then  # 小于 10GB
        warn "可用空间不足10GB，建议清理空间"
        df -h $WORK_DIR
    fi
    
    # WSL 特定优化
    if detect_wsl; then
        # 增加 WSL 最大内存（如果有配置）
        if [ -f /mnt/c/Users/.wslconfig ]; then
            log "检测到 WSL 配置"
        else
            warn "建议配置 .wslconfig 以优化性能"
            cat << EOF
在 C:\Users\<用户名>\.wslconfig 中添加：
[wsl2]
memory=8GB
processors=4
swap=2GB
EOF
        fi
    fi
    
    # 安装依赖（Ubuntu/Debian）
    if command -v apt &> /dev/null; then
        log "安装编译依赖..."
        sudo apt update
        sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
            gettext git libncurses5-dev libssl-dev python3 python3-pip python3-serial \
            rsync unzip zlib1g-dev file wget curl
    else
        error "不支持的包管理器，请手动安装依赖"
    fi
    
    # 创建编译目录
    mkdir -p "$WORK_DIR"
    log "工作目录: $WORK_DIR"
}

# 2. 克隆源代码
clone_source() {
    log "克隆源代码..."
    
    if [ -d "$BUILD_DIR" ]; then
        log "源码已存在，拉取更新..."
        cd "$BUILD_DIR"
        
        # 保存本地修改
        if git status --porcelain | grep -q .; then
            warn "发现未提交的修改，创建备份..."
            cd ..
            mv openwrt "openwrt-backup-$(date +%Y%m%d_%H%M%S)"
            git clone $REPO_URL -b $REPO_BRANCH openwrt
        else
            git pull origin $REPO_BRANCH
        fi
    else
        git clone $REPO_URL -b $REPO_BRANCH "$BUILD_DIR"
    fi
    
    cd "$BUILD_DIR"
}

# 3. 加载自定义配置（使用相对路径）
load_custom_feeds() {
    log "加载自定义 feeds 配置..."
    
    cd "$BUILD_DIR"
    
    # 从脚本所在目录加载配置
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 加载自定义 feeds.conf
    if [ -f "$script_dir/$FEEDS_CONF" ]; then
        log "使用自定义 feeds 配置"
        cp "$script_dir/$FEEDS_CONF" feeds.conf.default
    elif [ -f "./$FEEDS_CONF" ]; then
        log "使用当前目录的 feeds 配置"
        cp "./$FEEDS_CONF" feeds.conf.default
    fi
    
    # 执行自定义脚本1
    if [ -f "$script_dir/$DIY_P1_SH" ]; then
        log "执行自定义脚本1"
        chmod +x "$script_dir/$DIY_P1_SH"
        "$script_dir/$DIY_P1_SH"
    elif [ -f "./$DIY_P1_SH" ]; then
        log "执行当前目录的自定义脚本1"
        chmod +x "./$DIY_P1_SH"
        "./$DIY_P1_SH"
    fi
}

# 4. 更新和安装 feeds
update_feeds() {
    log "更新 feeds..."
    cd "$BUILD_DIR"
    ./scripts/feeds update -a
    
    log "安装 feeds..."
    ./scripts/feeds install -a
}

# 5. 加载自定义配置
load_custom_config() {
    log "加载自定义配置..."
    
    cd "$BUILD_DIR"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 复制文件目录
    if [ -d "$script_dir/files" ]; then
        log "复制自定义文件"
        cp -r "$script_dir/files" .
    fi
    
    # 复制配置文件
    if [ -f "$script_dir/$CONFIG_FILE" ]; then
        log "使用自定义配置文件"
        cp "$script_dir/$CONFIG_FILE" .config
    elif [ -f "./$CONFIG_FILE" ]; then
        log "使用当前目录的配置文件"
        cp "./$CONFIG_FILE" .config
    fi
    
    # 执行自定义脚本2
    if [ -f "$script_dir/$DIY_P2_SH" ]; then
        log "执行自定义脚本2"
        chmod +x "$script_dir/$DIY_P2_SH"
        "$script_dir/$DIY_P2_SH"
    elif [ -f "./$DIY_P2_SH" ]; then
        log "执行当前目录的自定义脚本2"
        chmod +x "./$DIY_P2_SH"
        "./$DIY_P2_SH"
    fi
}

# 6. 下载软件包
download_packages() {
    log "下载软件包..."
    cd "$BUILD_DIR"
    
    # 先检查配置
    if [ ! -f .config ]; then
        make defconfig
    fi
    
    # 并行下载
    local cpu_cores=$(nproc)
    local download_jobs=$((cpu_cores > 8 ? 8 : cpu_cores))
    
    log "使用 $download_jobs 个线程下载"
    make download -j$download_jobs
    
    # 清理无效的小文件
    find dl -size -1024c -delete 2>/dev/null || true
    
    # 检查下载完整性
    local broken_files=$(find dl -size 0 2>/dev/null | wc -l)
    if [ $broken_files -gt 0 ]; then
        warn "发现 $broken_files 个空文件，重新下载..."
        find dl -size 0 -delete
        make download -j1 V=s
    fi
}

# 7. 编译固件（WSL 优化版）
compile_firmware() {
    log "开始编译固件..."
    cd "$BUILD_DIR"
    
    local cpu_cores=$(nproc)
    log "使用 $cpu_cores 个CPU核心编译"
    
    # WSL 内存检查
    local available_mem=$(free -g | awk 'NR==2 {print $7}')
    if [ $available_mem -lt 4 ]; then
        warn "可用内存不足4GB，建议关闭其他程序"
        local compile_jobs=$((cpu_cores > 2 ? 2 : cpu_cores))
    else
        local compile_jobs=$cpu_cores
    fi
    
    log "使用 $compile_jobs 个线程编译"
    
    # 编译策略
    if ! make -j$compile_jobs; then
        warn "多线程编译失败，尝试单线程编译..."
        if ! make -j1; then
            warn "单线程编译失败，尝试详细模式..."
            make -j1 V=s
        fi
    fi
    
    log "编译完成！"
}

# 8. 整理文件
organize_files() {
    log "整理输出文件..."
    
    if [ -d "$BUILD_DIR/bin/targets" ]; then
        cd "$BUILD_DIR/bin/targets"/*/*
        
        # 删除 packages 目录（可选）
        rm -rf packages 2>/dev/null || true
        
        FIRMWARE_DIR=$(pwd)
        log "固件输出目录: $FIRMWARE_DIR"
        
        # 显示生成的文件
        echo "生成的固件文件:"
        find . -type f \( -name "*.bin" -o -name "*.img" -o -name "*.gz" \) -exec ls -lh {} \; | sort
    else
        error "编译输出目录不存在，编译可能失败"
    fi
}

# 9. 复制文件到 Windows 方便访问
copy_to_windows() {
    log "复制文件到 Windows 目录..."
    
    local windows_desktop="/mnt/c/Users/$USER/Desktop/OpenWrt_Build_$(date +%Y%m%d_%H%M%S)"
    
    if [ -d "/mnt/c/Users" ]; then
        mkdir -p "$windows_desktop"
        cp -r $FIRMWARE_DIR/* "$windows_desktop/" 2>/dev/null || true
        log "文件已复制到 Windows 桌面: $windows_desktop"
    else
        warn "未找到 Windows 目录，跳过复制"
    fi
}

# 主执行流程
main() {
    log "开始在 WSL 中编译 OpenWrt..."
    log工作目录: $WORK_DIR"
    
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
    copy_to_windows
    
    log "编译流程全部完成！"
    log "固件位置: $FIRMWARE_DIR"
}

# 运行主函数
main "$@"
