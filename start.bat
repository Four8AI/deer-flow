@echo off

rem 启动后端服务
echo 启动后端服务...
start "DeerFlow Backend" /d "backend" cmd /c "python -m uv run langgraph dev --no-browser --no-reload --n-jobs-per-worker 10"

rem 等待后端服务启动
echo 等待后端服务启动...
timeout /t 5 /nobreak >nul

rem 启动前端服务
echo 启动前端服务...
start "DeerFlow Frontend" /d "frontend" cmd /c "pnpm dev"

echo 服务启动完成！
echo 后端服务地址: http://localhost:8001
echo 前端服务地址: http://localhost:3000
echo 按任意键退出...
pause >nul