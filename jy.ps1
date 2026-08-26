# 切换到 D 盘的 dddd 目录
Set-Location -Path "D:\dddd"

# 激活 Python 虚拟环境
& ".\.venv\Scripts\Activate.ps1"

# 启动 Jupyter Notebook
jupyter notebook

# 暂停（等待用户按任意键）
Read-Host -Prompt "按任意键继续..."