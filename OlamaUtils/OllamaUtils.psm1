#Requires -Version 5.1
<#
.SYNOPSIS
Provides PowerShell functions to interact with the Ollama REST API.

.DESCRIPTION
This module contains functions for generating text, managing models (listing, pulling, removing),
and checking the status of a locally running Ollama instance via its API.

.NOTES
Author: Your Name / AI Assistant
Version: 1.0
Requires: Ollama service running locally (default: http://localhost:11434)
#>
Function Get-OllamaStatus {
    <#
    .SYNOPSIS
    Checks if the Ollama API is reachable and responding.
    .DESCRIPTION
    Sends a simple GET request to the root of the Ollama API endpoint.
    Returns $true if successful (Ollama responded), $false otherwise.
    .PARAMETER OllamaUri
    The base URI of the Ollama API endpoint. Defaults to 'http://localhost:11434'.
    .EXAMPLE
    Get-OllamaStatus
    # Returns $true or $false depending on whether Ollama is running and responding.
    .EXAMPLE
    if (Get-OllamaStatus -OllamaUri 'http://192.168.1.100:11434') {
        Write-Host "Ollama is running on the specified host."
    }
    .OUTPUTS
    System.Boolean
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OllamaUri = 'http://localhost:11434'
    )

    try {
        # Simple GET request to the root endpoint. Ollama should respond with "Ollama is running".
        $response = Invoke-RestMethod -Uri $OllamaUri -Method Get -TimeoutSec 5 -ErrorAction Stop
        # Check if response is the expected string, though just getting a 200 OK is usually sufficient proof.
        if ($response -eq "Ollama is running") {
            return $true
        } else {
            # If we got a 200 OK but unexpected content, still consider it running.
            # Add more specific checks if needed based on Ollama API docs.
             Write-Warning "Ollama API responded, but not with the expected 'Ollama is running' message. Content: $response"
             return $true
        }
    }
    catch [System.Net.WebException] {
        Write-Warning "Failed to connect to Ollama API at '$OllamaUri'. Is Ollama running? Error: $($_.Exception.Message)"
        return $false
    }
    catch {
        Write-Warning "An unexpected error occurred while checking Ollama status at '$OllamaUri'. Error: $($_.Exception.Message)"
        return $false
    }
}

Function Get-OllamaModel {
    <#
    .SYNOPSIS
    Lists locally available Ollama models or shows details for a specific model.
    .DESCRIPTION
    Retrieves a list of all models stored locally by Ollama by querying the '/api/tags' endpoint.
    If a Name is provided, it queries '/api/show' for details about that specific model.
    .PARAMETER Name
    The optional name (including tag, e.g., 'gemma:3b') of a specific model to get details for.
    If omitted, lists all local models.
    .PARAMETER OllamaUri
    The base URI of the Ollama API endpoint. Defaults to 'http://localhost:11434'.
    .EXAMPLE
    Get-OllamaModel
    # Lists all locally available models and their basic info.
    .EXAMPLE
    Get-OllamaModel -Name 'llama3:latest'
    # Shows detailed information about the 'llama3:latest' model.
    .OUTPUTS
    PSCustomObject or Array of PSCustomObjects
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$OllamaUri = 'http://localhost:11434'
    )

    if (-not [string]::IsNullOrEmpty($Name)) {
        # Get details for a specific model
        $apiUrl = "$OllamaUri/api/show"
        $body = @{ name = $Name } | ConvertTo-Json

        try {
            Write-Verbose "Querying model details for '$Name' at '$apiUrl'"
            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $body -ContentType 'application/json' -ErrorAction Stop
            return $response
        }
        catch {
            Write-Error "Failed to get details for model '$Name'. Error: $($_.Exception.Message)"
            return $null
        }
    }
    else {
        # List all local models
        $apiUrl = "$OllamaUri/api/tags"
        try {
            Write-Verbose "Querying all local models at '$apiUrl'"
            $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
            # The response structure is {"models": [...]}. We want the array inside.
            return $response.models
        }
        catch {
            Write-Error "Failed to list local models. Error: $($_.Exception.Message)"
            return $null
        }
    }
}

