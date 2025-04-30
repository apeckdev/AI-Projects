#Requires -Version 5.1
#Requires -Modules Pester

<#
.SYNOPSIS
    Generates a basic Pester test suite from an OpenAPI (v2/v3) schema file (JSON format).

.DESCRIPTION
    This script reads an OpenAPI schema file (in JSON format), identifies the API endpoints (paths and methods),
    and creates a structured Pester test suite in a subdirectory.
    For each endpoint (path + HTTP method combination), it generates:
    1. A Gherkin-style .feature file describing a basic scenario.
    2. A corresponding .tests.ps1 file implementing a basic Pester test (checking for a 2xx success status code).

    The script creates a self-contained directory named 'PesterTestSuite' (by default)
    in the same location as the script itself. It outputs a summary of the generated files and any issues encountered.

.PARAMETER SchemaPath
    The mandatory path to the OpenAPI schema file (must be in JSON format).

.PARAMETER OutputDirectoryName
    The name for the output directory that will contain the generated test suite. Defaults to 'PesterTestSuite'.

.EXAMPLE
    .\Generate-PesterFromOpenAPI.ps1 -SchemaPath .\path\to\your\openapi.json

.EXAMPLE
    .\Generate-PesterFromOpenAPI.ps1 -SchemaPath C:\schemas\api-spec.json -OutputDirectoryName MyApiTests

.NOTES
    - Requires the Pester module to be installed (`Install-Module Pester -Force -SkipPublisherCheck`).
    - Currently only supports OpenAPI schema files in JSON format. YAML files must be converted to JSON first.
    - The generated tests are basic (checking for 2xx status code). They assume the API base URL and any necessary
      authentication (like API keys) are provided via environment variables ($env:API_BASE_URL, $env:API_KEY)
      or by modifying the generated test files or the 'run-tests.ps1' script.
    - The generated tests do not automatically handle path parameters (like /users/{id}), body payloads for POST/PUT,
      or complex query parameters. These need to be manually implemented in the '.tests.ps1' files.
    - The script will overwrite the output directory if it already exists.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false, HelpMessage = "Path to the OpenAPI schema file (JSON format).")]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$SchemaPath,

    [Parameter(Mandatory = $false, HelpMessage = "Name for the output directory. Defaults to 'PesterTestSuite'.")]
    [string]$OutputDirectoryName = "PesterTestSuite"
)

# --- Script Setup ---
$ErrorActionPreference = 'Stop'
Clear-Host

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputBasePath = Join-Path -Path $scriptDir -ChildPath $OutputDirectoryName
$featuresDir = Join-Path -Path $outputBasePath -ChildPath "Features"
$testsDir = Join-Path -Path $outputBasePath -ChildPath "Tests"

$summary = @{
    SchemaFile      = $SchemaPath
    OutputDirectory = $outputBasePath
    FeaturesCreated = 0
    TestsCreated    = 0
    EndpointsFound  = 0
    Errors          = [System.Collections.Generic.List[string]]::new()
    Skipped         = [System.Collections.Generic.List[string]]::new()
}

# --- Helper Function ---
function Sanitize-PathForFileName {
    param(
        [string]$Path
    )
    # Remove leading/trailing slashes, replace slashes with underscores, remove curly braces
    $sanitized = $Path.Trim('/') -replace '/', '_' -replace '[{}]', ''
    # Remove potentially problematic characters for filenames
    $sanitized = $sanitized -replace '[^a-zA-Z0-9_-]', ''
    if ([string]::IsNullOrWhiteSpace($sanitized)) {
        # Fallback if the path was only invalid chars (unlikely for OpenAPI)
        return "endpoint_$(Get-Random)"
    }
    return $sanitized
}

# --- Main Script Logic ---

Write-Host "Starting Pester test suite generation from OpenAPI schema..."
Write-Host "Schema file: $SchemaPath"

# 1. Validate Schema File Type (Basic Check)
if ($SchemaPath -notlike '*.json') {
    $summary.Errors.Add("Input file '$SchemaPath' is not a .json file. This script currently only supports JSON format.")
    # Stop execution cleanly after adding the error
    Write-Warning "Input file must be in JSON format."
    # Output summary before exiting
    Write-Host "`n--- Generation Summary ---"
    Write-Host "Schema File: $($summary.SchemaFile)"
    Write-Host "Output Directory: $($summary.OutputDirectory) (Not Created)"
    Write-Host "Endpoints Found: $($summary.EndpointsFound)"
    Write-Host "Feature Files Created: $($summary.FeaturesCreated)"
    Write-Host "Test Scripts Created: $($summary.TestsCreated)"
    if ($summary.Errors.Count -gt 0) {
        Write-Host "`nErrors Encountered:" -ForegroundColor Red
        $summary.Errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    }
    exit 1
}


