#!/bin/sh

echo "🧹 Cleaning all processes..."
pkill -f monitor 2>/dev/null
pkill -f live-stream 2>/dev/null
sleep 3

echo "🔥 Starting load-based monitor..."

LOAD_LIMIT=0.5  # Load average بالای 1.5 = pause
MAIN_PID=0

start_fresh() {
    nice -n 19 ./live-stream -config config.json > /dev/null 2>&1 &
    MAIN_PID=$!
    echo "✅ PID: $MAIN_PID"
}

start_fresh

while true; do
    if ! kill -0 $MAIN_PID 2>/dev/null; then
        echo "💀 Process died, restarting..."
        pkill -f live-stream 2>/dev/null
        start_fresh
        sleep 2
        continue
    fi
    
    # Load average (دقیق‌ترین معیار)
    LOAD=$(cat /proc/loadavg | cut -d' ' -f1)
    LOAD_INT=$(echo $LOAD | cut -d'.' -f1)
    LOAD_DEC=$(echo $LOAD | cut -d'.' -f2 | cut -c1)
    
    # تبدیل به عدد قابل مقایسه (1.5 = 15)
    LOAD_CALC=$((LOAD_INT * 10 + LOAD_DEC))
    LIMIT_CALC=5  # 1.5 load limit
    
    # اطلاعات اضافی
    PROCESSES=$(pgrep -f live-stream | wc -l)
    MEM=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    CONNECTIONS=$(netstat -an 2>/dev/null | grep :3000 | grep ESTABLISHED | wc -l || echo "0")
    
    echo "📊 Load: $LOAD | Proc: $PROCESSES | Mem: $MEM% | Conn: $CONNECTIONS"
    
    if [ "$LOAD_CALC" -ge "$LIMIT_CALC" ]; then
        echo "⏸️ HIGH LOAD! ($LOAD >= $LOAD_LIMIT) - Micro pause 0.2s..."
        
        # pause همه live-stream processes
        PIDS=$(pgrep -f live-stream)
        for pid in $PIDS; do
            kill -STOP $pid 2>/dev/null
        done
        
        sleep 0.6
        
        # resume همه
        for pid in $PIDS; do
            kill -CONT $pid 2>/dev/null
        done
        
        echo "▶️ Resumed! Load should drop now."
        sleep 5  # بیشتر صبر کن تا load پایین بیاد
    fi
    
    sleep 2
done
