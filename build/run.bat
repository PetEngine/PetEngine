@echo off

setlocal enableExtensions

REM checking current directory
if not exist "%cd%\%~nx0%" (
    echo [ERROR] You have to call %~nx0% from Pet/build directory.
    echo.
    set /A errorLevel=1
    goto end
)

set CONFIG=%~1

if "%CONFIG%" equ "" set CONFIG=debug

pushd "..\output\windows\%CONFIG%"
    .\engine.exe
popd

:end
exit /B %errorLevel%
endlocal
