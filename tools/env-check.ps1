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

  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 20
    return [PSCustomObject]@{
      url = $Url
      ok = $true
      status = [int]$response.StatusCode
      length = $response.Content.Length
    }
  } catch {
    return [PSCustomObject]@{
      url = $Url
      ok = $false
      status = $null
      length = $null
      error = $_.Exception.Message
    }
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

