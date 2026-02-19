@echo off
cd /d "%~dp0"

echo Стан репозиторію:
git status --short

echo.
echo Додавання змін...
git add .

:: Запит коментаря
set "commit_msg="
set /p commit_msg="Введіть опис (Enter для авто-дати): "

:: Формуємо чисту дату для повідомлення
set "auto_msg=Auto-sync EEG-Anorexia: %date% %time%"

echo.
echo Створення коміту...
if "%commit_msg%"=="" (
    git commit -m "%auto_msg%"
) else (
    git commit -m "%commit_msg%"
)

echo.
echo Відправка на GitHub...
:: Спробуємо відправити в поточну гілку, якою б вона не була
git push origin HEAD

echo.
echo Все готово!
pause