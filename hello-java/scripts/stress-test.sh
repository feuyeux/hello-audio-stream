#!/bin/bash

# =============================================================================
#                    Java 音频流服务 - 压力测试脚本
# =============================================================================
#
# 【脚本功能】
#   本脚本用于对 Java 音频流服务端进行压力测试，通过动态增加并发客户端数量
#   来摸底服务端能支撑的最大并发连接数，评估服务端的性能极限。
#
# 【测试流程】
#   1. 使用指定的 JVM 内存参数启动服务端
#   2. 从最小并发数开始，逐步增加客户端数量
#   3. 每个并发级别持续运行指定时间
#   4. 记录成功/失败的连接数，评估服务端性能
#
# 【使用方法】
#   ./stress-test.sh [选项]
#
# 【可配置参数】
#   可通过环境变量或修改脚本中的配置区域来自定义测试参数
#
# 【依赖条件】
#   - Java 17+ (支持 --enable-preview)
#   - 已构建的服务端和客户端 JAR 包（脚本会自动检测并构建）
#   - 音频测试文件: audio/input/hello.opus
#
# =============================================================================

# 注意：不使用 set -e，因为某些命令（如 pgrep、算术运算）可能返回非零状态
# 脚本会在关键步骤手动检查错误

# -----------------------------------------------------------------------------
# 脚本路径初始化
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# -----------------------------------------------------------------------------
# 【配置区域】- 可根据测试需求调整以下参数
# -----------------------------------------------------------------------------

# 服务端配置
SERVER_PORT=${SERVER_PORT:-8080}                    # 服务端监听端口
SERVER_PATH=${SERVER_PATH:-/audio}                  # WebSocket 路径
AUDIO_FILE="${AUDIO_FILE:-../../audio/input/hello.opus}"  # 测试用音频文件

# JVM 内存配置 (用于测试服务端在不同内存限制下的表现)
# -Xms: 初始堆内存大小
# -Xmx: 最大堆内存大小
# -XX:+UseG1GC: 使用 G1 垃圾回收器（适合大堆内存和低延迟场景）
SERVER_JVM_OPTS="${SERVER_JVM_OPTS:--Xms512m -Xmx2g -XX:+UseG1GC}"

# 并发测试配置
MIN_CONCURRENCY=${MIN_CONCURRENCY:-1}              # 起始并发客户端数
MAX_CONCURRENCY=${MAX_CONCURRENCY:-100}            # 最大并发客户端数
CONCURRENCY_STEP=${CONCURRENCY_STEP:-5}            # 每次增加的并发数
STEP_DURATION=${STEP_DURATION:-10}                 # 每个并发级别持续时间（秒）

# 客户端 JVM 配置（每个客户端进程的内存设置）
CLIENT_JVM_OPTS="${CLIENT_JVM_OPTS:--Xms64m -Xmx256m}"

# 内存阈值配置（当堆内存使用率达到此百分比时停止测试）
MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-90}

# 日志目录配置
LOG_DIR="${LOG_DIR:-/tmp/stress-test-$(date +%Y%m%d_%H%M%S)}"

# -----------------------------------------------------------------------------
# 【清理函数】- 测试结束或中断时执行清理操作
# -----------------------------------------------------------------------------
cleanup() {
    echo ""
    echo "=============================================="
    echo "  正在清理测试环境..."
    echo "=============================================="
    
    # 停止服务端进程
    if [ -n "$SERVER_PID" ]; then
        echo "  - 停止服务端 (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
    fi
    
    # 停止所有客户端进程
    echo "  - 停止所有客户端进程..."
    pkill -f "audio-stream-client.*jar" 2>/dev/null || true
    
    # 等待进程完全退出
    wait 2>/dev/null || true
    
    echo "  - 清理完成"
    echo ""
}

# 注册信号处理器，确保脚本退出时清理资源
trap cleanup EXIT INT TERM

# -----------------------------------------------------------------------------
# 【辅助函数】- 打印带时间戳的日志
# -----------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# -----------------------------------------------------------------------------
# 【主流程开始】
# -----------------------------------------------------------------------------

echo "=============================================="
echo "      Java 音频流服务 - 压力测试"
echo "=============================================="
echo ""
echo "【测试配置】"
echo "  音频文件:       $AUDIO_FILE"
echo "  服务端 JVM:     $SERVER_JVM_OPTS"
echo "  客户端 JVM:     $CLIENT_JVM_OPTS"
echo "  服务端地址:     ws://localhost:$SERVER_PORT$SERVER_PATH"
echo "  并发范围:       $MIN_CONCURRENCY → $MAX_CONCURRENCY (步长: $CONCURRENCY_STEP)"
echo "  每级持续时间:   ${STEP_DURATION}秒"
echo "  日志目录:       $LOG_DIR"
echo ""

# 创建日志目录
mkdir -p "$LOG_DIR"

# -----------------------------------------------------------------------------
# 【步骤1】检查并构建服务端 JAR
# -----------------------------------------------------------------------------
log "【步骤1】检查服务端 JAR 包..."