# 2. Load and Parse OpenAPI Schema
$openApiSchema = $null
try {
    Write-Verbose "Loading and parsing OpenAPI JSON file..."
    $schemaContent = Get-Content -Path $SchemaPath -Raw
    $openApiSchema = $schemaContent | ConvertFrom-Json -ErrorAction Stop
    Write-Verbose "Schema loaded successfully."
}
catch {
    $summary.Errors.Add("Failed to parse OpenAPI JSON file '$SchemaPath': $($_.Exception.Message)")
    # Stop execution cleanly
    Write-Error "Failed to parse JSON schema. Please ensure it's valid JSON."
    # Output summary before exiting (similar to above)
    # (Duplicate code, could be refactored into a function if larger)
    Write-Host "`n--- Generation Summary ---"
    Write-Host "Schema File: $($summary.SchemaFile)"
    Write-Host "Output Directory: $($summary.OutputDirectory) (Not Created)"
    Write-Host "Endpoints Found: $($summary.EndpointsFound)"
    Write-Host "Feature Files Created: $($summary.FeaturesCreated)"
    Write-Host "Test Scripts Created: $($summary.TestsCreated)"
    if ($summary.Errors.Count -gt 0) {
        Write-Host "`nErrors Encountered:" -ForegroundColor Red
        $summary.Errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    }
    exit 1
}

# Check for essential 'paths' property
if (-not $openApiSchema.paths) {
    $summary.Errors.Add("The OpenAPI schema does not contain the required 'paths' property.")
    Write-Error "Schema missing 'paths' property."
     # Output summary before exiting
    Write-Host "`n--- Generation Summary ---"
    Write-Host "Schema File: $($summary.SchemaFile)"
    Write-Host "Output Directory: $($summary.OutputDirectory) (Not Created)"
    Write-Host "Endpoints Found: $($summary.EndpointsFound)"
    Write-Host "Feature Files Created: $($summary.FeaturesCreated)"
    Write-Host "Test Scripts Created: $($summary.TestsCreated)"
    if ($summary.Errors.Count -gt 0) {
        Write-Host "`nErrors Encountered:" -ForegroundColor Red
        $summary.Errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    }
    exit 1
}


# 3. Create Output Directory Structure
Write-Host "Creating output directory: $outputBasePath"
try {
    if (Test-Path $outputBasePath) {
        Write-Verbose "Removing existing directory: $outputBasePath"
        Remove-Item -Recurse -Force -Path $outputBasePath
    }
    New-Item -ItemType Directory -Path $outputBasePath | Out-Null
    New-Item -ItemType Directory -Path $featuresDir | Out-Null
    New-Item -ItemType Directory -Path $testsDir | Out-Null
    Write-Verbose "Output directories created."
}
catch {
    $summary.Errors.Add("Failed to create output directory structure at '$outputBasePath': $($_.Exception.Message)")
    Write-Error "Could not create output directories. Check permissions."
     # Output summary before exiting
    Write-Host "`n--- Generation Summary ---"
    Write-Host "Schema File: $($summary.SchemaFile)"
    Write-Host "Output Directory: $($summary.OutputDirectory) (Creation Failed)"
    Write-Host "Endpoints Found: $($summary.EndpointsFound)"
    Write-Host "Feature Files Created: $($summary.FeaturesCreated)"
    Write-Host "Test Scripts Created: $($summary.TestsCreated)"
    if ($summary.Errors.Count -gt 0) {
        Write-Host "`nErrors Encountered:" -ForegroundColor Red
        $summary.Errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    }
    exit 1
}


# 4. Iterate Through Paths and Methods to Generate Files
Write-Host "Generating test files..."

# Get the paths object (which is a PSCustomObject where property names are the paths)
$paths = $openApiSchema.paths

