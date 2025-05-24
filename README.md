# Webcam Timelapse Creator / Создатель Таймлапсов с Веб-Камеры

## English Description

### Overview
This project provides a flexible solution for creating timelapse videos from a webcam with support for both landscape (16:9) and portrait (9:16) orientations. It consists of:
- Python scripts for image capture and video processing
- Bash script for easy management
- Support for automatic session management
- Configurable capture intervals and duration

### Features
- **Dual Orientation Support**: Choose between landscape or portrait mode
- **Automatic Video Creation**: Converts captured frames to video automatically
- **Session Management**: Organizes captures by sessions
- **Background Operation**: Runs as a background process
- **Make Video Only Mode**: Create videos from existing frames without capturing new ones
- **Logging**: Detailed logging for monitoring and debugging

### Requirements
- Python 3
- OpenCV (cv2)
- ffmpeg
- Bash

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/webcam-timelapse.git
   cd webcam-timelapse
   ```

2. Set up Python virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install opencv-python
   deactivate
   ```

3. Make the bash script executable:
   ```bash
   chmod +x webcam_timelapse.sh
   ```

### Usage
```bash
./webcam_timelapse.sh [command]

Commands:
  start         Start timelapse capture
  stop          Stop running capture
  restart       Restart the capture process
  status        Show current status
  logs          View logs in real-time
  make-video    Create video from existing frames
  clean-frames  Delete all captured frames
  help          Show this help message
```

When starting, you'll be prompted to select video orientation (landscape or portrait).

### Configuration
Edit the Python scripts to adjust:
- Capture interval (`CAPTURE_INTERVAL`)
- Total duration (`CAPTURE_DURATION`)
- Frame rate (`FPS`)
- Directories for frames and videos

## Описание на Русском

### Обзор
Этот проект предоставляет гибкое решение для создания таймлапсов с веб-камеры с поддержкой как альбомной (16:9), так и портретной (9:16) ориентации. Включает:
- Python-скрипты для захвата изображений и создания видео
- Bash-скрипт для удобного управления
- Поддержку автоматического управления сессиями
- Настраиваемые интервалы съемки и продолжительность

### Возможности
- **Поддержка Двух Ориентаций**: Выбор между альбомным и портретным режимом
- **Автоматическое Создание Видео**: Преобразует снятые кадры в видео
- **Управление Сессиями**: Организация снимков по сессиям
- **Работа в Фоне**: Запуск в фоновом режиме
- **Режим Только Видео**: Создание видео из существующих кадров без новой съемки
- **Логирование**: Подробные логи для мониторинга и отладки

### Требования
- Python 3
- OpenCV (cv2)
- ffmpeg
- Bash

### Установка
1. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/yourusername/webcam-timelapse.git
   cd webcam-timelapse
   ```

2. Настройте виртуальное окружение Python:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install opencv-python
   deactivate
   ```

3. Сделайте bash-скрипт исполняемым:
   ```bash
   chmod +x webcam_timelapse.sh
   ```

### Использование
```bash
./webcam_timelapse.sh [команда]

Команды:
  start         Начать съемку таймлапса
  stop         Остановить текущую съемку
  restart      Перезапустить процесс съемки
  status       Показать текущий статус
  logs         Просматривать логи в реальном времени
  make-video   Создать видео из существующих кадров
  clean-frames Удалить все сохраненные кадры
  help         Показать эту справку
```

При запуске будет предложено выбрать ориентацию видео (альбомная или портретная).

### Настройка
Отредактируйте Python-скрипты для изменения:
- Интервала съемки (`CAPTURE_INTERVAL`)
- Общей продолжительности (`CAPTURE_DURATION`)
- Частоты кадров (`FPS`)
- Директорий для кадров и видео

## License / Лицензия
MIT License / Лицензия MIT
