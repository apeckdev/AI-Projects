<#
.SYNOPSIS
Converts data between CSV format and Gherkin data table format.

.DESCRIPTION
This script can convert a CSV file into a Gherkin Scenario Outline table format,
or parse a file containing Gherkin feature syntax to extract all data tables
into separate CSV files. It can also handle pasted Gherkin table input.

.PARAMETER Path
The path to the input file.
- For CsvToGherkin: Path to the input CSV file (Mandatory in this direction).
- For GherkinToCsv: Path to the input file containing Gherkin tables (e.g., .feature file). If not provided, the script will prompt for pasted input.

.PARAMETER Direction
Specifies the conversion direction. Must be either 'CsvToGherkin' or 'GherkinToCsv'.

.PARAMETER OutPath
Optional. Specifies the output directory for GherkinToCsv file output, or the output file path for CsvToGherkin file output.
If not specified:
- CsvToGherkin: Output is written to the console.
- GherkinToCsv (File Input): CSV files are created in the current directory.
- GherkinToCsv (Pasted Input): Output is written to the console.

.EXAMPLE
.\Convert-CsvGherkin.ps1 -Direction CsvToGherkin -Path .\users.csv
# Converts users.csv to Gherkin format and outputs to console.

.EXAMPLE
.\Convert-CsvGherkin.ps1 -Direction CsvToGherkin -Path .\users.csv -OutPath .\output.gherkin
# Converts users.csv to Gherkin format and saves to output.gherkin.

.EXAMPLE
.\Convert-CsvGherkin.ps1 -Direction GherkinToCsv -Path .\my_tests.feature
# Parses my_tests.feature, finds all Gherkin tables, and saves each as a CSV file
# in the current directory (e.g., gherkin_table_line_10.csv).

.EXAMPLE
.\Convert-CsvGherkin.ps1 -Direction GherkinToCsv -Path .\my_tests.feature -OutPath .\output_csvs
# Parses my_tests.feature and saves extracted CSV tables into the .\output_csvs directory.

.EXAMPLE
.\Convert-CsvGherkin.ps1 -Direction GherkinToCsv
# Prompts the user to paste a Gherkin table, then outputs the CSV conversion to the console.

.INPUTS
None. You cannot pipe objects to this script directly other than for pasted input simulation.

.OUTPUTS
System.String - Gherkin or CSV formatted text to the console.
System.IO.FileInfo - Creates CSV files when using GherkinToCsv with a file path.

.NOTES
Author: Your Name / AI Assistant
Date:   YYYY-MM-DD
Requires: PowerShell 5.1 or later.
For GherkinToCsv file parsing, it looks for lines starting and ending with '|' that form tables.
It doesn't perform full Gherkin syntax validation.
#>
[CmdletBinding(DefaultParameterSetName = 'FromFile')]
param(
    [Parameter(ParameterSetName = 'FromFile', Position = 0)]
    [Parameter(ParameterSetName = 'FromPaste', Position = 0)]
    [System.String]
    $Path,

    [Parameter(Mandatory = $true)]
    [ValidateSet('CsvToGherkin', 'GherkinToCsv')]
    [System.String]
    $Direction,

    [Parameter()]
    [System.String]
    $OutPath
)

# --- Helper Functions ---

function ConvertTo-GherkinTable {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$CsvData
    )

    if ($CsvData -eq $null -or $CsvData.Count -eq 0) {
        Write-Warning "Input CSV data is empty or null."
        return ""
    }

    # Get headers from the first object
    $headers = $CsvData[0].PSObject.Properties.Name
    $numColumns = $headers.Count

    # Calculate maximum width for each column
    $maxWidths = @{}
    foreach ($header in $headers) {
        $maxWidths[$header] = $header.Length
    }

    foreach ($row in $CsvData) {
        foreach ($header in $headers) {
            $valueLength = if ($null -ne $row.$header) { ($row.$header -as [string]).Length } else { 0 }
            if ($valueLength -gt $maxWidths[$header]) {
                $maxWidths[$header] = $valueLength
            }
        }
    }

    # Build Gherkin Table String
    $gherkinBuilder = [System.Text.StringBuilder]::new()

    # Header Row
    [void]$gherkinBuilder.Append("|")
    foreach ($header in $headers) {
        $paddedHeader = $header.PadRight($maxWidths[$header])
        [void]$gherkinBuilder.Append(" $($paddedHeader) |")
    }
    [void]$gherkinBuilder.AppendLine()

    # Data Rows
    foreach ($row in $CsvData) {
        [void]$gherkinBuilder.Append("|")
        foreach ($header in $headers) {
            $value = if ($null -ne $row.$header) { ($row.$header -as [string]) } else { "" }
            $paddedValue = $value.PadRight($maxWidths[$header])
            [void]$gherkinBuilder.Append(" $($paddedValue) |")
        }
        [void]$gherkinBuilder.AppendLine()
    }

    # Add Scenario Outline context
    $scenarioOutline = @"
    Scenario Outline: Converted from CSV
      Given some context
      When I process the data <$($headers[0])>
      Then the result should be valid

      Examples:
