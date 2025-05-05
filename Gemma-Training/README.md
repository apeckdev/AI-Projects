# Gemma Training - Gherkin Generation from CSV

## Overview

This directory contains a PowerShell script designed to leverage Ollama (with models like Google's Gemma or others like Llama 3) to convert structured test case data from a CSV file into the Gherkin syntax (`Given/When/Then`).

The primary goal is to automate the creation of Gherkin feature files from existing test case documentation, using the pattern-recognition capabilities of Large Language Models accessed via Ollama.

**Important Note:** This process uses *in-context learning* or *prompt-based generation*. It is **not** true model fine-tuning. The script sends each row of the CSV as part of a detailed prompt to the Ollama model, asking it to generate the corresponding Gherkin scenario based on the provided example structure and instructions within the prompt itself. The quality of the output heavily depends on the chosen model's capabilities, the clarity of the input data, and the effectiveness of the prompt within the script.

## Files

*   **`Generate-GherkinFromCsv.ps1`**: The main PowerShell script that reads the CSV, interacts with the Ollama API (via the `OllamaUtils` module), and generates Gherkin output.
*   **`api_test_cases.csv`**: An example CSV file demonstrating the expected input format. It contains columns for test case descriptions and corresponding steps.

## Prerequisites

1.  **PowerShell:** Version 5.1 or later.
2.  **Ollama:** Must be installed and running locally. Download from [https://ollama.com/](https://ollama.com/).
3.  **Ollama Model:** You need a model downloaded and available in Ollama that is suitable for instruction following and code generation (e.g., Gemma, Llama 3).
    *   Pull a model using: `ollama pull gemma:2b` or `ollama pull llama3` (replace with your desired model).
    *   Verify available models using: `ollama list`.
4.  **`OllamaUtils` PowerShell Module:** This custom module (located in the parent directory `../OllamaUtils`) is required by the `Generate-GherkinFromCsv.ps1` script to interact with the Ollama API.

## Setup

1.  **Ensure Ollama is Running:** Start the Ollama application or service.
2.  **Install the `OllamaUtils` Module:** The `Generate-GherkinFromCsv.ps1` script expects the `OllamaUtils` module to be available in your PowerShell module path. You can copy it there:
    *   Find your user module path: `$env:USERPROFILE\Documents\WindowsPowerShell\Modules`
    *   Copy the `OllamaUtils` directory:
        ```powershell
        # Ensure the destination directory exists
        $modulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
        if (-not (Test-Path -Path $modulePath)) { New-Item -Path $modulePath -ItemType Directory -Force }

        # Copy the module (adjust source path if necessary)
        Copy-Item -Path "..\OllamaUtils" -Destination $modulePath -Recurse -Force
        ```
    *   Verify it's found by PowerShell (you might need to open a new PowerShell session):
        ```powershell
        Get-Module -Name OllamaUtils -ListAvailable
        ```

## Input Data Format (`.csv`)

The script expects a CSV file with columns containing:

1.  **Test Case Description:** A brief summary or title of the test case. (Default column name: `Description`)
2.  **Test Steps:** A detailed, potentially multi-line, description of the steps to execute the test. (Default column name: `Steps`)

See `api_test_cases.csv` for an example. If your CSV uses different column names, you can specify them using the `-DescriptionColumn` and `-StepsColumn` parameters when running the script.

## Usage

Open PowerShell, navigate to the `Gemma-Training` directory, and run the `Generate-GherkinFromCsv.ps1` script.

**Basic Syntax:**

```powershell
.\Generate-GherkinFromCsv.ps1 -CsvPath <path_to_your_csv> -Model <ollama_model_name> [-OutputPath <output_file_path>] [-DescriptionColumn <name>] [-StepsColumn <name>] [-OllamaUri <uri>]
```

## Examples

1.  **Generate Gherkin to Console using `gemma:2b`:**
    ```powershell
    .\Generate-GherkinFromCsv.ps1 -CsvPath .\api_test_cases.csv -Model 'gemma:2b'
    ```

2.  **Generate Gherkin and append to a `.feature` file using `llama3`:**
    ```powershell
    .\Generate-GherkinFromCsv.ps1 -CsvPath .\api_test_cases.csv -Model 'llama3' -OutputPath .\generated_scenarios.feature
    ```

3.  **Using a CSV with different column names:**
    ```powershell
    .\Generate-GherkinFromCsv.ps1 -CsvPath C:\data\my_tests.csv -Model 'gemma:7b' -DescriptionColumn 'Summary' -StepsColumn 'ExecutionSteps' -OutputPath C:\output\tests.feature
    ```

4.  **Connecting to Ollama on a different host/port:**
    ```powershell
    .\Generate-GherkinFromCsv.ps1 -CsvPath .\api_test_cases.csv -Model 'gemma:2b' -OllamaUri 'http://192.168.1.100:11434'
    ```

## Output

*   If `-OutputPath` is **not** specified, the generated Gherkin `Scenario:` blocks are printed directly to the PowerShell console, prefixed with a comment indicating the source description.
*   If `-OutputPath` **is** specified, the script will append the generated Gherkin `Scenario:` blocks to that file. If the file doesn't exist or is empty, it will add a basic `Feature:` header first.

## Customization & Tips

*   **Prompt Engineering:** The quality of the generated Gherkin heavily depends on the system prompt (`$systemPrompt`) and user prompt (`$userPrompt`) variables *inside* the `Generate-GherkinFromCsv.ps1` script. Modify these prompts to better guide the model if the default output isn't satisfactory.
*   **Model Choice:** Experiment with different Ollama models (`-Model` parameter). Larger or instruction-tuned models might produce better results.
*   **Input Data Clarity:** Ensure the `Description` and `Steps` in your CSV are clear and unambiguous. The model works best with well-structured input.
*   **Performance:** Processing large CSV files can be time-consuming as each row requires a separate API call to Ollama.