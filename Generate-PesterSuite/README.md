# OpenAPI to Pester Test Suite Generator (`Generate-PesterFromOpenAPI.ps1`)

This PowerShell script automates the creation of a basic Pester test suite structure based on an OpenAPI (v2/v3) specification file provided in JSON format.

## Description

The script reads an OpenAPI JSON file, identifies the API endpoints (paths and their associated HTTP methods), and generates a corresponding Pester test suite in a self-contained directory. The goal is to provide a starting point or scaffold for API testing, reducing the manual effort required to set up the basic test structure.

For each API endpoint found, the script generates:
1.  A Gherkin-style `.feature` file describing a simple test scenario.
2.  A corresponding `.tests.ps1` file containing a basic Pester test that typically verifies a successful (2xx) status code response.

It also creates helper files within the output directory, including a `run-tests.ps1` script to execute the generated tests, a `.gitignore` file, and a separate `README.md` tailored to the generated test suite itself.

## Initial Prompt
*   Write me a Powershell Script that takes an OpenAPI schema as an argument and creates a pester test suite with feature files based on the endpoints inside of the schema.
*   Each endpoint should have basic tests implemented.
*   It should be output in it's own self-contained directory in the same directory as the script.
*   The script should output a summary that states the tests created and any issues encountered while creating the test suite.

## Features

*   Parses OpenAPI v2/v3 schemas (JSON format only).
*   Identifies API paths and HTTP methods (GET, POST, PUT, DELETE, etc.).
*   Generates `.feature` files using Gherkin syntax for basic scenarios.
*   Generates corresponding `.tests.ps1` Pester scripts with boilerplate test code.
*   Implements a basic "success" test (checking for 2xx status code) for each endpoint.
*   Uses OpenAPI operation summaries and tags (if available) in generated files.
*   Creates a self-contained output directory (defaults to `PesterTestSuite`).
*   Includes helper files (`run-tests.ps1`, `README.md`, `.gitignore`) within the generated suite.
*   Outputs a summary of the generation process, including created files and any errors encountered.

## Requirements (for this Generator Script)

*   **PowerShell:** Version 5.1 or later (due to `#Requires -Version 5.1`).
*   **Pester Module:** Must be installed (`Install-Module Pester -Force -SkipPublisherCheck`). The script includes a `#Requires -Modules Pester` statement. Version 5+ is recommended as the generated `run-tests.ps1` script relies on v5 syntax.
*   **OpenAPI Schema:** The input schema file **must** be in valid **JSON** format. YAML schemas need to be converted to JSON first.

## Usage

Run the script from a PowerShell terminal, providing the path to your OpenAPI JSON file.

```powershell
.\Generate-PesterFromOpenAPI.ps1 -SchemaPath <path-to-your-openapi.json> [-OutputDirectoryName <desired-output-folder-name>]
```

## Parameters:
-SchemaPath (Mandatory): The file path to the OpenAPI schema file (.json).
-OutputDirectoryName (Optional): The name for the output directory where the test suite will be created. Defaults to PesterTestSuite. This directory will be created in the same location as the Generate-PesterFromOpenAPI.ps1 script.

## Examples:
# Generate tests using defaults in the 'PesterTestSuite' directory
.\Generate-PesterFromOpenAPI.ps1 -SchemaPath .\specs\my-api-v1.json

# Specify a custom output directory name
.\Generate-PesterFromOpenAPI.ps1 -SchemaPath C:\Users\Me\Documents\api-spec.json -OutputDirectoryName MyGeneratedApiTests

## Important Notes on Generated Tests
Basic Scaffolding: The generated tests are very basic and serve as a starting point. They primarily check for a 2xx success status code.
Manual Enhancement Required: You must review and enhance the generated .tests.ps1 files to make them meaningful for your specific API. This includes:
*   Setting the API_BASE_URL environment variable before running tests.
*   Implementing correct authentication (e.g., adding API keys or Bearer tokens to $headers).
*   Handling path parameters (e.g., replacing {userId} with actual values).
*   Providing valid request bodies for POST, PUT, PATCH methods.
*   Adding more specific assertions to validate response content, headers, non-2xx status codes, etc.
Refer to Generated README: The README.md file inside the generated output directory provides detailed instructions on how to configure and run the generated test suite.
Overwrites Output: If the specified output directory already exists, this script will delete and recreate it.
JSON Only: Currently, only JSON formatted OpenAPI schemas are supported.