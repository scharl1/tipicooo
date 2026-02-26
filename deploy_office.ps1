$ErrorActionPreference = "Stop"

Write-Host "== Tipicooo Office deploy =="

# 1) Build Flutter web with correct base href
Write-Host "Building web..."
flutter build web --base-href /office/

# 2) Upload to SiteGround via saved WinSCP session
Write-Host "Uploading via WinSCP..."
& "C:\Program Files (x86)\WinSCP\winscp.com" /command `
  "open siteground-office" `
  "synchronize remote -delete build\web /public_html/office" `
  "exit"

Write-Host "Deploy completed."
