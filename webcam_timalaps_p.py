#!/usr/bin/env python3
import os
import time
import cv2
import subprocess
from datetime import datetime
import glob
import signal
import sys
import re

# Настройки
CAPTURE_INTERVAL = 20  # секунд между снимками
CAPTURE_DURATION = 2 * 60 * 60  # 2 часа в секундах
FRAMES_DIR = "/home/tim/fram"
VIDEO_DIR = "/home/tim/video2"
FPS = 25
PORTRAIT_WIDTH = 720  # Ширина для портретного режима
PORTRAIT_HEIGHT = 1280  # Высота для портретного режима (соотношение 9:16)

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
        """Захватывает изображения с веб-камеры в портретном режиме"""
        self.cap = cv2.VideoCapture(0)
        if not self.cap.isOpened():
            # Пробуем альтернативные индексы камеры
            for i in range(3):
                self.cap = cv2.VideoCapture(i)
                if self.cap.isOpened():
                    break
            else:
                raise RuntimeError("Не удалось открыть веб-камеру (пробовали индексы 0-2)")

        # Устанавливаем разрешение (если камера поддерживает)
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, PORTRAIT_HEIGHT)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, PORTRAIT_WIDTH)

        start_time = time.time()
        self.frame_count = 0

        try:
            while not self.should_exit and (time.time() - start_time < CAPTURE_DURATION):
                ret, frame = self.cap.read()
                if not ret:
                    print("Предупреждение: не удалось получить кадр, пропускаем...")
                    time.sleep(1)
                    continue

                # Поворачиваем кадр на 90 градусов для портретного режима
                frame = cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)
                
                # Обрезаем до нужного соотношения сторон
                h, w = frame.shape[:2]
                target_ratio = PORTRAIT_HEIGHT / PORTRAIT_WIDTH
                current_ratio = h / w
                
                if current_ratio > target_ratio:
                    new_h = int(w * target_ratio)
                    offset = (h - new_h) // 2
                    frame = frame[offset:offset+new_h, :]
                elif current_ratio < target_ratio:
                    new_w = int(h / target_ratio)
                    offset = (w - new_w) // 2
                    frame = frame[:, offset:offset+new_w]
                
                frame = cv2.resize(frame, (PORTRAIT_WIDTH, PORTRAIT_HEIGHT))

                # Форматируем номер кадра с ведущими нулями
                frame_num = f"{self.frame_count:04d}"
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"{FRAMES_DIR}/session_{session_id}_frame_{frame_num}_{timestamp}.jpg"

                # Сохраняем изображение
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

                # Ждем до следующего снимка
                for _ in range(CAPTURE_INTERVAL * 10):
                    if self.should_exit:
                        break
                    time.sleep(0.1)
        finally:
            if self.cap and self.cap.isOpened():
                self.cap.release()

        return self.frame_count

    def natural_sort_key(self, filename):
        """Функция для натуральной сортировки файлов по номеру кадра"""
        match = re.search(r'session_\d+_frame_(\d+)_', filename)
        if match:
            return int(match.group(1))
        return 0

    def create_video(self, session_id, frame_count):
        """Создает видео из изображений в правильном порядке"""
        # Получаем все файлы сессии и сортируем их по номеру кадра
        pattern = f"{FRAMES_DIR}/session_{session_id}_frame_*.jpg"
        image_files = sorted(glob.glob(pattern), key=self.natural_sort_key)

        if not image_files:
            raise RuntimeError(f"Не найдены изображения для сессии {session_id}")

        # Ограничиваем количество файлов, если передано frame_count
        if frame_count > 0:
            image_files = image_files[:frame_count]

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
            '-vf', f'scale={PORTRAIT_WIDTH}:{PORTRAIT_HEIGHT}:force_original_aspect_ratio=decrease,pad={PORTRAIT_WIDTH}:{PORTRAIT_HEIGHT}:(ow-iw)/2:(oh-ih)/2,setsar=1',
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

    def run(self):
        """Основной цикл работы"""
        self.ensure_dirs_exist()

        if self.make_video_only:
            sessions = self.find_existing_sessions()
            if not sessions:
                print("Нет доступных сессий для создания видео")
                return

            for session in sessions:
                frame_count = len(glob.glob(f"{FRAMES_DIR}/session_{session}_frame_*.jpg"))
                if frame_count > 0:
                    self.current_session = session
                    self.process_session()
            return

        print(f"Начало сессии {self.current_session}")
        try:
            frame_count = self.capture_images(self.current_session)
            if frame_count > 0:
                self.process_session()
        except Exception as e:
            print(f"Ошибка в сессии {self.current_session}: {str(e)}")
            raise

if __name__ == "__main__":
    timelapse = WebcamTimelapse()
    timelapse.run()
