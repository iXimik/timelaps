#!/bin/bash

# webcam_timelapse.sh - Управление скриптом создания таймлапсов

SCRIPT_DIR="/home/tim/timelaps"
LANDSCAPE_SCRIPT="webcam_timelapse.py"
PORTRAIT_SCRIPT="webcam_timelapse_p.py"
VENV_DIR="$SCRIPT_DIR/venv"
LOG_FILE="$SCRIPT_DIR/webcam_timelapse.log"
PID_FILE="$SCRIPT_DIR/webcam_timelapse.pid"
FRAMES_DIR="/home/tim/fram"
VIDEO_DIR="/home/tim/video2"

# Выбор ориентации видео
select_orientation() {
    PS3='Выберите ориентацию видео: '
    options=("Альбомный (горизонтальный)" "Портретный (вертикальный)" "Отмена")
    select opt in "${options[@]}"
    do
        case $opt in
            "Альбомный (горизонтальный)")
                echo "landscape"
                break
                ;;
            "Портретный (вертикальный)")
                echo "portrait"
                break
                ;;
            "Отмена")
                echo "cancel"
                break
                ;;
            *) echo "Некорректный вариант $REPLY";;
        esac
    done
}

# Проверка наличия необходимых утилит
check_requirements() {
    local missing=()

    # Проверка ffmpeg
    if ! command -v ffmpeg &> /dev/null; then
        missing+=("ffmpeg")
    fi

    # Проверка Python
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo "Ошибка: отсутствуют необходимые компоненты: ${missing[*]}"
        echo "Установите их перед использованием:"
        echo "  sudo apt update && sudo apt install -y ffmpeg python3 python3-venv"
        exit 1
    fi
}

# Настройка виртуального окружения
setup_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        echo "Создание виртуального окружения..."
        python3 -m venv "$VENV_DIR"
        source "$VENV_DIR/bin/activate"
        pip install opencv-python
        deactivate
    fi
}

# Запуск скрипта
start() {
    check_requirements
    setup_venv

    if [ -f "$PID_FILE" ]; then
        if ps -p $(cat "$PID_FILE") > /dev/null; then
            echo "Скрипт уже запущен (PID: $(cat "$PID_FILE"))"
            exit 1
        else
            rm "$PID_FILE"
        fi
    fi

    # Запрашиваем ориентацию только при обычном запуске
    if [ "$1" != "--make-video" ]; then
        echo "Выберите ориентацию видео:"
        orientation=$(select_orientation)
        
        if [ "$orientation" == "cancel" ]; then
            echo "Отмена запуска"
            exit 0
        fi
    else
        # Для режима make-video используем последний выбранный вариант
        if [ -f "$SCRIPT_DIR/last_orientation" ]; then
            orientation=$(cat "$SCRIPT_DIR/last_orientation")
        else
            orientation="landscape" # значение по умолчанию
        fi
    fi

    # Определяем какой скрипт запускать
    if [ "$orientation" == "portrait" ]; then
        SCRIPT_NAME="$PORTRAIT_SCRIPT"
        echo "Выбрана портретная ориентация"
    else
        SCRIPT_NAME="$LANDSCAPE_SCRIPT"
        echo "Выбрана альбомная ориентация"
    fi

    # Сохраняем выбор для следующих запусков
    if [ "$1" != "--make-video" ]; then
        echo "$orientation" > "$SCRIPT_DIR/last_orientation"
    fi

    echo "Запуск скрипта $SCRIPT_NAME..."
    source "$VENV_DIR/bin/activate"
    nohup python3 "$SCRIPT_DIR/$SCRIPT_NAME" "$@" >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    deactivate

    echo "Скрипт запущен (PID: $(cat "$PID_FILE")), логи: $LOG_FILE"
}

# Остановка скрипта
stop() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null; then
            echo "Остановка скрипта (PID: $pid)..."
            kill -SIGINT $pid
            sleep 2
            if ps -p $pid > /dev/null; then
                kill -9 $pid
            fi
            rm "$PID_FILE"
            echo "Скрипт остановлен"
        else
            rm "$PID_FILE"
            echo "PID файл найден, но процесс не запущен"
        fi
    else
        echo "Скрипт не запущен (PID файл не найден)"
    fi
}

# Проверка статуса
status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null; then
            echo "Скрипт работает (PID: $pid)"
            return 0
        else
            echo "Скрипт не работает, но PID файл существует"
            return 1
        fi
    else
        echo "Скрипт не запущен"
        return 1
    fi
}

# Просмотр логов
logs() {
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        echo "Лог-файл не найден: $LOG_FILE"
    fi
}

# Создание однократного видео из существующих снимков
make_video() {
    echo "Создание видео из существующих снимков..."
    start "--make-video"
}

# Очистка всех снимков
clean_frames() {
    read -p "Вы уверены, что хотите удалить все снимки в $FRAMES_DIR? [y/N] " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        rm -f "$FRAMES_DIR"/*.jpg
        echo "Все снимки удалены"
    else
        echo "Отмена"
    fi
}

# Показать помощь
show_help() {
    echo "Использование: $0 {start|stop|restart|status|logs|make-video|clean-frames|help}"
    echo
    echo "Команды:"
    echo "  start         - Запустить скрипт в фоновом режиме"
    echo "  stop          - Остановить скрипт"
    echo "  restart       - Перезапустить скрипт"
    echo "  status        - Показать статус скрипта"
    echo "  logs          - Показать логи в реальном времени"
    echo "  make-video    - Создать видео из существующих снимков (без использования камеры)"
    echo "  clean-frames  - Удалить все снимки"
    echo "  help          - Показать эту справку"
    echo
}

# Основная логика
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        status
        ;;
    logs)
        logs
        ;;
    make-video)
        make_video
        ;;
    clean-frames)
        clean_frames
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Неизвестная команда: $1"
        show_help
        exit 1
        ;;
esac

exit 0
