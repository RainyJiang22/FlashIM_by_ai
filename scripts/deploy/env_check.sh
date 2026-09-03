#!/bin/bash
#
# 闪讯 IM — 服务器运行环境检测
#
# 在部署目录下执行，检测运行所需的环境是否就绪。
#

set -e

# ─── 颜色输出 ───

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; }

# ─── 配置 ───

WORK_DIR="$(pwd)"
MIGRATIONS_DIR="$WORK_DIR/migrations"
ENV_FILE="$WORK_DIR/.env"
BINARY_PATH="$WORK_DIR/flash-im"
SERVER_PORT="9600"
DB_NAME="flash_im"

PASS=0
WARN_COUNT=0
FAIL_COUNT=0

check_pass() { ok "$1"; PASS=$((PASS + 1)); }
check_warn() { warn "$1"; WARN_COUNT=$((WARN_COUNT + 1)); }
check_fail() { fail "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   闪讯 IM — 运行环境检测                 ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─── 1. 系统信息 ───

info "━━━ 系统信息 ━━━"
echo ""
OS=$(uname -s)
ARCH=$(uname -m)
DISTRO=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME" | cut -d'"' -f2 || echo "Unknown")
info "系统：$DISTRO"
info "架构：$ARCH"
info "内核：$(uname -r)"
echo ""

# ─── 2. 内存与 Swap ───

info "━━━ 内存与 Swap ━━━"
echo ""

TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
AVAIL_MEM=$(free -m | awk '/^Mem:/{print $7}')
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')

info "总内存：${TOTAL_MEM}MB，可用：${AVAIL_MEM}MB，Swap：${SWAP_TOTAL}MB"

if [ "$SWAP_TOTAL" -eq 0 ] && [ "$TOTAL_MEM" -lt 4096 ]; then
  check_warn "内存 < 4G 且无 Swap，建议创建 Swap 防止 OOM"
  echo ""
  read -p "  是否自动创建 2G Swap？[y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile &>/dev/null
    swapon /swapfile
    if ! grep -q '/swapfile' /etc/fstab; then
      echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    check_pass "Swap 已创建（2G）"
  fi
else
  check_pass "内存/Swap 充足"
fi

echo ""

# ─── 3. PostgreSQL ───

info "━━━ PostgreSQL ━━━"
echo ""

if command -v psql &>/dev/null; then
  PG_VER=$(psql --version | head -1)
  check_pass "已安装：$PG_VER"
else
  check_warn "PostgreSQL 未安装，尝试自动安装..."
  sudo apt-get update -q
  if sudo apt install -y postgresql postgresql-contrib; then
    PG_VER=$(psql --version | head -1)
    check_pass "PostgreSQL 安装成功：$PG_VER"
  else
    check_fail "PostgreSQL 自动安装失败，请手动安装："
    echo "  sudo apt-get update"
    echo "  sudo apt install -y postgresql postgresql-contrib"
  fi
fi

if systemctl is-active --quiet postgresql 2>/dev/null; then
  check_pass "PostgreSQL 正在运行"
else
  check_fail "PostgreSQL 未运行"
  echo "  启动：sudo systemctl start postgresql"
fi

# 检查数据库是否存在
if command -v psql &>/dev/null && systemctl is-active --quiet postgresql 2>/dev/null; then
  # 列出所有数据库
  DB_LIST=$(sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | sed 's/^ *//' | grep -v '^$' | grep -v '^template')
  info "已有数据库：$DB_LIST"

  if echo "$DB_LIST" | grep -qw "$DB_NAME"; then
    check_pass "数据库 '$DB_NAME' 已存在"
    # 列出表
    TABLE_LIST=$(sudo -u postgres psql -d "$DB_NAME" -Atc "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;" 2>/dev/null)
    if [ -n "$TABLE_LIST" ]; then
      TABLE_COUNT=$(echo "$TABLE_LIST" | wc -l)
      info "已有 $TABLE_COUNT 张表：$(echo $TABLE_LIST | tr '\n' ' ')"
    else
      warn "数据库 '$DB_NAME' 中没有表，需要执行迁移"
    fi
  else
    info "数据库 '$DB_NAME' 不存在，正在创建..."
    if sudo -u postgres createdb "$DB_NAME" 2>/dev/null; then
      check_pass "数据库 '$DB_NAME' 已创建"
    else
      check_fail "数据库 '$DB_NAME' 创建失败"
    fi
  fi

  # 执行迁移
  if [ -d "$MIGRATIONS_DIR" ] && sudo -u postgres psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    MIGRATION_COUNT=$(ls "$MIGRATIONS_DIR"/*.sql 2>/dev/null | wc -l)
    if [ "$MIGRATION_COUNT" -gt 0 ]; then
      check_pass "迁移文件就绪（$MIGRATION_COUNT 个 SQL 文件）"
      info "执行迁移请运行：bash db.sh migrate"
    fi
  fi
fi

echo ""

# ─── 4. 配置文件 ───

info "━━━ 配置文件 ━━━"
echo ""

if [ -f "$ENV_FILE" ]; then
  check_pass ".env 文件存在"
  # 检查关键配置项
  if grep -q "DATABASE_URL" "$ENV_FILE"; then
    check_pass "DATABASE_URL 已配置"
    # 验证数据库连接密码是否正确
    DB_URL=$(grep "^DATABASE_URL" "$ENV_FILE" | sed 's/^DATABASE_URL=//' | tr -d ' \r\n')
    if command -v psql &>/dev/null && [ -n "$DB_URL" ]; then
      DB_RESULT=$(timeout 5 psql "$DB_URL" -c "SELECT 1;" 2>&1 || true)
      if echo "$DB_RESULT" | grep -q "1 row"; then
        check_pass "数据库连接验证通过"
      else
        check_warn "数据库连接验证未通过（不影响服务运行）"
      fi
    fi
  else
    check_fail "DATABASE_URL 缺失"
  fi
  if grep -q "JWT_SECRET" "$ENV_FILE"; then
    JWT_VAL=$(grep "JWT_SECRET" "$ENV_FILE" | cut -d'=' -f2)
    if [ ${#JWT_VAL} -lt 16 ]; then
      check_warn "JWT_SECRET 太短，建议至少 32 字符"
    else
      check_pass "JWT_SECRET 已配置（${#JWT_VAL} 字符）"
    fi
  else
    check_fail "JWT_SECRET 缺失"
  fi
else
  check_fail ".env 文件不存在：$ENV_FILE"
  echo "  创建示例："
  echo "    DATABASE_URL=postgres://postgres:密码@localhost:5432/$DB_NAME"
  echo "    JWT_SECRET=\$(openssl rand -hex 32)"
  echo "    SERVER_PORT=$SERVER_PORT"
fi

echo ""

# ─── 5. uploads 目录 ───

info "━━━ 文件存储 ━━━"
echo ""

UPLOADS_DIR="$WORK_DIR/uploads"
if [ -d "$UPLOADS_DIR" ]; then
  check_pass "uploads 目录存在"
else
  check_warn "uploads 目录不存在，将自动创建"
  mkdir -p "$UPLOADS_DIR"
  check_pass "uploads 目录已创建"
fi

echo ""

# ─── 6. 二进制文件 ───

info "━━━ 可执行文件 ━━━"
echo ""

if [ -f "$BINARY_PATH" ]; then
  BINARY_SIZE=$(du -h "$BINARY_PATH" | cut -f1)
  check_pass "二进制文件存在（$BINARY_SIZE）"
  # 检查是否是 Linux 可执行文件
  FILE_TYPE=$(file "$BINARY_PATH" 2>/dev/null || echo "unknown")
  if echo "$FILE_TYPE" | grep -q "ELF"; then
    check_pass "文件类型正确（ELF Linux 可执行文件）"
  else
    check_warn "文件类型异常：$FILE_TYPE"
  fi
else
  check_fail "二进制文件不存在：$BINARY_PATH"
  echo "  请在本地编译后上传：python scripts/deploy/build.py root@$(hostname -I | awk '{print $1}')"
fi

echo ""

# ─── 7. 端口检测 ───

info "━━━ 端口检测 ━━━"
echo ""

if ss -tlnp 2>/dev/null | grep -q ":$SERVER_PORT "; then
  PROC=$(ss -tlnp | grep ":$SERVER_PORT " | awk '{print $NF}')
  PID=$(echo "$PROC" | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2)
  check_warn "端口 $SERVER_PORT 已被占用：$PROC"
  if [ -n "$PID" ]; then
    echo "  关闭占用进程：kill $PID"
    echo "  强制关闭：    kill -9 $PID"
  else
    echo "  查看占用：ss -tlnp | grep :$SERVER_PORT"
    echo "  手动关闭：kill <PID>"
  fi
else
  check_pass "端口 $SERVER_PORT 可用"
fi

echo ""

# ─── 8. 防火墙 ───

info "━━━ 防火墙 ━━━"
echo ""

if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
  if ufw status | grep -q "$SERVER_PORT"; then
    check_pass "ufw 已放行端口 $SERVER_PORT"
  else
    check_warn "ufw 已启用但未放行端口 $SERVER_PORT"
    echo "  放行：sudo ufw allow $SERVER_PORT/tcp"
  fi
else
  check_pass "ufw 未启用（所有端口默认开放）"
fi

check_warn "如果是云服务器，请确认安全组已放行 $SERVER_PORT 端口"

echo ""

# ─── 汇总 ───

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  检测完成：${GREEN}$PASS 通过${NC}  ${YELLOW}$WARN_COUNT 警告${NC}  ${RED}$FAIL_COUNT 失败${NC}"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
  fail "存在 $FAIL_COUNT 个必须修复的问题，请按上方提示处理后重新检测。"
  exit 1
elif [ "$WARN_COUNT" -gt 0 ]; then
  warn "存在 $WARN_COUNT 个警告，建议处理但不影响启动。"
else
  ok "所有检测通过，可以启动服务！"
fi

echo ""