Function Invoke-OllamaGenerate {
    <#
    .SYNOPSIS
    Generates text using a specified Ollama model and prompt.
    .DESCRIPTION
    Sends a prompt to the Ollama '/api/generate' endpoint and returns the model's response.
    Supports both standard (full response at once) and streaming modes.
    .PARAMETER Model
    The name of the Ollama model to use (e.g., 'gemma:2b', 'llama3'). Mandatory.
    .PARAMETER Prompt
    The text prompt to send to the model. Mandatory.
    .PARAMETER SystemPrompt
    An optional system message to provide context or instructions to the model.
    .PARAMETER Stream
    If specified ($true), the response will be streamed word-by-word to the console.
    If $false (default), the function waits for the full response and returns it as a single string.
    .PARAMETER Format
    Optional. Specify the format for the response (e.g., 'json' for JSON output).
    .PARAMETER OllamaUri
    The base URI of the Ollama API endpoint. Defaults to 'http://localhost:11434'.
    .PARAMETER Raw
    If specified ($true), returns the full response object instead of just the 'response' text property (only applies when Stream is $false).
    .PARAMETER Options
    A hashtable of additional Ollama generation options (e.g., @{ temperature = 0.8; top_k = 50 }).
    See Ollama API documentation for available options.
    .EXAMPLE
    Invoke-OllamaGenerate -Model 'gemma:2b' -Prompt 'Why is the sky blue?'
    # Returns the full answer as a single string.
    .EXAMPLE
    Invoke-OllamaGenerate -Model 'llama3' -Prompt 'Write a short poem about PowerShell.' -Stream
    # Prints the poem to the console word by word as it's generated.
    .EXAMPLE
    Invoke-OllamaGenerate -Model 'gemma:2b' -Prompt 'Explain quantum physics simply.' -SystemPrompt 'You are an expert physicist explaining concepts to a five-year-old.'
    .EXAMPLE
    $ollamaOptions = @{
        temperature = 0.5
        num_predict = 100 # Max tokens
    }
    Invoke-OllamaGenerate -Model 'llama3' -Prompt 'List 5 facts about Mars.' -Options $ollamaOptions
    .OUTPUTS
    System.String (default or Stream=$true)
    PSCustomObject (if Raw=$true and Stream=$false)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Prompt,

        [Parameter(Mandatory = $false)]
        [string]$SystemPrompt,

        [Parameter(Mandatory = $false)]
        [switch]$Stream,

        [Parameter(Mandatory = $false)]
        [string]$Format,

        [Parameter(Mandatory = $false)]
        [string]$OllamaUri = 'http://localhost:11434',

        [Parameter(Mandatory = $false)]
        [switch]$Raw,

        [Parameter(Mandatory=$false)]
        [hashtable]$Options
    )

    $apiUrl = "$OllamaUri/api/generate"
    $body = @{
        model  = $Model
        prompt = $Prompt
        stream = if ($Stream.IsPresent) { $true } else { $false }
    }

    # Add optional parameters if they are provided
    if (-not [string]::IsNullOrEmpty($SystemPrompt)) {
        $body.Add('system', $SystemPrompt)
    }
    if (-not [string]::IsNullOrEmpty($Format)) {
        $body.Add('format', $Format)
    }
     if ($Options -ne $null -and $Options.Count -gt 0) {
        $body.Add('options', $Options)
    }

    $jsonBody = $body | ConvertTo-Json -Depth 5 # Increase depth if needed for complex options

    Write-Verbose "Sending request to '$apiUrl' with body: $jsonBody"

    try {
        if ($Stream.IsPresent) {
            # Streaming requires handling the response differently
            $request = [System.Net.HttpWebRequest]::Create($apiUrl)
            $request.Method = 'POST'
            $request.ContentType = 'application/json'
            $request.Accept = 'application/json' # Or application/x-ndjson for streams
            $request.AllowReadStreamBuffering = $false # Important for streaming

            $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
            $request.ContentLength = $bytes.Length
            $requestStream = $request.GetRequestStream()
            $requestStream.Write($bytes, 0, $bytes.Length)
            $requestStream.Close()

            $response = $request.GetResponse()
            $responseStream = $response.GetResponseStream()
            $reader = [System.IO.StreamReader]::new($responseStream)

            Write-Verbose "Streaming response..."
            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if (-not [string]::IsNullOrEmpty($line)) {
                    try {
                        $lineObject = $line | ConvertFrom-Json
                        # Write the 'response' part of the stream chunk without a newline
                        Write-Host $lineObject.response -NoNewline
                        # Check if generation is done (Ollama API specific field)
                        if ($lineObject.done -eq $true) {
                            Write-Verbose "Stream finished."
                            break
                        }
                    } catch {
                         Write-Warning "Could not parse JSON line from stream: $line. Error: $($_.Exception.Message)"
                    }
                }
            }
            # Add a final newline after streaming is complete
            Write-Host ""
            $reader.Close()
            $responseStream.Close()
            $response.Close()
        }
        else {
            # Non-streaming: Get the full response at once
            $responseObject = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $jsonBody -ContentType 'application/json' -ErrorAction Stop

            if ($Raw.IsPresent) {
                return $responseObject # Return the entire object
            } else {
                # By default, just return the text response
                return $responseObject.response
            }
        }
    }
    catch {
        Write-Error "Failed to generate text using model '$Model'. Error: $($_.Exception.Message)"
        # Optionally display more details from the exception if available
         if ($_.Exception -is [System.Net.WebException]) {
            $webEx = $_.Exception
            if ($webEx.Response) {
                $errReader = [System.IO.StreamReader]::new($webEx.Response.GetResponseStream())
                $errorDetails = $errReader.ReadToEnd()
                $errReader.Close()
                Write-Error "API Error Details: $errorDetails"
            }
        }
        return $null
    }
}

