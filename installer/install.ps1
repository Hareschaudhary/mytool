$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo       = "Hareschaudhary/mytool"
$ExeName    = "mytool.exe"
$HashName   = "mytool.exe.sha256"
$InstallDir = "$env:LOCALAPPDATA\Programs\MyTool"
$TempDir    = Join-Path $env:TEMP "mytool-install"

$Release = Invoke-RestMethod `
  "https://api.github.com/repos/$Repo/releases/latest" `
  -Headers @{ "User-Agent" = "mytool-installer" }

$ExeAsset  = $Release.assets | Where-Object { $_.name -eq $ExeName }  | Select-Object -First 1
$HashAsset = $Release.assets | Where-Object { $_.name -eq $HashName } | Select-Object -First 1

if (-not $ExeAsset -or -not $HashAsset) {
    throw "EXE ya SHA256 file GitHub Release mein nahi mili."
}

New-Item -ItemType Directory -Path $TempDir, $InstallDir -Force | Out-Null
$TempExe  = Join-Path $TempDir $ExeName
$TempHash = Join-Path $TempDir $HashName

Invoke-WebRequest -Uri $ExeAsset.browser_download_url  -OutFile $TempExe
Invoke-WebRequest -Uri $HashAsset.browser_download_url -OutFile $TempHash

# SHA-256 verify
$Expected = ((Get-Content $TempHash -Raw).Trim() -split '\s+')[0].ToLower()
$Actual   = (Get-FileHash $TempExe -Algorithm SHA256).Hash.ToLower()

if ($Expected -ne $Actual) {
    Remove-Item $TempDir -Recurse -Force
    throw "SHA-256 mismatch! Expected: $Expected, Got: $Actual. Installation roki gayi."
}
Write-Host "SHA-256 verified: $Actual"

Move-Item $TempExe "$InstallDir\$ExeName" -Force
Remove-Item $TempDir -Recurse -Force

# PATH mein add karo (user level)
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($UserPath -split ';') -notcontains $InstallDir) {
    $NewPath = (@($UserPath -split ';' | Where-Object { $_ }) + $InstallDir) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
}

Write-Host "Installation complete! Naya terminal kholkar run karo: mytool"