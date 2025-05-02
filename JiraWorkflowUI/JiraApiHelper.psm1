# JiraApiHelper.psm1
# Module for Jira API interactions
# (Content from the previous version is correct)

#Requires -Version 5.1

Function Load-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFilePath
    )
    Write-Verbose "Loading configuration from $ConfigFilePath"
    if (-not (Test-Path $ConfigFilePath)) { [System.Windows.Forms.MessageBox]::Show("Configuration file '$ConfigFilePath' not found.", "Error", 0, 16); return $null }
    try {
        $config = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json
        if ([string]::IsNullOrWhiteSpace($config.JiraUrl) -or [string]::IsNullOrWhiteSpace($config.Email) -or [string]::IsNullOrWhiteSpace($config.ApiToken)) { throw "JiraUrl, Email, or ApiToken missing/empty" }
        $authTokenBytes = [System.Text.Encoding]::UTF8.GetBytes("$($config.Email):$($config.ApiToken)")
        $base64AuthInfo = [System.Convert]::ToBase64String($authTokenBytes)
        if ($null -eq $config.MaxResultsPerQuery -or $config.MaxResultsPerQuery -le 0) { $config.MaxResultsPerQuery = 100; Write-Warning "MaxResults missing/invalid, default 100." }
        Write-Verbose "Configuration loaded successfully."
        return @{ Config = $config; AuthInfo = $base64AuthInfo }
    } catch { [System.Windows.Forms.MessageBox]::Show("Error reading config file '$ConfigFilePath': $($_.Exception.Message)", "Config Error", 0, 16); return $null }
}

Function Get-JiraIssues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$Jql,
        [Parameter(Mandatory = $true)] [PSCustomObject]$Config,
        [Parameter(Mandatory = $true)] [string]$Base64AuthInfo
    )
    if (-not $Config -or -not $Base64AuthInfo) { Write-Error "Config/AuthInfo not provided."; return $null }
    $apiUrl = "$($Config.JiraUrl)/rest/api/2/search"; $headers = @{ "Authorization" = "Basic $Base64AuthInfo"; "Content-Type" = "application/json"; "Accept" = "application/json" }; $body = @{ jql = $Jql; maxResults = $Config.MaxResultsPerQuery; fields = @("summary", "status", "assignee", "updated", "priority", "issuetype", "project") } | ConvertTo-Json
    Write-Verbose "[API] Executing JQL: $Jql"; try { $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body -ContentType "application/json"; Write-Verbose "[API] OK: $($response.total) found (max $($Config.MaxResultsPerQuery) returned)."; return $response.issues } catch { $errorMessage = "[API Error] Fetch failed: $($_.Exception.Message)"; if ($_.Exception.Response) { $statusCode = $_.Exception.Response.StatusCode.value__; $responseBody = "(Read Error)"; try { $responseStream = $_.Exception.Response.GetResponseStream(); $reader = New-Object System.IO.StreamReader($responseStream); $responseBody = $reader.ReadToEnd(); $reader.Close(); $responseStream.Close() } catch { Write-Warning "[API Error] Read fail: $($_.Exception.Message)" }; $errorMessage += "`nStatus: $statusCode`nResponse: $responseBody" }; Write-Error $errorMessage; return $null }
}

Export-ModuleMember -Function Load-Config, Get-JiraIssues
Write-Verbose "JiraApiHelper module loaded."