cd audio-stream-server
JAR_SERVER=$(ls target/audio-stream-server*.jar 2>/dev/null | grep -v original | head -1)
if [ -z "$JAR_SERVER" ]; then
    log "  服务端 JAR 未找到，正在构建..."
    bash "$SCRIPT_DIR/build-server.sh"
    JAR_SERVER=$(ls target/audio-stream-server*.jar 2>/dev/null | grep -v original | head -1)
fi
JAR_SERVER="$(pwd)/$JAR_SERVER"
log "  服务端 JAR: $JAR_SERVER"

# -----------------------------------------------------------------------------
# 【步骤2】检查并构建客户端 JAR
# -----------------------------------------------------------------------------
log "【步骤2】检查客户端 JAR 包..."

cd ../audio-stream-client
JAR_CLIENT=$(ls target/audio-stream-client*.jar 2>/dev/null | grep -v original | head -1)
if [ -z "$JAR_CLIENT" ]; then
    log "  客户端 JAR 未找到，正在构建..."
    bash "$SCRIPT_DIR/build-client.sh"
    JAR_CLIENT=$(ls target/audio-stream-client*.jar 2>/dev/null | grep -v original | head -1)
fi
JAR_CLIENT="$(pwd)/$JAR_CLIENT"
log "  客户端 JAR: $JAR_CLIENT"

# -----------------------------------------------------------------------------
# 【步骤3】启动服务端
# -----------------------------------------------------------------------------
log "【步骤3】启动服务端 (端口: $SERVER_PORT)..."

cd "$PROJECT_ROOT/audio-stream-server"
java $SERVER_JVM_OPTS --enable-preview -jar "$JAR_SERVER" "$SERVER_PORT" "$SERVER_PATH" > "$LOG_DIR/server.log" 2>&1 &
SERVER_PID=$!

# 等待服务端启动完成
log "  等待服务端启动..."
sleep 3

# 检查服务端是否成功启动
if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo ""
    echo "【错误】服务端启动失败！"
    echo "服务端日志："
    cat "$LOG_DIR/server.log"
    exit 1
fi

log "  服务端启动成功 (PID: $SERVER_PID)"
echo ""

# -----------------------------------------------------------------------------
# 【步骤4】执行并发压力测试
# -----------------------------------------------------------------------------

# 统计变量
total_started=0      # 已启动的客户端总数
total_success=0      # 成功完成的客户端数
total_failed=0       # 失败的客户端数
peak_active=0        # 峰值活跃连接数
limit_reason=""      # 测试停止原因（空表示正常完成所有级别）

log "【步骤4】开始并发压力测试（内存阈值: ${MEMORY_THRESHOLD}%）..."
echo ""

# 遍历每个并发级别
for concurrency in $(seq $MIN_CONCURRENCY $CONCURRENCY_STEP $MAX_CONCURRENCY); do
    echo "=============================================="
    echo "  测试并发级别: $concurrency"
    echo "=============================================="

    # 记录当前批次的客户端 PID
    client_pids=()
    
    # 启动指定数量的客户端
    for i in $(seq 1 $concurrency); do
        log "  启动客户端 #$i/$concurrency..."
        java $CLIENT_JVM_OPTS --enable-preview -jar "$JAR_CLIENT" \
            --server "ws://localhost:$SERVER_PORT$SERVER_PATH" \
            --input "$AUDIO_FILE" \
            > "$LOG_DIR/client_${concurrency}_${i}.log" 2>&1 &
        client_pids+=($!)
        total_started=$((total_started + 1))
    done

    log "  已启动 $concurrency 个客户端，等待 ${STEP_DURATION} 秒..."
    sleep $STEP_DURATION

    # 统计当前活跃的客户端连接数
    active_count=$(pgrep -f "audio-stream-client.*jar" 2>/dev/null | wc -l || echo 0)
    log "  当前活跃客户端: $active_count"
    
    # 更新峰值记录
    if [ "$active_count" -gt "$peak_active" ]; then
        peak_active=$active_count
    fi

    # 检查服务端是否仍在运行
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo ""
        echo "【警告】服务端进程已终止！可能已达到性能极限。"
        echo "当前并发级别: $concurrency"
        limit_reason="服务端进程崩溃"
        break
    fi

    # 显示服务端内存使用情况（堆内 + 堆外）并检测是否达到阈值
    if command -v jstat &> /dev/null; then
        # 获取堆内存使用（单位：KB）
        # jstat -gc 输出: S0U S1U EU OU MU ... 
        # 堆内存 = S0U + S1U + EU + OU (Survivor0 + Survivor1 + Eden + Old)
        heap_info=$(jstat -gc "$SERVER_PID" 2>/dev/null | tail -1)
        if [ -n "$heap_info" ]; then
            heap_used_kb=$(echo "$heap_info" | awk '{printf "%.0f", $4 + $6 + $8 + $10}')
            heap_used_mb=$((heap_used_kb / 1024))
            
            # 获取堆最大容量（单位：KB）
            # S0C + S1C + EC + OC = 总堆容量
            heap_max_kb=$(echo "$heap_info" | awk '{printf "%.0f", $3 + $5 + $7 + $9}')
            heap_max_mb=$((heap_max_kb / 1024))
            
            # 计算堆内存使用率
            if [ "$heap_max_mb" -gt 0 ]; then
                heap_percent=$((heap_used_mb * 100 / heap_max_mb))
            else
                heap_percent=0
            fi
            
            # 获取进程总内存 RSS（包含堆内+堆外，单位：KB）
            rss_kb=$(ps -o rss= -p "$SERVER_PID" 2>/dev/null | tr -d ' ')
            if [ -n "$rss_kb" ]; then
                rss_mb=$((rss_kb / 1024))
                # 堆外内存 ≈ RSS - 堆内存
                off_heap_mb=$((rss_mb - heap_used_mb))
                [ "$off_heap_mb" -lt 0 ] && off_heap_mb=0
                log "  服务端内存: 堆内=${heap_used_mb}MB/${heap_max_mb}MB(${heap_percent}%), 堆外≈${off_heap_mb}MB, 总RSS=${rss_mb}MB"
            else
                log "  服务端内存: 堆内=${heap_used_mb}MB/${heap_max_mb}MB(${heap_percent}%)"
            fi
            
            # 检查内存是否达到阈值（90%）
            if [ "$heap_percent" -ge "$MEMORY_THRESHOLD" ]; then
                echo ""
                echo "【警告】堆内存使用率达到 ${heap_percent}%，超过阈值 ${MEMORY_THRESHOLD}%！"
                echo "当前并发级别: $concurrency"
                limit_reason="堆内存达到${heap_percent}%阈值"
                break
            fi
        fi
    fi

    # 继续下一个并发级别（保持当前客户端运行以模拟持续负载）
    sleep 2
