#!/usr/bin/env python3
import os
import time
import cv2
import subprocess
from datetime import datetime
import glob
import signal
import sys

# Настройки
CAPTURE_INTERVAL = 20  # секунд между снимками
CAPTURE_DURATION = 2 * 60 * 60  # 2 часа в секундах
FRAMES_DIR = "/home/tim/fram"
VIDEO_DIR = "/home/tim/video2"
FPS = 25

class WebcamTimelapse:
    def __init__(self):
        self.should_exit = False
        self.current_session = self.find_last_session() + 1
        self.frame_count = 0
        self.cap = None
        self.make_video_only = '--make-video' in sys.argv

        # Обработка сигналов завершения
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)

    def find_last_session(self):
        """Находит номер последней сессии в папке с кадрами"""
        sessions = set()
        for f in glob.glob(f"{FRAMES_DIR}/session_*_frame_*.jpg"):
            try:
                session = int(f.split('_')[1])
                sessions.add(session)
            except (IndexError, ValueError):
                continue
        return max(sessions) if sessions else 0

    def signal_handler(self, signum, frame):
        """Обработчик сигналов завершения"""
        print(f"\nПолучен сигнал {signum}, завершение работы...")
        self.should_exit = True

        if self.cap and self.cap.isOpened():
            self.cap.release()

        if self.frame_count > 0 and not self.make_video_only:
            self.process_session()

        sys.exit(0)

    def ensure_dirs_exist(self):
        """Создает необходимые директории"""
        os.makedirs(FRAMES_DIR, exist_ok=True)
        os.makedirs(VIDEO_DIR, exist_ok=True)

    def capture_images(self, session_id):
        """Захватывает изображения с веб-камеры"""
        self.cap = cv2.VideoCapture(0)
        if not self.cap.isOpened():
            # Пробуем альтернативные индексы камеры
            for i in range(3):
                self.cap = cv2.VideoCapture(i)
                if self.cap.isOpened():
                    break
            else:
                raise RuntimeError("Не удалось открыть веб-камеру (пробовали индексы 0-2)")

        start_time = time.time()
        self.frame_count = 0

        try:
            while not self.should_exit and (time.time() - start_time < CAPTURE_DURATION):
                ret, frame = self.cap.read()
                if not ret:
                    print("Предупреждение: не удалось получить кадр, пропускаем...")
                    time.sleep(1)
                    continue

                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"{FRAMES_DIR}/session_{session_id}_frame_{self.frame_count}_{timestamp}.jpg"

                # Пробуем сохранить несколько раз при ошибке
                for attempt in range(3):
                    try:
                        cv2.imwrite(filename, frame)
                        if os.path.exists(filename):
                            break
                    except Exception as e:
                        if attempt == 2:
                            raise RuntimeError(f"Не удалось сохранить кадр: {str(e)}")
                        time.sleep(0.1)

                self.frame_count += 1

                # Ждем до следующего снимка с проверкой флага выхода
                for _ in range(CAPTURE_INTERVAL * 10):
                    if self.should_exit:
                        break
                    time.sleep(0.1)
        finally:
            if self.cap and self.cap.isOpened():
                self.cap.release()

        return self.frame_count

    def create_video(self, session_id, frame_count):
        """Создает видео из изображений"""
        image_files = []
        for i in range(frame_count):
            pattern = f"{FRAMES_DIR}/session_{session_id}_frame_{i}_*.jpg"
            matching_files = sorted(glob.glob(pattern))
            if matching_files:
                image_files.append(matching_files[0])

        if not image_files:
            raise RuntimeError(f"Не найдены изображения для сессии {session_id}")

        list_file = os.path.join(FRAMES_DIR, f"ffmpeg_list_{session_id}.txt")
        with open(list_file, 'w') as f:
            for img in image_files:
                f.write(f"file '{os.path.abspath(img)}'\nduration {1/float(FPS)}\n")

        output_file = os.path.join(VIDEO_DIR, f"out{session_id}.mp4")

        cmd = [
            'ffmpeg',
            '-f', 'concat',
            '-safe', '0',
            '-i', list_file,
            '-r', str(FPS),
            '-c:v', 'libx264',
            '-pix_fmt', 'yuv420p',
            '-crf', '23',
            '-preset', 'fast',
            '-y',
            output_file
        ]

        try:
            subprocess.run(cmd, check=True, stderr=subprocess.PIPE)
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Ошибка ffmpeg: {e.stderr.decode()}")
        finally:
            if os.path.exists(list_file):
                os.remove(list_file)

        return output_file

    def cleanup_images(self, session_id):
        """Удаляет изображения после создания видео"""
        pattern = f"{FRAMES_DIR}/session_{session_id}_frame_*.jpg"
        for file in glob.glob(pattern):
            try:
                os.remove(file)
            except OSError as e:
                print(f"Не удалось удалить файл {file}: {e}")

    def process_session(self):
        """Обрабатывает текущую сессию (создает видео и чистит файлы)"""
        if self.frame_count > 0:
            print(f"Создание видео для сессии {self.current_session}...")
            try:
                video_path = self.create_video(self.current_session, self.frame_count)
                print(f"Видео создано: {video_path}")
                self.cleanup_images(self.current_session)
                print(f"Изображения сессии {self.current_session} удалены")
            except Exception as e:
                print(f"Ошибка при создании видео: {str(e)}")

    def find_existing_sessions(self):
        """Находит все существующие сессии снимков"""
        sessions = set()
        for f in glob.glob(f"{FRAMES_DIR}/session_*_frame_*.jpg"):
            try:
                session = int(f.split('_')[1])
                sessions.add(session)
            except (IndexError, ValueError):
                continue
        return sorted(sessions)

    def run_make_video_mode(self):
        """Режим только создания видео из существующих снимков"""
        sessions = self.find_existing_sessions()
        if not sessions:
            print("Не найдено ни одной сессии снимков для обработки")
            return

        for session in sessions:
            frame_count = len(glob.glob(f"{FRAMES_DIR}/session_{session}_frame_*.jpg"))
            if frame_count > 0:
                print(f"Обработка сессии {session} ({frame_count} кадров)...")
                try:
                    video_path = self.create_video(session, frame_count)
                    print(f"Видео создано: {video_path}")
                except Exception as e:
                    print(f"Ошибка при обработке сессии {session}: {str(e)}")

    def run(self):
        """Основной цикл программы"""
        self.ensure_dirs_exist()

        if self.make_video_only:
            self.run_make_video_mode()
            return

        while not self.should_exit:
            print(f"Начало сессии {self.current_session} - захват изображений...")
            try:
                self.frame_count = self.capture_images(self.current_session)
                self.process_session()
            except Exception as e:
                print(f"Критическая ошибка: {str(e)}")
                if self.cap and self.cap.isOpened():
                    self.cap.release()
                time.sleep(5)  # Пауза перед повторной попыткой

            self.current_session += 1
            self.frame_count = 0

if __name__ == "__main__":
    app = WebcamTimelapse()
    app.run()
tim@tim2:~/timelaps$ cat webcam_timelapse.sh
#!/bin/bash

# webcam_timelapse.sh - Управление скриптом создания таймлапсов

SCRIPT_DIR="/home/tim/timelaps"
SCRIPT_NAME="webcam_timelapse.py"
VENV_DIR="$SCRIPT_DIR/venv"
LOG_FILE="$SCRIPT_DIR/webcam_timelapse.log"
PID_FILE="$SCRIPT_DIR/webcam_timelapse.pid"
FRAMES_DIR="/home/tim/fram"
VIDEO_DIR="/home/tim/video2"

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

    echo "Запуск скрипта..."
    source "$VENV_DIR/bin/activate"
    nohup python3 "$SCRIPT_DIR/$SCRIPT_NAME" >> "$LOG_FILE" 2>&1 &
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
    source "$VENV_DIR/bin/activate"
    python3 "$SCRIPT_DIR/$SCRIPT_NAME" --make-video
    deactivate
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
