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
$ErrorActionPreference = 'Stop' # EXECUTES - Needs escape

Write-Host "Starting Pester tests..."

# --- Configuration ---
# Check if Base URL is set via environment variable (recommended)
if (-not $env:API_BASE_URL) { # EXECUTES - Needs escape
    Write-Warning "Environment variable 'API_BASE_URL' is not set. Tests might fail to connect."
    Write-Warning "You can set it before running this script, e.g., in PowerShell:"
    # This is a comment showing example usage, the literal $ is fine here within the comment string.
    # For the warning output itself, keep the escape so the generated file shows the example correctly.
    Write-Warning "$env:API_BASE_URL='http://your-api-url'"
    # Optionally, provide a default value here if suitable for your environment, but env var is better practice.
    #  = "http://localhost:8080" # COMMENT - No escape needed/desired here
} else {
     Write-Host "Using API Base URL: $env:API_BASE_URL" # EXECUTES - Needs escape
}
# Check for API Key (Optional based on your API)
if (-not $env:API_KEY) { # EXECUTES - Needs escape
    Write-Warning "Environment variable 'API_KEY' is not set. Tests requiring authentication might fail."
    # Note: The individual test files handle the actual usage of  # COMMENT - No escape needed
}

# --- Pester Execution ---
$pesterConfiguration = @{ # EXECUTES - Needs escape
    Run = @{
        Path = '.\Tests' # Relative path to the test scripts
        # PassThru = True # COMMENT - No escape needed/desired here
        # ExcludePath = # Add paths to exclude if needed
    }
    Output = @{
        Verbosity = 'Detailed' # Options: Quiet, Normal, Detailed, Diagnostic
    }
    TestResult = @{
        Enabled = $true # EXECUTES - Needs escape
        OutputPath = 'TestResults.xml' # Default output path/name
        TestSuiteName = 'OpenAPI Generated API Tests'
    }
    # Filter = @{ # Optional: Filter tests by Tag
    #    Tag = 'GET' # Example: Run only GET request tests
    # }
    # CodeCoverage = @{ # Optional: Configure code coverage if testing PowerShell modules
    #    Enabled = False # COMMENT - No escape needed/desired here
    # }
}


# Execute Pester tests
# Wrap in try/catch to handle potential Pester execution errors
try {
    Write-Host "Invoking Pester with configuration:"
    Write-Host ($pesterConfiguration | ConvertTo-Json -Depth 4) # EXECUTES - Needs escape
    $result = Invoke-Pester -Configuration $pesterConfiguration # EXECUTES - Needs escape
} catch {
    Write-Error "An error occurred during Pester execution: $($_.Exception.Message)" # EXECUTES - Needs escape
    # Exit with a specific error code for runner failure
    exit 2
}


# Check results and exit with appropriate code
if ($null -eq $result) { # EXECUTES - Needs escape
     Write-Error "Pester execution did not return results. Check Pester installation and configuration."
     exit 3
}

if ($result.FailedCount -gt 0) { # EXECUTES - Needs escape
    Write-Host "
Pester tests finished with $($result.FailedCount) failure(s)." -ForegroundColor Red # EXECUTES - Needs escape
    exit 1 # Standard exit code for test failures
} else {
    Write-Host "
Pester tests finished successfully ($($result.PassedCount) passed)." -ForegroundColor Green # EXECUTES - Needs escape
    exit 0 # Standard exit code for success
}