done

echo ""
echo "=============================================="
echo "  压力测试完成，正在收集结果..."
echo "=============================================="

# -----------------------------------------------------------------------------
# 【步骤5】收集并分析测试结果
# -----------------------------------------------------------------------------
log "【步骤5】分析测试结果..."

# 等待所有客户端完成最后的传输
log "  等待客户端完成传输..."
sleep 5

# 统计成功和失败的客户端数
success_count=0
failed_count=0

for log_file in "$LOG_DIR"/client_*.log; do
    if [ -f "$log_file" ]; then
        # 检查日志中是否包含错误关键字
        if grep -qiE "Exception|Error|Failed|Timeout|Connection refused" "$log_file" 2>/dev/null; then
            failed_count=$((failed_count + 1))
            # 可选：记录失败的日志文件名
            echo "  [失败] $log_file" >> "$LOG_DIR/failed_clients.txt"
        else
            success_count=$((success_count + 1))
        fi
    fi
done

# -----------------------------------------------------------------------------
# 【步骤6】输出测试报告
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "        压 力 测 试 报 告"
echo "=============================================="
echo ""
echo "【测试配置】"
echo "  服务端 JVM 参数:  $SERVER_JVM_OPTS"
echo "  客户端 JVM 参数:  $CLIENT_JVM_OPTS"
echo "  并发范围:         $MIN_CONCURRENCY → $MAX_CONCURRENCY"
echo "  步长:             $CONCURRENCY_STEP"
echo "  每级持续时间:     ${STEP_DURATION}秒"
echo "  内存阈值:         ${MEMORY_THRESHOLD}%"
echo ""
echo "【测试结果】"
if [ -n "$limit_reason" ]; then
    echo "  ⚠ 停止原因:       $limit_reason"
else
    echo "  ✓ 完成状态:       正常完成所有并发级别"
fi
echo "  启动客户端总数:   $total_started"
echo "  成功完成:         $success_count"
echo "  失败数量:         $failed_count"
echo "  峰值活跃连接:     $peak_active"
echo ""

# 计算成功率
if [ "$total_started" -gt 0 ]; then
    success_rate=$((success_count * 100 / total_started))
    echo "  成功率:           ${success_rate}%"
fi

echo ""
echo "【日志文件位置】"
echo "  服务端日志:       $LOG_DIR/server.log"
echo "  客户端日志:       $LOG_DIR/client_*.log"
if [ -f "$LOG_DIR/failed_clients.txt" ]; then
    echo "  失败列表:         $LOG_DIR/failed_clients.txt"
fi
echo ""

# 显示服务端最后的日志片段
echo "【服务端日志（最后 20 行）】"
echo "----------------------------------------------"
tail -20 "$LOG_DIR/server.log" 2>/dev/null || echo "  (无日志)"
echo "----------------------------------------------"

# 如果有失败的客户端，显示一个失败示例
if [ "$failed_count" -gt 0 ]; then
    echo ""
    echo "【失败示例日志】"
    echo "----------------------------------------------"
    first_failed=$(head -1 "$LOG_DIR/failed_clients.txt" 2>/dev/null | sed 's/.*\] //')
    if [ -n "$first_failed" ] && [ -f "$first_failed" ]; then
        tail -10 "$first_failed"
    fi
    echo "----------------------------------------------"
fi

echo ""
log "测试完成！等待 5 秒后清理..."
sleep 5

# 清理操作由 trap 自动执行