# Iterate through each path property (e.g., '/users', '/users/{id}')
foreach ($pathProperty in $paths.PSObject.Properties) {
    $path = $pathProperty.Name
    $pathItem = $pathProperty.Value # This object contains methods like 'get', 'post'

    # Iterate through each HTTP method defined for the current path
    foreach ($methodProperty in $pathItem.PSObject.Properties) {
        $method = $methodProperty.Name.ToUpper()
        $operation = $methodProperty.Value # Details about the operation (summary, description, etc.)

        # Basic check if it looks like an HTTP method
        if ($method -notin @('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS', 'HEAD', 'TRACE')) {
            $summary.Skipped.Add("Skipping non-standard HTTP method '$($methodProperty.Name)' found at path '$path'.")
            Write-Verbose "Skipping non-standard method '$($methodProperty.Name)' for path '$path'."
            continue
        }

        $summary.EndpointsFound++
        Write-Verbose "Processing: $method $path"

        # Generate sanitized base filename
        $baseFileName = "$(Sanitize-PathForFileName -Path $path)_$($method.ToLower())"
        $featureFilePath = Join-Path -Path $featuresDir -ChildPath "$baseFileName.feature"
        $testFilePath = Join-Path -Path $testsDir -ChildPath "$baseFileName.tests.ps1"

        # Get Operation Summary or use default
        $operationSummary = $operation.summary -replace '"','' # Basic sanitization for feature file
        if ([string]::IsNullOrWhiteSpace($operationSummary)) {
            $operationSummary = "Basic $method request"
        }

        # Get tags if available
        $pesterTags = @($method) # Always tag with the method
        if ($operation.tags -is [array] -and $operation.tags.Count -gt 0) {
           $pesterTags += $operation.tags | Where-Object { -not [String]::IsNullOrWhiteSpace($_) }
        }
        # --- CORRECTED LINE ---
        $pesterTagsString = ($pesterTags | ForEach-Object { "'$_'" }) -join ', '
        # --- END CORRECTION ---


        # --- Generate Feature File Content ---
        $featureContent = @"
Feature: $path - $method Endpoint ($operationSummary)

  Scenario: Basic successful $method request to $path
    Given a valid base API URL and necessary credentials
    When a $method request is sent to "$path"
    Then the response status code should indicate success (2xx)
    # And the response content type should be appropriate (e.g., application/json) # Example of another potential step
"@

# --- Generate Pester Test File Content ---
        # Note: Assumes $env:API_BASE_URL and $env:API_KEY exist. Users must configure these.
        $testContent = @"
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for the $method $path endpoint.
    Generated by Generate-PesterFromOpenAPI.ps1 script.
#>

param(
    # Base URL for the API. Default attempts to read from environment variable.
    [string]`$BaseUrl = `$env:API_BASE_URL, # Use backticks to escape $

    # API Key if needed for authentication. Default attempts to read from environment variable.
    [string]`$ApiKey = `$env:API_KEY # Use backticks to escape $ - Modify or remove if using different auth
)

BeforeAll {
    if ([string]::IsNullOrWhiteSpace(`$BaseUrl)) { # Use backtick to escape $
        # Use backticks to escape $env:API_BASE_URL and $BaseUrl
        Write-Warning "API Base URL (`$env:API_BASE_URL or -BaseUrl parameter) is not set. Tests will likely fail."
        # You might want to throw here to stop execution if BaseUrl is mandatory
        # throw "API Base URL is required."
    }
    # Add other setup tasks if needed (e.g., check for API Key)
    # if ([string]::IsNullOrWhiteSpace(`$ApiKey)) {
    #     Write-Warning "API Key (`$env:API_KEY or -ApiKey parameter) is not set. Authentication tests might fail."
    # }
}

Describe "$method $path Endpoint Tests" -Tags $pesterTagsString { # $method, $path, $pesterTagsString are expanded by the *generator*

    Context "Basic $method Request" { # $method expanded by the *generator*

        It "Should return a successful status code (2xx)" {
            # TODO: Handle path parameters (e.g., replace {id} with a valid value) if '$path' contains them.
            `$requestPath = '$path' # Use backtick for literal $requestPath. $path is expanded by the generator.

            # Example Parameter Handling (Uncomment and adapt if needed):
            # if (`$requestPath -match '\{(.+?)\}') { # Use backtick for literal $requestPath
            #     `$paramName = `$Matches[1] # Use backtick for literal $paramName, $Matches
            #     Write-Warning "Test for path '$path' requires parameter '{`$`$paramName}'. Using placeholder '1'." # Escape $ for literal ${paramName} output
            #     `$requestPath = `$requestPath -replace "\{\$`$paramName\}", "1" # Use backtick for literal $requestPath, escape $ for literal ${paramName}
            # }

            # Use backticks for literal $uri, $BaseUrl, $requestPath in the generated script
            `$uri = "`$BaseUrl`$requestPath"

            # TODO: Add authentication headers if needed. Example for Bearer token:
            `$headers = @{} # Use backtick for literal $headers
            # if (-not [string]::IsNullOrWhiteSpace(`$ApiKey)) { # Use backtick for literal $ApiKey
            #    `$headers.Add('Authorization', "Bearer `$ApiKey") # Use backtick for literal $headers, $ApiKey
            # }
            # Or add API Key header directly:
            # if (-not [string]::IsNullOrWhiteSpace(`$ApiKey)) { # Use backtick for literal $ApiKey
            #    `$headers.Add('X-API-Key', `$ApiKey) # Adjust header name as needed # Use backtick for literal $headers, $ApiKey
            # }

            # TODO: Add body for POST/PUT/PATCH methods if required.
            # `$body = @{ key = 'value' } | ConvertTo-Json # Example body # Use backtick for literal $body

            # Use backtick for literal $uri in the generated script's Write-Verbose
            Write-Verbose "Sending $method request to `$uri" # $method expanded by generator

            try {
                # Use Invoke-WebRequest to easily access status code, even for non-2xx by default (though it throws on 4xx/5xx)
                # Use -SkipHttpErrorCheck with Invoke-RestMethod if you prefer that and want to check status manually for all cases
                # Ensure $headers and potentially $body are defined correctly above this try block
                # Use backticks for literal $response, $uri, $headers. '$method' is literal string here. $body needs backtick if used.
                `$response = Invoke-WebRequest -Uri `$uri -Method '$method' -Headers `$headers -ErrorAction Stop # Add -Body `$body if needed

                # Check if status code is in the 200-299 range
                # Use backtick for literal $response
                `$response.StatusCode | Should -BeInRange 200 299
            }
            catch {
                # If Invoke-WebRequest throws (likely 4xx or 5xx), fail the test and show the error
                # We want the literal '$($_.Exception.Message)' in the output file. Escape the outer '$'.
                Write-Error "Request failed: `$(`$_.Exception.Message)"
                # We want the literal '$_.Exception.Response' in the output file. Escape the '$'.
                if (`$_.Exception.Response) {
                   # We want the literal '$($_.Exception.Response.StatusCode)' in the output file. Escape the outer '$'.
                   Write-Error "Response Status Code: `$(`$_.Exception.Response.StatusCode)"
                   # Try to get response body if available
                   try {
                       # We want the literal '$_.Exception.Response.GetResponseStream()' in the output file. Escape the '$'.
                       # Define literal $responseStream variable inside the catch block
                       `$responseStream = `$_.Exception.Response.GetResponseStream()
                       # Use literal $responseStream variable from *within* this catch block
                       `$streamReader = New-Object System.IO.StreamReader(`$responseStream)
                       # Use literal $responseBody variable
                       `$responseBody = `$streamReader.ReadToEnd()
                       `$streamReader.Close()
                       `$responseStream.Close()
                       # Expand the variable $responseBody *within the generated script's context*. Escape the outer '$'.
                       Write-Error "Response Body: `$(`$responseBody)"
                   } catch {
                       Write-Warning "Could not read response body from exception."
                   }
                } else {
                   Write-Warning "No response object found in the exception."
                }
                # Fail the test explicitly to make it clear
                # Expand the variable $uri *within the generated script's context*. Escape the outer '$'.
                Throw "Request to `$(`$uri) failed."
            }
        }

        # TODO: Add more basic tests as needed.
        # It "Should return the correct Content-Type" {
        #     # ... similar request logic ...
        #     # Note: Invoke-WebRequest response object has Headers property
        #     # `$response = Invoke-WebRequest ... # Use backtick for literal $response
        #     # `$response.Headers.'Content-Type' | Should -Match 'application/json' # Adjust expected type # Use backtick for literal $response
        # }
    }
}
"@

        # --- Write Files ---
        try {
            $featureContent | Out-File -FilePath $featureFilePath -Encoding UTF8
            $summary.FeaturesCreated++
            Write-Verbose "  Created feature file: $featureFilePath"

            $testContent | Out-File -FilePath $testFilePath -Encoding UTF8
            $summary.TestsCreated++
            Write-Verbose "  Created test file: $testFilePath"
        }
        catch {
            $errorMessage = "Failed to write files for $method $path $($_.Exception.Message)"
            $summary.Errors.Add($errorMessage)
            Write-Warning $errorMessage
            # Attempt to clean up potentially partially created files for this endpoint
            if (Test-Path $featureFilePath) { Remove-Item $featureFilePath -Force }
            if (Test-Path $testFilePath) { Remove-Item $testFilePath -Force }
            # Decrement counts if files were not successfully created
             # Safely decrement only if greater than 0
             if ($summary.FeaturesCreated -gt 0) { $summary.FeaturesCreated-- }
             if ($summary.TestsCreated -gt 0) { $summary.TestsCreated-- }

        }
    } # End method loop
} # End path loop


