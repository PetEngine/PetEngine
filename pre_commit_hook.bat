"C:\Program Files\Git\bin\git.exe" diff --cached --name-status | findstr /S /I /C:"@DoNotCommit" *.jai
if %errorLevel% equ 0 (
    exit /B 1
) else (
    exit /B 0
)
