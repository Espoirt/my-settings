# 生成日期后缀，例如 20261114_153025
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

# 目标目录（不存在则自动创建）
$destRoot = "F:\Backup"
if (-not (Test-Path $destRoot)) {
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
}

$items = @(
    @{ Source = "C:\Users\Anea\Desktop";    Name = "desktop" },
    @{ Source = "C:\Users\Anea\Documents";  Name = "docu" },
    @{ Source = "C:\Users\Anea\Pictures";   Name = "image" }
)

foreach ($item in $items) {
    if (-not (Test-Path $item.Source)) {
        Write-Warning "源目录不存在，跳过: $($item.Source)"
        continue
    }

    $target = Join-Path $destRoot "$($item.Name)_$stamp.zip"
    Write-Host "正在压缩: $($item.Source)" -ForegroundColor Cyan
    Write-Host "       -> $target"

    try {
        Compress-Archive -Path $item.Source -DestinationPath $target -Force
        $size = [math]::Round((Get-Item $target).Length / 1MB, 2)
        Write-Host "完成，大小 $size MB" -ForegroundColor Green
    } catch {
        Write-Error "压缩失败: $($item.Name) - $($_.Exception.Message)"
    }
}

Write-Host "`n全部任务结束！压缩包保存在 $destRoot" -ForegroundColor Green