# 5. Generate Helper Files (run-tests.ps1, .gitignore, README.md)
Write-Host "Generating helper files..."

# --- run-tests.ps1 ---
$runTestsContent = @"
#Requires -Modules Pester

<#
.SYNOPSIS
    Runs the Pester tests generated for the API.
.DESCRIPTION
    This script executes all .tests.ps1 files located in the .\Tests subdirectory.
    It assumes that necessary environment variables (like API_BASE_URL, API_KEY)
    are set before running this script, or they are passed as parameters to the
    individual test files if modified to accept them.
#>

# Set error action preference for the runner script
`$ErrorActionPreference = 'Stop' # EXECUTES - Needs escape

Write-Host "Starting Pester tests..."

# --- Configuration ---
# Check if Base URL is set via environment variable (recommended)
if (-not `$env:API_BASE_URL) { # EXECUTES - Needs escape
    Write-Warning "Environment variable 'API_BASE_URL' is not set. Tests might fail to connect."
    Write-Warning "You can set it before running this script, e.g., in PowerShell:"
    # This is a comment showing example usage, the literal $ is fine here within the comment string.
    # For the warning output itself, keep the escape so the generated file shows the example correctly.
    Write-Warning "`$env:API_BASE_URL='http://your-api-url'"
    # Optionally, provide a default value here if suitable for your environment, but env var is better practice.
    # $env:API_BASE_URL = "http://localhost:8080" # COMMENT - No escape needed/desired here
} else {
     Write-Host "Using API Base URL: `$env:API_BASE_URL" # EXECUTES - Needs escape
}
# Check for API Key (Optional based on your API)
if (-not `$env:API_KEY) { # EXECUTES - Needs escape
    Write-Warning "Environment variable 'API_KEY' is not set. Tests requiring authentication might fail."
    # Note: The individual test files handle the actual usage of $env:API_KEY # COMMENT - No escape needed
}

# --- Pester Execution ---
`$pesterConfiguration = @{ # EXECUTES - Needs escape
    Run = @{
        Path = '.\Tests' # Relative path to the test scripts
        # PassThru = $true # COMMENT - No escape needed/desired here
        # ExcludePath = # Add paths to exclude if needed
    }
    Output = @{
        Verbosity = 'Detailed' # Options: Quiet, Normal, Detailed, Diagnostic
    }
    TestResult = @{
        Enabled = `$true # EXECUTES - Needs escape
        OutputPath = 'TestResults.xml' # Default output path/name
        TestSuiteName = 'OpenAPI Generated API Tests'
    }
    # Filter = @{ # Optional: Filter tests by Tag
    #    Tag = 'GET' # Example: Run only GET request tests
    # }
    # CodeCoverage = @{ # Optional: Configure code coverage if testing PowerShell modules
    #    Enabled = $false # COMMENT - No escape needed/desired here
    # }
}


# Execute Pester tests
# Wrap in try/catch to handle potential Pester execution errors
try {
    Write-Host "Invoking Pester with configuration:"
    Write-Host (`$pesterConfiguration | ConvertTo-Json -Depth 4) # EXECUTES - Needs escape
    `$result = Invoke-Pester -Configuration `$pesterConfiguration # EXECUTES - Needs escape
} catch {
    Write-Error "An error occurred during Pester execution: `$(`$_.Exception.Message)" # EXECUTES - Needs escape
    # Exit with a specific error code for runner failure
    exit 2
}


# Check results and exit with appropriate code
if (`$null -eq `$result) { # EXECUTES - Needs escape
     Write-Error "Pester execution did not return results. Check Pester installation and configuration."
     exit 3
}

if (`$result.FailedCount -gt 0) { # EXECUTES - Needs escape
    Write-Host "`nPester tests finished with `$(`$result.FailedCount) failure(s)." -ForegroundColor Red # EXECUTES - Needs escape
    exit 1 # Standard exit code for test failures
} else {
    Write-Host "`nPester tests finished successfully (`$(`$result.PassedCount) passed)." -ForegroundColor Green # EXECUTES - Needs escape
    exit 0 # Standard exit code for success
}
"@
try {
    $runTestsPath = Join-Path -Path $outputBasePath -ChildPath "run-tests.ps1"
    $runTestsContent | Out-File -FilePath $runTestsPath -Encoding UTF8
    Write-Verbose "Created helper script: $runTestsPath"
} catch {
    $summary.Errors.Add("Failed to write run-tests.ps1: $($_.Exception.Message)")
}

