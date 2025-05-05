<#
.SYNOPSIS
Reads API test case data from a CSV and uses Ollama to generate Gherkin scenarios.

.DESCRIPTION
This script iterates through rows in a specified CSV file, taking description and step data
for each test case. It constructs a prompt for Ollama (using a specified model) to
convert this information into Gherkin format (Given/When/Then).

Note: This uses Ollama's generation endpoint for in-context learning, not true model fine-tuning.

.PARAMETER CsvPath
The path to the input CSV file containing test case data.

.PARAMETER Model
The name of the Ollama model to use for generation (e.g., 'gemma:2b', 'llama3').

.PARAMETER OutputPath
Optional. Path to a file where the generated Gherkin scenarios will be appended.
If not specified, output is written to the console.

.PARAMETER DescriptionColumn
The name of the column in the CSV containing the test case description. Defaults to 'Description'.

.PARAMETER StepsColumn
The name of the column in the CSV containing the test case steps. Defaults to 'Steps'.

.PARAMETER OllamaUri
The base URI of the Ollama API endpoint. Defaults to 'http://localhost:11434'.

.EXAMPLE
.\Generate-GherkinFromCsv.ps1 -CsvPath .\api_test_cases.csv -Model 'gemma:2b' -OutputPath .\generated_tests.feature

.EXAMPLE
.\Generate-GherkinFromCsv.ps1 -CsvPath C:\data\tests.csv -Model 'llama3:latest' -DescriptionColumn 'Summary' -StepsColumn 'TestSteps'

.NOTES
Requires the 'OllamaUtils' PowerShell module (containing Invoke-OllamaGenerate) to be installed and accessible.
The quality of the Gherkin output depends heavily on the model's capabilities and the clarity of the input data and prompt.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [string]$Model,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$DescriptionColumn = 'Description',

    [Parameter(Mandatory = $false)]
    [string]$StepsColumn = 'Steps',

    [Parameter(Mandatory = $false)]
    [string]$OllamaUri = 'http://localhost:11434'
)

#region Setup and Validation
# Ensure the OllamaUtils module is available
$OllamaModule = Get-Module -Name OllamaUtils -ListAvailable
if (-not $OllamaModule) {
    Write-Error "The required 'OllamaUtils' module was not found. Please ensure it's installed in your PowerShell module path."
    Exit 1
}
# Import the module - Force ensures we get the latest if it was updated
try {
    Import-Module OllamaUtils -Force -ErrorAction Stop
    Write-Verbose "OllamaUtils module loaded."
}
catch {
    Write-Error "Failed to load the OllamaUtils module. Error: $($_.Exception.Message)"
    Exit 1
}

# Check Ollama Status
if (-not (Get-OllamaStatus -OllamaUri $OllamaUri -ErrorAction SilentlyContinue)) {
     Write-Warning "Could not connect to Ollama at '$OllamaUri'. Please ensure Ollama is running."
    # Decide if you want to exit or continue trying
    # Exit 1
}

# Import CSV Data
try {
    $testCases = Import-Csv -Path $CsvPath -ErrorAction Stop
    Write-Host "Successfully imported $($testCases.Count) test cases from '$CsvPath'." -ForegroundColor Green
}
catch {
    Write-Error "Failed to import CSV data from '$CsvPath'. Error: $($_.Exception.Message)"
    Exit 1
}

# Validate Columns
if ($testCases.Count -gt 0) {
    $firstRow = $testCases[0]
    if (-not ($firstRow.PSObject.Properties.Name -contains $DescriptionColumn)) {
        Write-Error "CSV file '$CsvPath' does not contain the specified DescriptionColumn: '$DescriptionColumn'."
        Exit 1
    }
    if (-not ($firstRow.PSObject.Properties.Name -contains $StepsColumn)) {
        Write-Error "CSV file '$CsvPath' does not contain the specified StepsColumn: '$StepsColumn'."
        Exit 1
    }
} else {
    Write-Warning "CSV file '$CsvPath' is empty or contains only headers."
    Exit 0 # No work to do
}