$($gherkinBuilder.ToString().TrimEnd())
"@
    return $scenarioOutline
}

function ConvertFrom-GherkinTable {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GherkinLines
    )

    $tableLines = $GherkinLines | Where-Object { $_ -match '^\s*\|.*\|\s*$' } | ForEach-Object { $_.Trim() }

    if ($tableLines.Count -lt 2) {
        Write-Verbose "Not enough lines found to form a Gherkin table (header + data)."
        return $null # Indicate no valid table found
    }

    # Process Header
    $headerLine = $tableLines[0]
    $headers = $headerLine.Split('|', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() }

    # Process Data Rows
    $csvRows = @()
    for ($i = 1; $i -lt $tableLines.Count; $i++) {
        $dataLine = $tableLines[$i]
        $cells = $dataLine.Split('|', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() }

        # Handle rows with potentially fewer columns than header (e.g. empty cells at end)
        $rowObject = [PSCustomObject]::new()
        for ($j = 0; $j -lt $headers.Count; $j++) {
            $cellValue = if ($j -lt $cells.Count) { $cells[$j] } else { "" } # Default to empty if cell missing
             # Quote if it contains comma, double quote, or leading/trailing spaces
            if ($cellValue -match ',|"' -or $cellValue -match '^\s|\s$') {
                 $escapedValue = $cellValue -replace '"', '""' # Escape existing double quotes
                 $rowObject | Add-Member -MemberType NoteProperty -Name $headers[$j] -Value "`"$escapedValue`""
            } else {
                 $rowObject | Add-Member -MemberType NoteProperty -Name $headers[$j] -Value $cellValue
            }
        }
        $csvRows += $rowObject
    }

    # Convert PSCustomObjects to CSV format string
    # Manually construct CSV to handle quotes correctly as built-in ConvertTo-Csv might add unnecessary quotes
    $csvOutput = [System.Text.StringBuilder]::new()
    [void]$csvOutput.AppendLine(($headers | ForEach-Object { if ($_ -match ',|"|^\s|\s$') { """$($_ -replace '"', '""')""" } else { $_ } }) -join ',') # Header row
    foreach ($row in $csvRows) {
        $rowValues = $headers | ForEach-Object { $row.$_ } # Access properties directly which are already quoted if needed
        [void]$csvOutput.AppendLine(($rowValues -join ','))
    }

    return $csvOutput.ToString().TrimEnd()
}

# --- Main Logic ---

if ($Direction -eq 'CsvToGherkin') {
    # CsvToGherkin requires a file path
    if (-not $Path) {
        throw "Parameter -Path is required when Direction is CsvToGherkin."
    }
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        throw "Input file not found: $Path"
    }

    Write-Verbose "Converting CSV file '$Path' to Gherkin format."
    try {
        $csvData = Import-Csv -Path $Path
        if ($csvData -eq $null -or $csvData.Count -eq 0) {
             Write-Warning "CSV file '$Path' is empty or could not be parsed."
             return
        }
        $gherkinOutput = ConvertTo-GherkinTable -CsvData $csvData

        if ($OutPath) {
            Write-Verbose "Writing Gherkin output to file: $OutPath"
            # Ensure directory exists if OutPath includes directory structure
             $OutDir = Split-Path -Path $OutPath -Parent
             if ($OutDir -and (-not (Test-Path -Path $OutDir -PathType Container))) {
                 Write-Verbose "Creating output directory: $OutDir"
                 New-Item -Path $OutDir -ItemType Directory -Force | Out-Null
             }
            Set-Content -Path $OutPath -Value $gherkinOutput -Encoding UTF8
        } else {
            Write-Output $gherkinOutput
        }
    } catch {
        Write-Error "Failed to convert CSV to Gherkin: $($_.Exception.Message)"
    }

} elseif ($Direction -eq 'GherkinToCsv') {
    $inputLines = @()
    $isPastedInput = $false

    if ($Path) {
        if (-not (Test-Path -Path $Path -PathType Leaf)) {
            throw "Input file not found: $Path"
        }
        Write-Verbose "Reading Gherkin input from file: $Path"
        $inputLines = Get-Content -Path $Path
    } else {
        # Prompt for pasted input
        Write-Host "Please paste your Gherkin table here. Press Enter twice (empty line) when finished:" -ForegroundColor Yellow
        $isPastedInput = $true
        while ($line = Read-Host) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                break # Stop on empty line
            }
            $inputLines += $line
        }
        if ($inputLines.Count -eq 0) {
             Write-Warning "No input pasted."
             return
        }
         Write-Verbose "Processing pasted Gherkin input."
    }

    # Find tables within the input lines
    $tables = @()
    $currentTable = @()
    $tableStartLine = -1
    $lineNum = 0

    foreach ($line in $inputLines) {
        $lineNum++
        if ($line -match '^\s*\|.*\|\s*$') {
            if ($currentTable.Count -eq 0) {
                $tableStartLine = $lineNum # Record start line for filename
            }
            $currentTable += $line.Trim()
        } else {
            if ($currentTable.Count -ge 2) { # Found end of a potential table (must have header + at least one data row)
                $tables += @{ Lines = $currentTable; StartLine = $tableStartLine }
            }
            $currentTable = @() # Reset for next table
            $tableStartLine = -1
        }
    }
    # Add the last table if the file ends with one
    if ($currentTable.Count -ge 2) {
         $tables += @{ Lines = $currentTable; StartLine = $tableStartLine }
    }

    if ($tables.Count -eq 0) {
        Write-Warning "No valid Gherkin data tables found in the input."
        return
    }

    Write-Verbose "Found $($tables.Count) potential Gherkin table(s)."

    # Process each found table
    $tableIndex = 0
    foreach ($tableInfo in $tables) {
        $tableIndex++
        $csvOutput = ConvertFrom-GherkinTable -GherkinLines $tableInfo.Lines
        if ($null -eq $csvOutput) {
            Write-Warning "Skipping invalid table structure starting near line $($tableInfo.StartLine)."
            continue
        }

        if ($isPastedInput) {
            # Output directly to console for pasted input
            Write-Output $csvOutput
        } else {
            # Output to file(s)
            $outputFileName = "gherkin_table_line_$($tableInfo.StartLine).csv"
            $fullOutputPath = $outputFileName
            if ($OutPath) {
                 # Check if OutPath is a directory
                 if (Test-Path -Path $OutPath -PathType Container) {
                     $fullOutputPath = Join-Path -Path $OutPath -ChildPath $outputFileName
                     # Ensure directory exists (might be redundant if Test-Path worked, but safe)
                     if (-not (Test-Path -Path $OutPath -PathType Container)) {
                         Write-Verbose "Creating output directory: $OutPath"
                         New-Item -Path $OutPath -ItemType Directory -Force | Out-Null
                     }
                 } else {
                     # Treat OutPath as a full file path *only if* there's exactly one table found
                     if ($tables.Count -eq 1) {
                          $fullOutputPath = $OutPath
                          $OutDir = Split-Path -Path $fullOutputPath -Parent
                          if ($OutDir -and (-not (Test-Path -Path $OutDir -PathType Container))) {
                              Write-Verbose "Creating output directory: $OutDir"
                              New-Item -Path $OutDir -ItemType Directory -Force | Out-Null
                          }
                     } else {
                         Write-Warning "-OutPath '$OutPath' is not a directory. Saving CSVs to current directory instead as multiple tables were found."
                         # Fallback to current dir, but keep $fullOutputPath using the generated name
                         $fullOutputPath = Join-Path -Path (Get-Location) -ChildPath $outputFileName
                     }
                 }
            } else {
                 # Default to current directory
                 $fullOutputPath = Join-Path -Path (Get-Location) -ChildPath $outputFileName
            }


            Write-Verbose "Writing CSV output for table starting line $($tableInfo.StartLine) to: $fullOutputPath"
            try {
                Set-Content -Path $fullOutputPath -Value $csvOutput -Encoding UTF8
            } catch {
                Write-Error "Failed to write CSV file '$fullOutputPath': $($_.Exception.Message)"
            }
        }
    }
}