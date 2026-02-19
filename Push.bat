@echo off
cd /d "%~dp0"

echo 1. Оновлення даних із хмари (Pull)...
:: Це дозволить уникнути помилки [rejected]
git pull origin main --rebase

echo.
echo 2. Перевірка нових файлів...
git status --short

echo.
echo 3. Додавання змін...
git add .

set "commit_msg="
set /p commit_msg="Введіть опис (Enter для авто-дати): "
set "auto_msg=Research update: %date% %time%"

echo.
echo 4. Створення коміту...
:: Перевіряємо, чи є взагалі що комітити
git diff --quiet --cached
if %errorlevel% neq 0 (
    if "%commit_msg%"=="" (git commit -m "%auto_msg%") else (git commit -m "%commit_msg%")
) else (
    echo Нових змін для запису не знайдено.
)

echo.
echo 5. Відправка на GitHub...
git push origin main

echo.
echo Синхронізацію завершено!
pause