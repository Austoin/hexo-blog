# PowerShell 脚本：将 E:\PPT 目录下的所有 PPT 文件转换为 PDF

$sourceDir = "E:\PPT"
$outputDir = "E:\PPT\PDF"

# 创建输出目录
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# 获取所有 PPT 文件
$pptFiles = Get-ChildItem -Path $sourceDir -Filter "*.pptx"

if ($pptFiles.Count -eq 0) {
    Write-Host "未找到任何 PPTX 文件"
    exit
}

Write-Host "找到 $($pptFiles.Count) 个 PPT 文件"

# 创建 PowerPoint 应用程序对象
try {
    $powerpoint = New-Object -ComObject PowerPoint.Application
    $powerpoint.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
    
    foreach ($file in $pptFiles) {
        Write-Host "正在转换: $($file.Name)"
        
        $presentation = $powerpoint.Presentations.Open($file.FullName)
        $pdfPath = Join-Path $outputDir ($file.BaseName + ".pdf")
        
        # 保存为 PDF (格式代码 32 表示 PDF)
        $presentation.SaveAs($pdfPath, 32)
        $presentation.Close()
        
        Write-Host "已完成: $($file.BaseName).pdf"
    }
    
    $powerpoint.Quit()
    Write-Host "`n转换完成！PDF 文件保存在: $outputDir"
    
} catch {
    Write-Host "错误: $_"
    Write-Host "请确保已安装 Microsoft PowerPoint"
} finally {
    # 释放 COM 对象
    if ($powerpoint) {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($powerpoint) | Out-Null
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}
