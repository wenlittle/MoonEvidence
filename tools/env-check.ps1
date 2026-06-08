param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Get-ToolStatus {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string[]]$VersionArgs = @("--version")
  )

  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd -and $Name -eq "moon") {
    $candidatePaths = @(
      "D:\Programming_Language\MoonBit\bin\moon.exe",
      (Join-Path $HOME ".moon\bin\moon.exe")
    )
    foreach ($candidatePath in $candidatePaths) {
      if (Test-Path $candidatePath) {
        $cmd = [PSCustomObject]@{
          Source = $candidatePath
        }
        break
      }
    }
  }
  if (-not $cmd) {
    return [PSCustomObject]@{
      name = $Name
      found = $false
      path = $null
      version = $null
    }
  }

  $version = $null
  try {
    $version = (& $cmd.Source @VersionArgs 2>&1 | Select-Object -First 1) -join " "
  } catch {
    $version = "version check failed: $($_.Exception.Message)"
  }

  [PSCustomObject]@{
    name = $Name
    found = $true
    path = $cmd.Source
    version = $version
  }
}

function Test-Url {
  param([Parameter(Mandatory = $true)][string]$Url)

  $lastError = $null
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
      $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 20
      return [PSCustomObject]@{
        url = $Url
        ok = $true
        status = [int]$response.StatusCode
        length = $response.Content.Length
        attempts = $attempt
      }
    } catch {
      $lastError = $_.Exception.Message
      Start-Sleep -Seconds 1
    }
  }

  [PSCustomObject]@{
    url = $Url
    ok = $false
    status = $null
    length = $null
    attempts = 3
    error = $lastError
  }
}

$result = [PSCustomObject]@{
  checked_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
  tools = @(
    (Get-ToolStatus -Name "git"),
    (Get-ToolStatus -Name "node"),
    (Get-ToolStatus -Name "npm"),
    (Get-ToolStatus -Name "moon" -VersionArgs @("version"))
  )
  network = @(
    (Test-Url -Url "https://mooncakes.io/api/v0/modules"),
    (Test-Url -Url "https://www.moonbitlang.com/download/")
  )
}

if ($Json) {
  $result | ConvertTo-Json -Depth 5
} else {
  $result.tools | Format-Table -AutoSize
  $result.network | Format-Table -AutoSize
}
