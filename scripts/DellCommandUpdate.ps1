function Install-DellCommandUpdate {
  function Get-LatestDellCommandUpdate {
    # Set KB URL
    $DellKBURL = 'https://www.dell.com/support/kbdoc/en-us/000177325/dell-command-update'
  
    # Set fallback URL based on architecture
    $Arch = Get-Architecture
    if ($Arch -like 'arm*') { $FallbackDownloadURL = 'https://dl.dell.com/FOLDER11914141M/1/Dell-Command-Update-Windows-Universal-Application_6MK0D_WINARM64_5.4.0_A00.EXE' }
    else { $FallbackDownloadURL = 'https://dl.dell.com/FOLDER12925773M/1/Dell-Command-Update-Windows-Universal-Application_P4DJW_WIN64_5.5.0_A00.EXE' }
  
    # Set headers for Dell website
    $Headers = @{
      'accept'          = 'text/html'
      'accept-encoding' = 'gzip'
      'accept-language' = '*'
      'User-Agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Safari/537.36'
    }
  
    # Attempt to parse Dell website for download page links of latest DCU
    [String]$DellKB = Invoke-WebRequest -UseBasicParsing -Uri $DellKBURL -Headers $Headers -ErrorAction Ignore
    $LinkMatches = @($DellKB | Select-String '(https://www\.dell\.com.+driverid=[a-z0-9]+).+>Dell Command \| Update Windows Universal Application<\/a>' -AllMatches).Matches
    $KBLinks = foreach ($Match in $LinkMatches) { $Match.Groups[1].Value }
  
    # Attempt to parse Dell website for download URLs for latest DCU
    $DownloadURLs = foreach ($Link in $KBLinks) {
      $DownloadPage = Invoke-WebRequest -UseBasicParsing -Uri $Link -Headers $Headers -ErrorAction Ignore
      if ($DownloadPage -match '(https://dl\.dell\.com.+Dell-Command-Update.+\.EXE)') { $Matches[1] }
    }
  
    # Set download URL based on architecture
    if ($Arch -like 'arm*') { $DownloadURL = $DownloadURLs | Where-Object { $_ -like '*winarm*' } }else { $DownloadURL = $DownloadURLs | Where-Object { $_ -notlike '*winarm*' } }
  
    # Revert to fallback URL if unable to retrieve URL from Dell website
    if ($null -eq $DownloadURL) { $DownloadURL = $FallbackDownloadURL }
  
    # Get version from DownloadURL
    $Version = $DownloadURL | Select-String '[0-9]*\.[0-9]*\.[0-9]*' | ForEach-Object { $_.Matches.Value }
  
    return @{
      URL     = $DownloadURL
      Version = $Version
    }
  }
  
  $LatestDellCommandUpdate = Get-LatestDellCommandUpdate
  $Installer = Join-Path -Path $env:TEMP -ChildPath (Split-Path $LatestDellCommandUpdate.URL -Leaf)
  $CurrentVersion = (Get-InstalledApps -DisplayName 'Dell Command | Update for Windows Universal').DisplayVersion
  Write-Output "`nInstalled Dell Command Update: $CurrentVersion"
  Write-Output "Latest Dell Command Update: $($LatestDellCommandUpdate.Version)"

  if ($CurrentVersion -lt $LatestDellCommandUpdate.Version) {

    # Download installer
    Write-Output "`nDell Command Update installation needed"
    Write-Output 'Downloading...'
    
    # Create WebClient with spoofed user agent
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Safari/537.36")
    $wc.DownloadFile($LatestDellCommandUpdate.URL, $Installer)

    # Install DCU
    Write-Output 'Installing...'
    Start-Process -Wait -NoNewWindow -FilePath $Installer -ArgumentList '/s'

    # Confirm installation
    $CurrentVersion = (Get-InstalledApps -DisplayName 'Dell Command | Update for Windows Universal').DisplayVersion
    if ($CurrentVersion -match $LatestDellCommandUpdate.Version) {
      Write-Output "Successfully installed Dell Command Update [$CurrentVersion]`n"
      Remove-Item $Installer -Force -ErrorAction Ignore 
    }
    else {
      Write-Warning "Dell Command Update [$($LatestDellCommandUpdate.Version)] not detected after installation attempt"
      Remove-Item $Installer -Force -ErrorAction Ignore 
      exit 1
    }
  }
  else { Write-Output "`nDell Command Update installation / upgrade not needed`n" }
}
