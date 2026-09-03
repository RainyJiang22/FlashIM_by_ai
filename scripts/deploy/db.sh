#!/bin/bash
#
# 闪讯 IM — 数据库管理脚本
#
# 用法：
#   ./db.sh status     # 查看数据库状态（表列表、行数）
#   ./db.sh migrate    # 执行迁移（跳过已存在的表）
#   ./db.sh clear      # 删除数据库（危险！）
#   ./db.sh reset      # 删库重建（clear + migrate）
#

# ─── 颜色 ───

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# ─── 配置 ───

MIGRATIONS_DIR="$(pwd)/migrations"
DB_NAME="flash_im"
DB_USER="postgres"

ACTION="${1:-status}"
FORCE="${2:-}"

# ─── 工具函数 ───

psql_run() {
  sudo -u "$DB_USER" psql -d "$DB_NAME" "$@"
}

psql_cmd() {
  sudo -u "$DB_USER" psql "$@"
}

# ─── status：查看数据库状态 ───

do_status() {
  echo ""
  info "━━━ 数据库状态 ━━━"
  echo ""

  # 检查数据库是否存在
  if ! psql_cmd -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    warn "数据库 '$DB_NAME' 不存在"
    return
  fi

  ok "数据库 '$DB_NAME' 存在"
  echo ""

  # 列出所有表及行数
  info "表列表："
  psql_run -c "
    SELECT tablename AS 表名,
           pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS 大小
    FROM pg_tables
    WHERE schemaname = 'public'
    ORDER BY tablename;
  " 2>/dev/null

  echo ""
  info "各表行数："
  psql_run -Atc "
    SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;
  " 2>/dev/null | while read -r tbl; do
    COUNT=$(psql_run -Atc "SELECT COUNT(*) FROM \"$tbl\";" 2>/dev/null)
    printf "  %-30s %s 行\n" "$tbl" "$COUNT"
  done

  echo ""
}

# ─── migrate：执行迁移 ───

do_migrate() {
  echo ""
  info "━━━ 执行数据库迁移 ━━━"
  echo ""

  # 确保数据库存在
  if ! psql_cmd -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    info "数据库 '$DB_NAME' 不存在，正在创建..."
    psql_cmd -c "CREATE DATABASE $DB_NAME;" 2>/dev/null
    ok "数据库已创建"
  fi

  # 确保迁移记录表存在
  psql_run -c "
    CREATE TABLE IF NOT EXISTS _migrations (
      filename TEXT PRIMARY KEY,
      executed_at TIMESTAMP DEFAULT NOW()
    );
  " &>/dev/null

  # 逐个执行迁移（跳过已执行的）
  TOTAL=0
  SUCCESS=0
  SKIPPED=0

  for f in "$MIGRATIONS_DIR"/*.sql; do
    [ -f "$f" ] || continue
    TOTAL=$((TOTAL + 1))
    FILENAME=$(basename "$f")

    # 检查是否已执行过
    ALREADY=$(psql_run -Atc "SELECT 1 FROM _migrations WHERE filename='$FILENAME';" 2>/dev/null)
    if [ "$ALREADY" = "1" ]; then
      SKIPPED=$((SKIPPED + 1))
      info "  $FILENAME（已执行，跳过）"
      continue
    fi

    # 执行迁移
    OUTPUT=$(cat "$f" | psql_run 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ] && ! echo "$OUTPUT" | grep -qi "ERROR"; then
      # 记录已执行
      psql_run -c "INSERT INTO _migrations (filename) VALUES ('$FILENAME');" &>/dev/null
      SUCCESS=$((SUCCESS + 1))
      ok "  $FILENAME"
    else
      warn "  $FILENAME 失败："
      echo "$OUTPUT" | grep -i "ERROR" | head -3 | sed 's/^/    /'
    fi
  done

  echo ""
  ok "迁移完成：$SUCCESS 新执行，$SKIPPED 已跳过（共 $TOTAL 个文件）"
  echo ""
}

# ─── clear：删除数据库 ───

do_clear() {
  echo ""
  warn "━━━ 危险操作：删除数据库 ━━━"
  echo ""
  warn "这将删除数据库 '$DB_NAME' 及其所有数据！"
  echo ""

  if [ "$FORCE" != "-y" ]; then
    read -p "  确认删除？输入数据库名称确认 [$DB_NAME]: " CONFIRM
    echo ""
    if [ "$CONFIRM" != "$DB_NAME" ]; then
      info "已取消"
      return
    fi
  fi

  info "断开所有连接..."
  psql_cmd -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$DB_NAME' AND pid <> pg_backend_pid();" &>/dev/null

  info "删除数据库..."
  psql_cmd -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null
  ok "数据库 '$DB_NAME' 已删除"
}

# ─── reset：删库重建（clear + migrate） ───

do_reset() {
  do_clear
  echo ""
  info "重新创建数据库..."
  psql_cmd -c "CREATE DATABASE $DB_NAME;" 2>/dev/null
  ok "数据库已创建"
  # 确保 postgres 用户密码可用（应用通过密码连接）
  psql_cmd -c "ALTER USER postgres PASSWORD 'postgres';" 2>/dev/null
  ok "postgres 密码已设置为: postgres"
  do_migrate
}

# ─── 主入口 ───

case "$ACTION" in
  status)
    do_status
    ;;
  migrate)
    do_migrate
    ;;
  clear)
    do_clear
    ;;
  reset)
    do_reset
    ;;
  *)
    echo "用法：bash db.sh [status|migrate|clear|reset]"
    echo ""
    echo "  status   查看数据库状态（表列表、行数）"
    echo "  migrate  执行迁移（跳过已存在的表）"
    echo "  clear    删除数据库（危险！）"
    echo "  reset    删库重建（clear + migrate）"
    exit 1
    ;;
esac