# --- .gitignore ---
$gitIgnoreContent = @"
# Pester / PowerShell specific
**/Pester_Output/
**/TestResults/
TestResults.xml
junit.xml
nunit.xml

# VS Code specific
.vscode/

# macOS specific
.DS_Store

# Environment files (if you use a .env pattern)
# .env

# Configuration files (if you create local overrides)
# config.local.ps1
"@
try {
    $gitIgnorePath = Join-Path -Path $outputBasePath -ChildPath ".gitignore"
    $gitIgnoreContent | Out-File -FilePath $gitIgnorePath -Encoding UTF8
    Write-Verbose "Created helper file: $gitIgnorePath"
} catch {
    $summary.Errors.Add("Failed to write .gitignore: $($_.Exception.Message)")
}

# --- README.md ---
$readmeContent = @"
# API Test Suite (Generated from OpenAPI)

This directory contains a basic Pester test suite generated from the OpenAPI schema: `$($Summary.SchemaFile)`

## Structure

-   `$($OutputDirectoryName)/`
    -   `Features/`: Contains Gherkin `.feature` files describing test scenarios for each endpoint.
    -   `Tests/`: Contains Pester `.tests.ps1` scripts that implement the steps defined in the feature files.
    -   `run-tests.ps1`: A PowerShell script to execute all tests in the `Tests` directory.
    -   `.gitignore`: Standard git ignore file for Pester projects.
    -   `README.md`: This file.
    -   `TestResults.xml`: (Generated by `run-tests.ps1`) Test results in NUnit XML format.

