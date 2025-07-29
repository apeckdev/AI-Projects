#Requires -Version 5.1
# client.ps1 - The Player's Tool

# --- Script-level variables ---
$script:PlayerRole = "Unknown"
$script:PlayerName = "Unknown"
$script:CurrentLevel = 1
$script:CurrentTask = "Connecting..."
$script:CodeContext = "Not yet received."

# --- Helper function to display the current status ---
function Show-CurrentStatus {
    param (
        [int]$Level,
        [string]$Task,
        [string]$Code
    )
    $script:CurrentLevel = $Level
    $script:CurrentTask = $Task
    if (-not [string]::IsNullOrWhiteSpace($Code)) {
        $script:CodeContext = $Code
    }
    Clear-Host
    Write-Host -ForegroundColor White "Player: $script:PlayerName (Role: $script:PlayerRole)"
    Write-Host "---------------------------------"
    Write-Host -ForegroundColor Yellow "Level ${Level}: $Task"
    Write-Host "---------------------------------"
    Write-Host -ForegroundColor White "Relevant Code/Context:"
    Write-Host -ForegroundColor Gray $script:CodeContext
    Write-Host
}

# --- Function for Initial Registration ---
function Register-WithServer {
    param([string]$Name, [string]$ServerIp)
    try {
        $RegClient = [System.Net.Sockets.TcpClient]::new($ServerIp, 9999)
        $RegStream = $RegClient.GetStream()
        $RegReader = [System.IO.StreamReader]::new($RegStream)
        $RegWriter = [System.IO.StreamWriter]::new($RegStream)
        $RegWriter.AutoFlush = $true
        
        $RegWriter.WriteLine($Name)
        $RegWriter.WriteLine($script:PlayerRole)
        $RegWriter.WriteLine("__REGISTER__")
        
        $Response = $RegReader.ReadLine()
        $ResponseParts = $Response.Split('|')
        if ($ResponseParts[0] -eq "REGISTER") {
            $Base64Code = $ResponseParts[3]
            $DecodedCode = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Base64Code))
            Show-CurrentStatus -Level $ResponseParts[1] -Task $ResponseParts[2] -Code $DecodedCode
        }
        $RegClient.Close()
    }
    catch {
        Write-Error "Could not connect to the server at $ServerIp. Please check the IP and that the server is running."
        exit
    }
}

# --- Main Client Logic for Submissions ---
function Submit-ToQuestServer {
    param($Submission, [string]$ServerIp)
    try {
        $Client = [System.Net.Sockets.TcpClient]::new($ServerIp, 9999)
        $Stream = $Client.GetStream()
        $Reader = [System.IO.StreamReader]::new($Stream)
        $Writer = [System.IO.StreamWriter]::new($Stream)
        $Writer.AutoFlush = $true

        $Writer.WriteLine($script:PlayerName)
        $Writer.WriteLine($script:PlayerRole)
        $Writer.WriteLine($Submission) # Submission is now Base64 encoded

        $Response = $Reader.ReadLine()
        if ($Response) {
            $ResponseParts = $Response.Split('|')
            $Status = $ResponseParts[0]
            $Level = $ResponseParts[1]
            $Task = $ResponseParts[2]
            $Message = $ResponseParts[3]
            
            $NewCodeContext = if ($ResponseParts.Count -gt 4) {
                $Base64Code = $ResponseParts[4]
                [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Base64Code))
            } else { "" }

            Show-CurrentStatus -Level $Level -Task $Task -Code $NewCodeContext

            if ($Status -eq "SUCCESS") {
                Write-Host -ForegroundColor Green "[SERVER]: $Message"
            }
            elseif ($Status -eq "WINNER") {
                Write-Host -ForegroundColor Magenta "[SERVER]: $Message"
                exit
            }
            elseif ($Status -eq "ERROR") {
                Write-Error "[SERVER ERROR]: $Message"
            }
            else { # FAILURE
                Write-Host -ForegroundColor Red "[SERVER HINT]: $Message"
            }
        }
        $Client.Close()
    }
    catch { Write-Error "Could not connect to the server at $ServerIp." }
}

# --- Startup ---
Clear-Host
Write-Host -ForegroundColor Yellow "Welcome to AI Code Quest"

# --- Role Selection ---
$validRoles = @("DEV", "QA")
do {
    $chosenRole = Read-Host "Please choose your role (DEV / QA)"
    if ($validRoles -notcontains $chosenRole.ToUpper()) {
        Write-Warning "Invalid role. Please enter DEV or QA."
        $roleIsValid = $false
    } else {
        $script:PlayerRole = $chosenRole.ToUpper()
        $roleIsValid = $true
    }
} while (-not $roleIsValid)

$ServerIp = Read-Host "Enter Server IP (default: 127.0.0.1)"
if ([string]::IsNullOrWhiteSpace($ServerIp)) { $ServerIp = "127.0.0.1" }

$script:PlayerName = Read-Host "Please enter your name"

Register-WithServer -Name $script:PlayerName -ServerIp $ServerIp

# --- Main Game Loop ---
while ($true) {
    Write-Host
    Write-Host -ForegroundColor Cyan "Type your response. Type CLEAR to restart, or DONE to submit."
    $inputLines = [System.Collections.Generic.List[string]]::new()
    $cleared = $false

    while ($true) {
        $line = Read-Host
        
        if ($line.Trim().ToUpper() -eq 'DONE') { break }
        if ($line.Trim().ToUpper() -eq 'CLEAR') {
            Show-CurrentStatus -Level $script:CurrentLevel -Task $script:CurrentTask -Code $script:CodeContext
            Write-Warning "Input cleared. Starting over."
            $cleared = $true
            break
        }
        $inputLines.Add($line)
    }

    if ($cleared) { continue }

    $PlayerInput = $inputLines -join "`n"
    
    if ([string]::IsNullOrWhiteSpace($PlayerInput)) {
        Write-Warning "Submission cannot be empty."
        continue
    }

    Write-Host -ForegroundColor Gray "Submission sent to server for review..."

    # Encode the entire submission to Base64
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($PlayerInput)
    $EncodedInput = [System.Convert]::ToBase64String($Bytes)
    
    Submit-ToQuestServer -Submission $EncodedInput -ServerIp $ServerIp
}
