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

rmdir /S /Q ..\output ..\intermediates .\.build

:end
exit /B %errorLevel%
endlocal
