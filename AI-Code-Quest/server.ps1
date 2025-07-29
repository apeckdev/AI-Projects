#Requires -Version 5.1
# server.ps1 - The Game Master

param(
    [switch]$Verbose
)

# --- Server Configuration ---
$Config = Get-Content -Raw -Path "po_server_config.json" | ConvertFrom-Json
$Port = $Config.port
$OllamaUrl = "http://localhost:12000/api/generate" # Default Ollama URL
$Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
$PlayerProgress = @{}

# --- Helper Functions ---
function Log-Message {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    $Color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "VERBOSE" { "Cyan" }
        "INPUT"   { "Magenta" }
        default   { "White" }
    }
    
    if ($Level -eq "VERBOSE" -and -not $Verbose) { return }
    
    Write-Host $LogEntry -ForegroundColor $Color
    Add-Content -Path "server.log" -Value $LogEntry
}

function Test-PlayerSubmission {
    param(
        [string]$PlayerSubmission,
        [string]$ValidationCriteria
    )
    $failureResult = [pscustomobject]@{ decision = 'NO'; reasoning = 'AI validation system failed or returned a malformed response.' }

    if ([string]::IsNullOrWhiteSpace($PlayerSubmission)) { 
        return [pscustomobject]@{ decision = 'NO'; reasoning = 'Submission was empty.' }
    }

    # Simplified prompt for better compatibility
    $FinalPrompt = @"
You are an AI evaluator.
Requirement: $ValidationCriteria
Submission: "$PlayerSubmission"

Respond with only a raw JSON object with two keys: "decision" ("YES" or "NO") and "reasoning" (a brief explanation).
"@
    $body = @{ model = "gemma"; prompt = $FinalPrompt; stream = $false } | ConvertTo-Json
    
    Log-Message -Level VERBOSE -Message "Validating submission. Criteria: $ValidationCriteria"
    
    try {
        $response = Invoke-RestMethod -Uri $OllamaUrl -Method Post -Body $body -ContentType "application/json" -TimeoutSec 45
        
        if ($null -eq $response -or -not $response.PSObject.Properties.Name -contains 'response' -or [string]::IsNullOrWhiteSpace($response.response)) {
            Log-Message -Level ERROR -Message "Ollama response was null or did not contain a 'response' field."
            return $failureResult
        }

        # More robust JSON extraction: find the first '{' and last '}'
        $rawText = $response.response
        $firstBrace = $rawText.IndexOf('{')
        $lastBrace = $rawText.LastIndexOf('}')

        if ($firstBrace -eq -1 -or $lastBrace -eq -1 -or $lastBrace -le $firstBrace) {
            Log-Message -Level WARN -Message "AI response did not contain a valid JSON structure. Raw response: $rawText"
            # Fallback to keyword matching if JSON is malformed
            if ($rawText -imatch 'YES') {
                return [pscustomobject]@{ decision = 'YES'; reasoning = 'AI response indicated success but was not valid JSON.' }
            } else {
                return [pscustomobject]@{ decision = 'NO'; reasoning = "AI response was not valid JSON: $rawText" }
            }
        }

        $jsonString = $rawText.Substring($firstBrace, $lastBrace - $firstBrace + 1)
        
        $aiResult = $jsonString | ConvertFrom-Json -ErrorAction Stop
        
        if (-not $aiResult.PSObject.Properties.Name -contains 'decision' -or -not $aiResult.PSObject.Properties.Name -contains 'reasoning') {
            Log-Message -Level ERROR -Message "Parsed JSON from AI is missing required 'decision' or 'reasoning' keys."
            return $failureResult
        }

        return $aiResult
    }
    catch { 
        Log-Message -Level ERROR -Message "Failed during Invoke-RestMethod or JSON parsing. Error: $($_.Exception.Message)"
        if ($response) {
            Log-Message -Level VERBOSE -Message "Raw response was: $($response.response)"
        }
        return $failureResult
    }
}