## Prerequisites

1.  **PowerShell:** Version 5.1 or later.
2.  **Pester Module:** Version 5 or later recommended. Install/Update using `Install-Module Pester -Force -SkipPublisherCheck` in PowerShell (may require running as Administrator).
3.  **API Access:** The target API must be running and accessible from where you run the tests.

## Configuration

The generated tests in the `.\Tests` folder rely on **environment variables** for configuration:

-   **`API_BASE_URL` (Required):** The base URL of the API (e.g., `http://localhost:5000/api`, `https://api.example.com/v1`). The `run-tests.ps1` script will warn if this is not set.
-   **`API_KEY` (Optional):** An API key or token if required for authentication. The tests include commented-out examples for Bearer token or custom header authentication (like `X-API-Key`).

**You MUST review and potentially modify the `.tests.ps1` files to:**

1.  **Implement Authentication:** Uncomment and adapt the `$headers` section in each test file according to your API's authentication mechanism (Bearer token, API Key header, etc.). Use the `$ApiKey` parameter (which reads `$env:API_KEY`).
2.  **Handle Path Parameters:** If an endpoint path contains parameters (e.g., `/users/{id}`), you need to modify the test script to replace the placeholder (`{id}`) with a valid value. Examples are commented out in the tests.
3.  **Provide Request Bodies:** For `POST`, `PUT`, `PATCH` requests, uncomment and populate the `$body` variable with a valid JSON payload.
4.  **Refine Assertions:** Add more specific tests (`Should...`) to validate response bodies, headers, specific status codes (beyond just 2xx), timings, etc.

**Setting Environment Variables (Example):**

Open PowerShell and run these commands before executing `run-tests.ps1`:

```powershell
# Make sure to replace with your actual values
\$env:API_BASE_URL = "http://localhost:8080/v2" # Example using PetStore default
\$env:API_KEY = "your-secret-api-key-if-needed"
"@