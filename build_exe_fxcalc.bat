@echo off
setlocal EnableDelayedExpansion
title FX Calc – EXE Builder v1.x

echo.
echo ============================================================
echo   FX Calc  –  Portable EXE Builder v1.x
echo ============================================================
echo.

cd /d "%~dp0"

python --version >nul 2>&1
if errorlevel 1 (
    echo [FEHLER] Python nicht gefunden!
    pause & exit /b 1
)
for /f "tokens=*" %%v in ('python --version 2^>^&1') do set PYVER=%%v
echo [OK]  %PYVER% gefunden

python -c "import PyInstaller" >nul 2>&1
if errorlevel 1 (
    echo [INFO] PyInstaller wird installiert...
    pip install pyinstaller --quiet
)
for /f "tokens=*" %%v in ('python -c "import PyInstaller; print(PyInstaller.__version__)"') do set PIVER=%%v
echo [OK]  PyInstaller %PIVER% bereit

:: Icon erstellen falls nicht vorhanden
if not exist "fx-calc.ico" (
    if exist "fx-calc-256.png" (
        echo [INFO] fx-calc.ico wird erstellt...
        python -c "from PIL import Image; img=Image.open('fx-calc-256.png').convert('RGBA'); img.save('fx-calc.ico',format='ICO',sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])"
    )
)

set ICO_ARG=
set ICO_DATA_ARG=
if exist "fx-calc.ico" (
    echo [OK]  fx-calc.ico gefunden
    set ICO_ARG=--icon="fx-calc.ico"
    set ICO_DATA_ARG=--add-data "fx-calc.ico;."
) else (
    echo [WARN] fx-calc.ico nicht gefunden – kein Icon
)

if exist "build"              rmdir /s /q "build"
if exist "dist\FXCalc"        rmdir /s /q "dist\FXCalc"

echo.
echo [BUILD] Starte PyInstaller...
echo         (Kann 2-4 Minuten dauern)
echo.

python -m PyInstaller ^
    --noconfirm ^
    --onedir ^
    --windowed ^
    --name "FXCalc" ^
    %ICO_ARG% ^
    %ICO_DATA_ARG% ^
    --hidden-import "PyQt6.QtCore" ^
    --hidden-import "PyQt6.QtGui" ^
    --hidden-import "PyQt6.QtWidgets" ^
    --hidden-import "yfinance" ^
    --hidden-import "pandas" ^
    --hidden-import "numpy" ^
    --hidden-import "requests" ^
    --hidden-import "urllib3" ^
    --hidden-import "charset_normalizer" ^
    --hidden-import "certifi" ^
    --collect-all "yfinance" ^
    --collect-all "PyQt6" ^
    currency_converter.py

if errorlevel 1 (
    echo [FEHLER] PyInstaller fehlgeschlagen!
    pause & exit /b 1
)

if exist "fx-calc.ico" copy /y "fx-calc.ico" "dist\FXCalc\" >nul
echo [OK]  Icon in EXE-Ordner kopiert

(
echo @echo off
echo cd /d "%%~dp0"
echo start "" "FXCalc.exe"
) > "dist\FXCalc\FX Calc starten.bat"

echo.
echo ============================================================
echo   BUILD ERFOLGREICH!
echo   Ordner: %~dp0dist\FXCalc\
echo   Starten: FXCalc.exe
echo ============================================================
echo.
pause
