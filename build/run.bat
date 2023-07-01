@echo off

setlocal enableExtensions

set CONFIG=%~1

if "%CONFIG%" equ "" set CONFIG=debug

pushd "%~dp0%\..\output\windows"
    cd ".\%CONFIG%"
    .\engine.exe
popd

:end
exit /B %errorLevel%
endlocal