# --- Main Server Loop ---
try {
    $Listener.Start()
    Log-Message -Message "$($Config.server_name) is running on port $Port. Waiting for players..."
    if ($Verbose) { Log-Message -Message "Verbose logging enabled." -Level VERBOSE }

    while ($true) {
        if ($Listener.Pending()) {
            $Client = $Listener.AcceptTcpClient()
            $Stream = $Client.GetStream()
            $Reader = [System.IO.StreamReader]::new($Stream)
            $Writer = [System.IO.StreamWriter]::new($Stream)
            $Writer.AutoFlush = $true
            
            $PlayerName = $Reader.ReadLine()
            $PlayerRole = $Reader.ReadLine()
            $Base64Submission = $Reader.ReadLine()

            if ($Base64Submission -eq "__REGISTER__") {
                if (-not $PlayerProgress.ContainsKey($PlayerName)) { 
                    $PlayerProgress[$PlayerName] = @{ Role = $PlayerRole; Level = 1 } 
                }
                Log-Message -Message "REGISTER: Player '$PlayerName' (Role: $PlayerRole) has connected."
                
                $InitialTask = $Config.roles.$PlayerRole.tasks.'1'
                $InitialCode = $Config.roles.$PlayerRole.initial_code.'1'
                $Base64InitialCode = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($InitialCode))
                
                $Writer.WriteLine("REGISTER|1|$InitialTask|$Base64InitialCode")
                $Client.Close()
                continue
            }
            
            if (-not $PlayerProgress.ContainsKey($PlayerName)) {
                Log-Message -Message "Rejecting unregistered user." -Level WARN
                $Writer.WriteLine("ERROR|0|Not registered|Please restart the client and register first.")
                $Client.Close()
                continue
            }
            
            $CurrentLevel = $PlayerProgress[$PlayerName].Level
            $RoleConfig = $Config.roles.$PlayerRole
            
            # Decode submission from Base64
            $Submission = try {
                $DecodedBytes = [System.Convert]::FromBase64String($Base64Submission)
                [System.Text.Encoding]::UTF8.GetString($DecodedBytes)
            } catch {
                Log-Message -Level WARN -Message "Could not decode Base64 submission from '$PlayerName'."
                "" # Return empty string on failure
            }
            
            Log-Message -Message "--- New Submission from '$PlayerName' (Level $CurrentLevel) ---"
            Log-Message -Message $Submission -Level INFO

            $Criteria = $RoleConfig.validation_criteria.$CurrentLevel
            if ($null -eq $Criteria) {
                $ErrorMsg = "No validation criteria found for Role '$PlayerRole' at Level '$CurrentLevel'. Check po_server_config.json."
                Log-Message -Message $ErrorMsg -Level ERROR
                $Writer.WriteLine("ERROR|$($CurrentLevel)|$($RoleConfig.tasks.$CurrentLevel)|$($ErrorMsg)")
                $Client.Close()
                continue 
            }

            $aiValidation = Test-PlayerSubmission -PlayerSubmission $Submission -ValidationCriteria $Criteria
            
            Log-Message -Message "AI Decision: $($aiValidation.decision) | Reasoning: $($aiValidation.reasoning)" -Level INFO
            
            $finalDecision = ''
            $prompt = "[INPUT] Player '$PlayerName' | AI Suggests: $($aiValidation.decision). Reasoning: '$($aiValidation.reasoning)'. Do they pass? (y/n)"
            while ($finalDecision -notin @('y', 'n')) {
                $finalDecision = Read-Host -Prompt $prompt
            }
            $Success = ($finalDecision -eq 'y')
            
            if ($Success) {
                Log-Message -Message "Operator marked as PASSED." -Level SUCCESS
                $PlayerProgress[$PlayerName].Level++
                $NewLevel = $PlayerProgress[$PlayerName].Level
                $TaskCount = ($RoleConfig.tasks.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' }).Count

                if ($NewLevel -gt $TaskCount) {
                    $msg = "WINNER|{0}|All tasks complete!|Excellent work! You have completed all tasks for the {1} role." -f $TaskCount, $PlayerRole
                    $Writer.WriteLine($msg)
                } else {
                    $NewTask = $RoleConfig.tasks.$NewLevel.ToString()
                    $NewCode = $RoleConfig.initial_code.$NewLevel.ToString()
                    $Base64NewCode = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($NewCode))
                    $successMessage = "Correct! $($aiValidation.reasoning)"
                    $msg = "SUCCESS|{0}|{1}|{2}|{3}" -f $NewLevel, $NewTask, $successMessage, $Base64NewCode
                    $Writer.WriteLine($msg)
                }
            } else {
                Log-Message -Message "Operator marked as FAILED." -Level WARN
                $CurrentTask = $RoleConfig.tasks.$CurrentLevel.ToString()
                $failureHint = "Not quite. $($aiValidation.reasoning)"
                $msg = "FAILURE|{0}|{1}|{2}|" -f $CurrentLevel, $CurrentTask, $failureHint
                $Writer.WriteLine($msg)
            }
            $Client.Close()
        }
        Start-Sleep -Milliseconds 100
    }
}
catch { Log-Message -Message $_.Exception.Message -Level ERROR }
finally {
    Log-Message -Message "Shutting down server and releasing port $Port."
    $Listener.Stop()
}