Function Add-OllamaModel {
    <#
    .SYNOPSIS
    Pulls (downloads) a model from the Ollama library.
    .DESCRIPTION
    Instructs the local Ollama instance to download a specified model using the '/api/pull' endpoint.
    Shows download progress by default.
    .PARAMETER Name
    The name of the model to pull (e.g., 'llama3:8b', 'gemma:latest'). Mandatory.
    .PARAMETER Insecure
    If specified ($true), allows pulling from insecure (non-HTTPS) registries. Use with caution.
    .PARAMETER StreamOutput
    If specified ($true, default), streams the progress output from Ollama to the console.
    If $false, waits until the pull is complete and returns a summary status.
    .PARAMETER OllamaUri
    The base URI of the Ollama API endpoint. Defaults to 'http://localhost:11434'.
    .EXAMPLE
    Add-OllamaModel -Name 'gemma:2b'
    # Downloads the 'gemma:2b' model and shows progress.
    .EXAMPLE
    Add-OllamaModel -Name 'mymodel:custom' -Insecure
    # Pulls a model from a local insecure registry.
    .EXAMPLE
    Add-OllamaModel -Name 'llama3' -StreamOutput:$false
    # Pulls the model without showing line-by-line progress, just a final status.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [switch]$Insecure,

        [Parameter(Mandatory = $false)]
        [bool]$StreamOutput = $true, # Default to streaming progress

        [Parameter(Mandatory = $false)]
        [string]$OllamaUri = 'http://localhost:11434'
    )

    $apiUrl = "$OllamaUri/api/pull"
    $body = @{
        name   = $Name
        stream = $StreamOutput
    }
    if ($Insecure.IsPresent) {
        $body.Add('insecure', $true)
    }

    $jsonBody = $body | ConvertTo-Json

    Write-Verbose "Sending request to '$apiUrl' with body: $jsonBody"
    Write-Host "Pulling model '$Name'... (This may take a while)"

    try {
        if ($StreamOutput) {
            # Use Invoke-WebRequest for better streaming control and raw output
            $response = Invoke-WebRequest -Uri $apiUrl -Method Post -Body $jsonBody -ContentType 'application/json' -ErrorAction Stop
            # Output the content line by line as it comes (shows progress messages)
            # The Content might be a single block on completion or stream depending on PS version/WebRequest behavior
            # For robust streaming, similar HttpWebRequest logic as in Invoke-OllamaGenerate might be needed,
            # but Invoke-WebRequest often provides readable progress for `pull`.
            Write-Host $response.Content
            Write-Host "Model '$Name' pull process initiated. Monitor Ollama logs or console output for completion."

        } else {
             # Non-streaming: Get the final status message
            $responseObject = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $jsonBody -ContentType 'application/json' -ErrorAction Stop
            Write-Host "Model '$Name' pull completed."
            # Return the final status object which might contain summary info
            return $responseObject
        }
         # Add a check here if the model now exists
        $checkModel = Get-OllamaModel -Name $Name -OllamaUri $OllamaUri -ErrorAction SilentlyContinue
        if ($checkModel) {
            Write-Host "Successfully verified that model '$Name' is now available locally." -ForegroundColor Green
        } else {
             Write-Warning "Pull command sent, but could not immediately verify that model '$Name' is available locally. Please check manually with Get-OllamaModel."
        }

    }
    catch {
        Write-Error "Failed to pull model '$Name'. Error: $($_.Exception.Message)"
         if ($_.Exception -is [System.Net.WebException]) {
            $webEx = $_.Exception
            if ($webEx.Response) {
                $errReader = [System.IO.StreamReader]::new($webEx.Response.GetResponseStream())
                $errorDetails = $errReader.ReadToEnd()
                $errReader.Close()
                Write-Error "API Error Details: $errorDetails"
            }
        }
        return $null
    }
}

