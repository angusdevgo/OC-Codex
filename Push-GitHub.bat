@echo off
setlocal
title O-C GitHub Sync Tool

set "ROOT_DIR=%~dp0"

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
git push
if errorlevel 1 (
  echo [ERROR] git push failed. Please check network or GitHub credentials.
  pause
  exit /b 1
)

echo.
echo ===================================================
echo DONE! O-C successfully pushed to GitHub!
echo ===================================================
echo.
pause
