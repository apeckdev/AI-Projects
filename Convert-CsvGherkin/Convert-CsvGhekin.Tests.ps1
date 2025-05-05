#Requires -Modules Pester -Version 5.0

<#
Pester tests for Convert-CsvGherkin.ps1
#>

# Define paths relative to the test script location
$ScriptPath = Join-Path $PSScriptRoot 'Convert-CsvGherkin.ps1'
$SampleCsvPath = Join-Path $PSScriptRoot 'sample.csv'
$SampleFeaturePath = Join-Path $PSScriptRoot 'sample.feature'
$TestOutDir = Join-Path $PSScriptRoot 'TestOutput'

Describe 'Convert-CsvGherkin Script' { # <- Matches opening brace for Describe

    # Ensure output directory exists and is clean for file output tests
    BeforeAll { # <- Matches opening brace for BeforeAll
        if (Test-Path $TestOutDir) {
            Remove-Item -Path $TestOutDir -Recurse -Force
        }
        New-Item -Path $TestOutDir -ItemType Directory | Out-Null
    } # <- Matches closing brace for BeforeAll

    # Clean up output directory after tests
    AfterAll { # <- Matches opening brace for AfterAll
        if (Test-Path $TestOutDir) {
            Remove-Item -Path $TestOutDir -Recurse -Force
        }
    } # <- Matches closing brace for AfterAll

    Context 'Parameter Validation' { # <- Matches opening brace for Context
        It 'Should throw if -Direction is not specified' { # <- Matches opening brace for It
            { . $ScriptPath } | Should -Throw
        } # <- Matches closing brace for It

        It 'Should throw if -Direction has an invalid value' { # <- Matches opening brace for It
            { . $ScriptPath -Direction InvalidDirection } | Should -Throw
        } # <- Matches closing brace for It

        It 'Should throw if -Direction is CsvToGherkin and -Path is missing' { # <- Matches opening brace for It
            { . $ScriptPath -Direction CsvToGherkin } | Should -Throw 'Parameter -Path is required*'
        } # <- Matches closing brace for It

        It 'Should throw if -Path points to a non-existent file' { # <- Matches opening brace for It
            { . $ScriptPath -Direction CsvToGherkin -Path 'nonexistent.csv' } | Should -Throw 'Input file not found*'
            { . $ScriptPath -Direction GherkinToCsv -Path 'nonexistent.feature' } | Should -Throw 'Input file not found*'
        } # <- Matches closing brace for It
    } # <- Matches closing brace for Context

    Context 'CsvToGherkin Conversion' { # <- Matches opening brace for Context
        It 'Should convert sample.csv to Gherkin format (Console Output)' { # <- Matches opening brace for It
            $expectedHeader = '| ID | Name         | Job Title            | Location |' # Check padding/structure
            $expectedDataRow1 = '| 1  | Alice        | Software Engineer    | New York |'
            $expectedDataRow5 = '| 5  | Eve          | Data Scientist, AI   | Remote   |' # Check comma handling

            $result = & $ScriptPath -Direction CsvToGherkin -Path $SampleCsvPath
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Contain 'Scenario Outline: Converted from CSV'
            $result | Should -Contain 'Examples:'
            # Use -match with regex patterns that account for variable whitespace around pipes and content
            $result | Should -Match ('\| ID\s+\| Name\s+\| Job Title\s+\| Location\s+\|' -replace ' ', '\s+')
            $result | Should -Match ('\| 1\s+\| Alice\s+\| Software Engineer\s+\| New York\s+\|' -replace ' ', '\s+')
            $result | Should -Match ('\| 5\s+\| Eve\s+\| Data Scientist, AI\s+\| Remote\s+\|' -replace ' ', '\s+')
        } # <- Matches closing brace for It

         It 'Should convert sample.csv to Gherkin format (File Output)' { # <- Matches opening brace for It
             $outputFilePath = Join-Path $TestOutDir 'output.gherkin'
             & $ScriptPath -Direction CsvToGherkin -Path $SampleCsvPath -OutPath $outputFilePath

             Test-Path $outputFilePath | Should -BeTrue
             $fileContent = Get-Content $outputFilePath -Raw
             $fileContent | Should -Contain 'Scenario Outline: Converted from CSV'
             $fileContent | Should -Match ('\| 1\s+\| Alice\s+\| Software Engineer\s+\| New York\s+\|' -replace ' ', '\s+')
         } # <- Matches closing brace for It
    } # <- Matches closing brace for Context

    Context 'GherkinToCsv Conversion (File Input)' { # <- Matches opening brace for Context
        It 'Should parse sample.feature and create multiple CSV files in default location' { # <- Matches opening brace for It
            # Run in a temporary location to check default output dir
            Push-Location $TestOutDir
            try { # <- Matches opening brace for try
                # Clean any previous test artifacts in TestOutDir first
                 Get-ChildItem -Path $TestOutDir -Filter 'gherkin_table_line_*.csv' | Remove-Item -Force

                # Execute the script
                & $ScriptPath -Direction GherkinToCsv -Path $SampleFeaturePath

                # Check for expected files (based on sample.feature line numbers)
                Test-Path 'gherkin_table_line_8.csv' | Should -BeTrue  # First table
                Test-Path 'gherkin_table_line_14.csv' | Should -BeTrue # Second table
                Test-Path 'gherkin_table_line_22.csv' | Should -BeTrue # Third table (Examples: Valid)
                Test-Path 'gherkin_table_line_28.csv' | Should -BeTrue # Fourth table (Examples: Invalid)

                # Verify content of one file (e.g., the first table)
                $csvContent = Import-Csv -Path 'gherkin_table_line_8.csv'
                $csvContent.Count | Should -Be 3
                $csvContent[0].Name | Should -Be 'Frank'
                $csvContent[0].'Access Level' | Should -Be '5'
                $csvContent[1].Name | Should -Be 'Grace Hopper'
                 # Check quoted value handling - Import-Csv automatically handles the outer quotes
                $csvContent[2].Name | Should -Be 'Test, User' # Import-Csv removes the outer necessary quotes
                $csvContent[2].Role | Should -Be 'Quoted Role' # Import-Csv removes the outer necessary quotes

                 # Verify content of another file with empty cell (Examples: Valid Credentials)
                 $csvContent3 = Import-Csv -Path 'gherkin_table_line_22.csv'
                 $csvContent3.Count | Should -Be 3
                 $csvContent3[0].Username | Should -Be 'alice'
                 $csvContent3[1].Notes | Should -Be '' # Empty cell becomes empty string
                 $csvContent3[2].Notes | Should -Be 'Trailing space user' # Import-Csv removes the outer necessary quotes
            } # <- Matches closing brace for try
            finally { # <- Matches opening brace for finally
                 # Clean up created files within TestOutDir
                 Get-ChildItem -Path $TestOutDir -Filter 'gherkin_table_line_*.csv' | Remove-Item -Force
                Pop-Location
            } # <- Matches closing brace for finally
        } # <- Matches closing brace for It

        It 'Should parse sample.feature and create multiple CSV files in specified OutPath directory' { # <- Matches opening brace for It
            $outputSubDir = Join-Path $TestOutDir 'FeatureCsvOutput'
            & $ScriptPath -Direction GherkinToCsv -Path $SampleFeaturePath -OutPath $outputSubDir

            Test-Path $outputSubDir | Should -BeTrue
            Test-Path (Join-Path $outputSubDir 'gherkin_table_line_8.csv') | Should -BeTrue
            Test-Path (Join-Path $outputSubDir 'gherkin_table_line_14.csv') | Should -BeTrue
            Test-Path (Join-Path $outputSubDir 'gherkin_table_line_22.csv') | Should -BeTrue
            Test-Path (Join-Path $outputSubDir 'gherkin_table_line_28.csv') | Should -BeTrue

            # Clean up subdirectory
            Remove-Item -Path $outputSubDir -Recurse -Force
        } # <- Matches closing brace for It

         It 'Should handle OutPath as a file path if only ONE table is found' { # <- Matches opening brace for It
             # Create a temporary feature file with only one table
             $singleTableFeature = @"
 Feature: Single Table
   Scenario: Only one table
     Given this:
       | Col A | Col B |
       | Val 1 | Val 2 |
"@
             $tempFeaturePath = Join-Path $TestOutDir "single.feature"
             $outputFilePath = Join-Path $TestOutDir "single_output.csv"
             Set-Content -Path $tempFeaturePath -Value $singleTableFeature -Encoding UTF8

            try { # <- Matches opening brace for try
                 & $ScriptPath -Direction GherkinToCsv -Path $tempFeaturePath -OutPath $outputFilePath

                 Test-Path $outputFilePath | Should -BeTrue
                 $csvContent = Import-Csv -Path $outputFilePath
                 $csvContent.Count | Should -Be 1
                 $csvContent[0].'Col A' | Should -Be 'Val 1'
            } # <- Matches closing brace for try
            finally { # <- Matches opening brace for finally
                 Remove-Item $tempFeaturePath -Force -ErrorAction SilentlyContinue
                 Remove-Item $outputFilePath -Force -ErrorAction SilentlyContinue
            } # <- Matches closing brace for finally
         } # <- Matches closing brace for It
    } # <- Matches closing brace for Context

     Context 'GherkinToCsv Conversion (Pasted Input)' { # <- Matches opening brace for Context
         It 'Should convert pasted Gherkin table to CSV string' { # <- Matches opening brace for It
             $pastedGherkin = @'
 | Header 1 | Header 2 Col |
 | Value A  | 123          |
 | Value B  | 456,789      |
 | "C"      | Test         |
 '@ -split [Environment]::NewLine # Simulate line-by-line input # <- Closing '@ must be at start of line

            # Simulate pasting requires mocking Read-Host or using input redirection/piping
            # Easier approach for testing: Call the internal function directly (less ideal)
            # OR pass the lines via pipeline (if script supports it - requires modification)
            # Let's test by calling the function directly for simplicity here:
            # Note: Need to expose the function or dot-source the script

            # Dot-source the script to make function available
            . $ScriptPath

            $result = ConvertFrom-GherkinTable -GherkinLines $pastedGherkin
            $result | Should -Not -BeNullOrEmpty

            # Expected CSV output (note script's quoting rules: quote if contains space, comma, or quote; escape internal quotes)
            $expectedCsv = @'
Header 1,"Header 2 Col"
Value A,123
Value B,"456,789"
"""C""",Test
'@ # <- FIX: Closing '@ MUST be at the start of the line AND nothing else on the line.

            # Compare line by line after splitting is more robust than direct string compare
            $resultLines = $result.Trim() -split [Environment]::NewLine # Trim trailing newline script might add
            $expectedLines = $expectedCsv.Trim() -split [Environment]::NewLine
            $resultLines.Count | Should -Be $expectedLines.Count

            for($i=0; $i -lt $resultLines.Count; $i++){ # <- Matches opening brace for for
                $resultLines[$i] | Should -Be $expectedLines[$i]
            } # <- Matches closing brace for for

            # Testing the prompt mechanism is harder in Pester without mocking Read-Host
         } # <- Matches closing brace for It

          It 'Should return null or warning if pasted input is not a valid table' { # <- Matches opening brace for It
              . $ScriptPath # Dot-source
              $invalidInput = @( 'Just some text', 'Not a table' )
              $result = ConvertFrom-GherkinTable -GherkinLines $invalidInput
              $result | Should -BeNullOrEmpty
          } # <- Matches closing brace for It
     } # <- Matches closing brace for Context

    # Add more tests for edge cases:
    # - CSV with only headers
    # - Gherkin table with empty cells
    # - Files with mixed content (non-table lines)
    # - Encoding issues (if relevant)
} # <- Matches closing brace for Describe