Function Remove-OllamaModel {
    <#
    .SYNOPSIS
    Deletes a local Ollama model.
    .DESCRIPTION
    Sends a request to the Ollama '/api/delete' endpoint to remove a specified model from local storage.
    .PARAMETER Name
    The name of the model to delete (e.g., 'gemma:2b'). Mandatory.
    .PARAMETER OllamaUri
    The base URI of the Ollama API endpoint. Defaults to 'http://localhost:11434'.
    .EXAMPLE
    Remove-OllamaModel -Name 'gemma:2b'
    # Deletes the 'gemma:2b' model.
    .EXAMPLE
    Get-OllamaModel | Where-Object {$_.name -like '*:7b*'} | Remove-OllamaModel
    # Finds all models with ':7b' in their name and attempts to remove them (prompts for confirmation if -Confirm is supported/used).
    #>
    [CmdletBinding(SupportsShouldProcess = $true)] # Adds -WhatIf and -Confirm support
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$OllamaUri = 'http://localhost:11434'
    )

    # Allow piping PSCustomObjects from Get-OllamaModel which have a 'name' property
    if ($Name -is [pscustomobject] -and $Name.PSObject.Properties['name']) {
        $modelName = $Name.name
    } else {
        $modelName = $Name
    }


    $apiUrl = "$OllamaUri/api/delete"
    $body = @{ name = $modelName } | ConvertTo-Json

    Write-Verbose "Attempting to delete model '$modelName' via '$apiUrl'"

    if ($pscmdlet.ShouldProcess($modelName, "Delete Ollama Model")) {
        try {
            # NOTE: Invoke-RestMethod with DELETE and a BODY requires PS 6+ or using Invoke-WebRequest
            # Using Invoke-WebRequest for broader compatibility here.
            # For PS 5.1, Invoke-RestMethod -Method Delete does not easily support -Body
            # $response = Invoke-RestMethod -Uri $apiUrl -Method Delete -Body $body -ContentType 'application/json' -ErrorAction Stop

             $response = Invoke-WebRequest -Uri $apiUrl -Method Delete -Body $body -ContentType 'application/json' -ErrorAction Stop

            # Check status code for success (typically 200 OK for delete)
            if ($response.StatusCode -eq 200) {
                 Write-Host "Successfully deleted model '$modelName'."
            } else {
                # Should be caught by ErrorAction Stop, but as a fallback:
                 Write-Warning "Ollama API returned status code $($response.StatusCode) for deleting model '$modelName'. Content: $($response.Content)"
            }

        }
        catch {
            Write-Error "Failed to delete model '$modelName'. Error: $($_.Exception.Message)"
            # Provide more details if available (e.g., Model Not Found likely returns 404)
            if ($_.Exception -is [System.Net.WebException]) {
                 $webEx = $_.Exception
                 if ($webEx.Response) {
                    $errReader = [System.IO.StreamReader]::new($webEx.Response.GetResponseStream())
                    $errorDetails = $errReader.ReadToEnd()
                    $errReader.Close()
                    Write-Error "API Error Details (Status Code: $([int]$webEx.Response.StatusCode)): $errorDetails"
                 }
            }
        }
    } else {
         Write-Host "Skipped deletion of model '$modelName' due to -WhatIf or user cancellation."
    }
}

# Export the functions to make them available when the module is imported
Export-ModuleMember -Function Get-OllamaStatus, Get-OllamaModel, Invoke-OllamaGenerate, Add-OllamaModel, Remove-OllamaModel