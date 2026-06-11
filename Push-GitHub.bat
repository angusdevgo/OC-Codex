@echo off
setlocal
title O-C GitHub Sync Tool

set "ROOT_DIR=%~dp0"
set "MAX_PUSH_ATTEMPTS=3"

if not exist "%ROOT_DIR%\.git" (
  echo [ERROR] Git repository not found:
  echo %ROOT_DIR%
  pause
  exit /b 1
)

cd /d "%ROOT_DIR%"

echo.
echo ===================================================
echo                 O-C Git Push Tool
echo ===================================================
echo.

echo [1/4] Checking git status...
echo ---------------------------------------------------
git status -s
echo ---------------------------------------------------
echo.

set "msg=chore: sync local changes"

echo [2/4] Adding files...
git add .
if errorlevel 1 (
  echo [ERROR] git add failed.
  pause
  exit /b 1
)

echo.
echo [3/4] Committing...
git diff --cached --quiet
if errorlevel 1 (
  git -c core.quotepath=false commit -m "%msg%"
  if errorlevel 1 (
    echo [ERROR] git commit failed.
    pause
    exit /b 1
  )
) else (
  echo [INFO] Nothing new to commit, continuing to push existing commits...
)

echo.
echo [4/4] Pushing to GitHub...
set /a PUSH_ATTEMPT=1

:push_retry
git push
if not errorlevel 1 goto push_success

if %PUSH_ATTEMPT% geq %MAX_PUSH_ATTEMPTS% (
  echo [ERROR] git push failed after %MAX_PUSH_ATTEMPTS% attempts. Please check network or GitHub credentials.
  pause
  exit /b 1
)

echo [WARN] Retrying git push... attempt %PUSH_ATTEMPT%/%MAX_PUSH_ATTEMPTS%
set /a PUSH_ATTEMPT+=1
timeout /t 3 /nobreak >nul
goto push_retry

:push_success

echo.
echo ===================================================
echo DONE! O-C successfully pushed to GitHub!
echo ===================================================
echo.
pause
