@echo off
cls

setlocal enableExtensions

REM checking current directory
if not exist "%cd%\%~nx0%" (
    echo [ERROR] You have to call %~nx0% from the build directory.
    echo.
    set /A errorLevel=1
    goto end
)

set CONFIG=%~1
set BACKEND=%~2

if "%CONFIG%"  equ "" set CONFIG=debug
if "%BACKEND%" equ "" set BACKEND=x64

if /I "%CONFIG%" equ "release" (
    set BACKEND=llvm
)

jai -%BACKEND% ./build.jai - %CONFIG%

:end
exit /B %errorLevel%
endlocal
