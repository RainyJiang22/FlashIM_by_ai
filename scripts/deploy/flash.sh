#!/bin/bash
#
# 闪讯 IM — 服务管理脚本
#
# 用法：
#   bash flash.sh          # 后台启动
#   bash flash.sh stop     # 停止服务
#   bash flash.sh restart  # 重启服务
#   bash flash.sh status   # 查看服务状态
#   bash flash.sh log      # 查看实时日志
#   bash flash.sh clear    # 清空日志文件
#   bash flash.sh install  # 注册为系统服务（开机自启）
#   bash flash.sh uninstall # 移除系统服务
#

# ─── 颜色 ───

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

# ─── 配置 ───

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$WORK_DIR/flash-im"
SERVICE_NAME="flash-im"
LOG_FILE="$WORK_DIR/flash-im.log"

ACTION="${1:-start}"

# ─── 启动 ───

do_start() {
  if [ ! -f "$BINARY" ]; then
    warn "二进制文件不存在：$BINARY"
    exit 1
  fi

  chmod +x "$BINARY" 2>/dev/null

  # 如果已经在运行，先停掉
  if pgrep -f "$BINARY" &>/dev/null; then
    info "服务正在运行，先停止..."
    pkill -f "$BINARY"
    sleep 1
  fi

  cd "$WORK_DIR"
  nohup stdbuf -oL "$BINARY" > "$LOG_FILE" 2>&1 &
  PID=$!
  sleep 1

  if kill -0 "$PID" 2>/dev/null; then
    ok "服务已在后台启动（PID: $PID）"
    info "日志文件：$LOG_FILE"
    info "查看日志：bash flash.sh log"
    info "停止服务：bash flash.sh stop"
  else
    warn "启动失败，查看日志：cat $LOG_FILE"
  fi
}

# ─── 停止 ───

do_stop() {
  if pgrep -f "$BINARY" &>/dev/null; then
    pkill -f "$BINARY"
    ok "服务已停止"
  else
    info "服务未在运行"
  fi
}

# ─── 重启 ───

do_restart() {
  do_stop
  sleep 1
  do_start
}

# ─── 状态 ───

do_status() {
  echo ""
  if pgrep -f "$BINARY" &>/dev/null; then
    PID=$(pgrep -f "$BINARY")
    ok "服务运行中（PID: $PID）"
    info "内存占用：$(ps -o rss= -p $PID | awk '{printf "%.1f MB", $1/1024}')"
    info "运行时间：$(ps -o etime= -p $PID | xargs)"
  else
    warn "服务未在运行"
  fi
  echo ""
}

# ─── 日志 ───

do_log() {
  if [ -f "$LOG_FILE" ]; then
    info "实时日志（Ctrl+C 退出）"
    echo ""
    tail -f "$LOG_FILE"
  else
    warn "日志文件不存在：$LOG_FILE"
  fi
}

# ─── 清除日志 ───

do_clear() {
  if [ -f "$LOG_FILE" ]; then
    > "$LOG_FILE"
    ok "日志已清空"
  else
    info "日志文件不存在，无需清除"
  fi
}

# ─── 注册系统服务 ───

do_install() {
  cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Flash IM Server
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/flash-im
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable $SERVICE_NAME &>/dev/null
  ok "已注册为系统服务（开机自启）"
  info "启动：systemctl start $SERVICE_NAME"
  info "状态：systemctl status $SERVICE_NAME"
  info "日志：journalctl -u $SERVICE_NAME -f"
}

# ─── 移除系统服务 ───

do_uninstall() {
  systemctl stop $SERVICE_NAME &>/dev/null
  systemctl disable $SERVICE_NAME &>/dev/null
  rm -f /etc/systemd/system/$SERVICE_NAME.service
  systemctl daemon-reload
  ok "系统服务已移除"
}

# ─── 主入口 ───

case "$ACTION" in
  start)
    do_start
    ;;
  stop)
    do_stop
    ;;
  restart)
    do_restart
    ;;
  status)
    do_status
    ;;
  log)
    do_log
    ;;
  clear)
    do_clear
    ;;
  install)
    do_install
    ;;
  uninstall)
    do_uninstall
    ;;
  *)
    echo "用法：bash flash.sh [命令]"
    echo ""
    echo "  (无参数)   启动服务（后台运行）"
    echo "  stop       停止服务"
    echo "  restart    重启服务"
    echo "  status     查看服务状态"
    echo "  log        查看实时日志"
    echo "  clear      清空日志文件"
    echo "  install    注册为系统服务（开机自启）"
    echo "  uninstall  移除系统服务"
    exit 1
    ;;
esac