# Prepare Output
$useOutputFile = -not [string]::IsNullOrEmpty($OutputPath)
if ($useOutputFile) {
    Write-Host "Generated Gherkin will be appended to: '$OutputPath'"
    # Ensure directory exists (optional, Add-Content creates the file but not dirs)
    $OutputDirectory = Split-Path -Path $OutputPath -Parent
    if ($OutputDirectory -and (-not (Test-Path -Path $OutputDirectory -PathType Container))) {
       New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }
    # Add a Feature header if the file is new or empty
    if (-not (Test-Path -Path $OutputPath) -or ((Get-Item $OutputPath).Length -eq 0)) {
         Add-Content -Path $OutputPath -Value "Feature: API Test Cases Generated from CSV`n"
    }
} else {
    Write-Host "Generated Gherkin will be written to the console."
}

# Define the System Prompt for Ollama
# This guides the model on its role and the desired output format. Adjust as needed.
$systemPrompt = @"
You are an expert QA engineer specialized in API testing.
Your task is to convert provided test case descriptions and step-by-step instructions into the standard Gherkin syntax (Feature, Scenario, Given, When, Then).
Focus on creating clear, concise, and accurate Gherkin scenarios based *only* on the information given.
Infer standard API preconditions (like 'the API is available') if not explicitly stated.
Format the output strictly as a Gherkin Scenario block. Do not include the 'Feature:' line unless it's part of the Scenario description itself.
Start the output directly with 'Scenario:'.
"@

#endregion

#region Processing Loop
$counter = 0
$total = $testCases.Count

foreach ($row in $testCases) {
    $counter++
    $description = $row.$DescriptionColumn
    $steps = $row.$StepsColumn

    Write-Host "`n[$($counter)/$($total)] Processing: '$description'" -ForegroundColor Cyan

    if ([string]::IsNullOrWhiteSpace($description) -or [string]::IsNullOrWhiteSpace($steps)) {
        Write-Warning "Skipping row $counter due to missing Description or Steps."
        continue
    }

    # Construct the User Prompt for this specific row
    # This provides the context (description, steps) for the model to work with.
    $userPrompt = @"
Convert the following API test case details into a Gherkin Scenario:

**Test Case Description:**
$description

**Test Steps:**
$steps

**Gherkin Scenario Output:**
"@ # The model should generate the Scenario block after this line

    # Call Ollama
    Write-Verbose "Sending prompt to Ollama model '$Model'..."
    try {
        $generationParams = @{
            Model        = $Model
            Prompt       = $userPrompt
            SystemPrompt = $systemPrompt
            OllamaUri    = $OllamaUri
            Stream       = $false # Get the full response at once
            ErrorAction  = 'Stop'
        }
        $ollamaResponse = Invoke-OllamaGenerate @generationParams

        if ($ollamaResponse) {
            # Basic cleanup - remove potential ```gherkin fences if the model adds them
            $gherkinOutput = $ollamaResponse.Trim(" `t`n`r").Trim('```gherkin').Trim('```')

             # Ensure it starts roughly like Gherkin - simple check
             if ($gherkinOutput -notmatch '^\s*Scenario:|^\s*@\w+') {
                  Write-Warning "Model output for '$description' doesn't look like standard Gherkin starting with 'Scenario:' or a tag. Output was: $ollamaResponse"
                  # Optionally skip writing this output or try to fix it
             }

            # Output the result
            $outputBlock = @"

# --- Generated from: $description ---
$gherkinOutput
# --- End of generation ---

"@
            if ($useOutputFile) {
                Add-Content -Path $OutputPath -Value $outputBlock
                Write-Verbose "Appended Gherkin to '$OutputPath'"
            } else {
                Write-Host $outputBlock -ForegroundColor Green
            }
        } else {
             Write-Warning "Ollama returned an empty response for row $counter ('$description')."
        }
    }
    catch {
        Write-Error "Error processing row $counter ('$description') with Ollama model '$Model': $($_.Exception.Message)"
        # Optionally add a 'continue' here to skip to the next row on error, or let the script stop.
        # continue
    }
}
#endregion

Write-Host "`nProcessing complete. Processed $counter out of $total rows." -ForegroundColor Green
if ($useOutputFile) {
    Write-Host "Results saved to '$OutputPath'."
}