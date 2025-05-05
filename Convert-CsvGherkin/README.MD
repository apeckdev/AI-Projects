# Convert-CsvGherkin: CSV <=> Gherkin Data Table Converter

This directory contains a PowerShell script (`Convert-CsvGherkin.ps1`) designed to facilitate the conversion of data between standard CSV format and Gherkin data table format (commonly used in Cucumber/SpecFlow `.feature` files).

It's a utility script aimed at assisting with test data management, documentation generation, or migrating data between these formats.

[<- Back to Main Repository README](../README.md)

## Features

*   **CSV to Gherkin:** Converts a CSV file into a Gherkin `Scenario Outline` `Examples:` table format.
*   **Gherkin to CSV:**
    *   Parses a file (e.g., `.feature`) containing Gherkin syntax.
    *   Extracts **all** data tables found within the file.
    *   Saves each extracted table into a separate CSV file.
*   **Pasted Input:** Accepts a Gherkin table pasted directly into the console when no input file is specified (for Gherkin to CSV conversion).
*   **Flexible Output:** Output can be directed to the console or to specified files/directories using the `-OutPath` parameter.
*   **Automatic Naming:** When converting Gherkin files to multiple CSVs, output files are automatically named based on the starting line number of the table (e.g., `gherkin_table_line_15.csv`).
*   **Basic CSV Handling:** Properly quotes CSV fields containing commas, double quotes, or leading/trailing spaces during Gherkin-to-CSV conversion.

## Prerequisites

*   **PowerShell:** Version 5.1 or later is recommended.
*   **(Optional) Pester:** Version 5.0 or later is required to run the included unit tests (`Convert-CsvGherkin.Tests.ps1`).

## Setup

1.  Ensure you have PowerShell installed.
2.  Navigate to this directory (`Convert-CsvGherkin`) in your PowerShell terminal.

## Usage

The script operates based on the mandatory `-Direction` parameter.

```powershell
.\Convert-CsvGherkin.ps1 -Direction <CsvToGherkin | GherkinToCsv> [-Path <InputFilePath>] [-OutPath <OutputFilePathOrDirectory>]
```

### Parameters

*   `-Direction <string>`: **(Mandatory)** Specifies the conversion type.
    *   `CsvToGherkin`: Converts the input CSV file specified by `-Path` to Gherkin format.
    *   `GherkinToCsv`: Converts Gherkin table(s) from the input specified by `-Path` (or pasted input if `-Path` is omitted) to CSV format.
*   `-Path <string>`:
    *   **Required** for `CsvToGherkin`: The path to the input CSV file.
    *   **Optional** for `GherkinToCsv`: The path to the input file containing Gherkin tables (e.g., `my_tests.feature`). If omitted, the script will prompt you to paste the Gherkin table content directly into the console.
*   `-OutPath <string>`: **(Optional)** Controls where the output is saved.
    *   **For `CsvToGherkin`:**
        *   If provided, specifies the *file path* where the Gherkin output should be saved (e.g., `.\output.gherkin`).
        *   If omitted, the Gherkin output is printed to the console.
    *   **For `GherkinToCsv`:**
        *   If provided and it's an existing *directory*, extracted CSV files will be saved inside that directory.
        *   If provided and it's *not* a directory (and only *one* table is found in the input), it's treated as the specific output *file path* for that single CSV.
        *   If omitted (or if `-OutPath` is not a directory and multiple tables are found), extracted CSV files are saved in the *current directory*.
        *   If converting *pasted input*, `-OutPath` is ignored, and CSV output is always printed to the console.

## Examples

1.  **Convert CSV to Gherkin (Output to Console)**
    ```powershell
    .\Convert-CsvGherkin.ps1 -Direction CsvToGherkin -Path .\sample.csv
    ```
    *(This will print a Scenario Outline with the data from `sample.csv`)*

2.  **Convert CSV to Gherkin (Output to File)**
    ```powershell
    .\Convert-CsvGherkin.ps1 -Direction CsvToGherkin -Path .\sample.csv -OutPath .\output\my_scenario.gherkin
    ```
    *(Creates the `.\output` directory if needed and saves the Gherkin table in `my_scenario.gherkin`)*

3.  **Convert Gherkin File to CSV Files (Default Output Directory)**
    ```powershell
    .\Convert-CsvGherkin.ps1 -Direction GherkinToCsv -Path .\sample.feature
    ```
    *(Parses `sample.feature`, finds all tables, and creates CSV files like `gherkin_table_line_8.csv`, `gherkin_table_line_14.csv`, etc., in the current directory.)*

4.  **Convert Gherkin File to CSV Files (Specified Output Directory)**
    ```powershell
    .\Convert-CsvGherkin.ps1 -Direction GherkinToCsv -Path .\sample.feature -OutPath .\extracted_csvs
    ```
    *(Creates the `.\extracted_csvs` directory if needed and saves the output CSV files there.)*

5.  **Convert Pasted Gherkin Table to CSV (Output to Console)**
    ```powershell
    .\Convert-CsvGherkin.ps1 -Direction GherkinToCsv
    ```
    *(The script will prompt: "Please paste your Gherkin table here...". Paste your table, press Enter on an empty line, and the CSV conversion will be printed.)*

    *Example Paste:*
    ```gherkin
    | Header A | Header B |
    | Value 1  | Data X   |
    | Value 2  | Data Y   |

    <Press Enter on this empty line>
    ```

    *Example Output:*
    ```csv
    Header A,"Header B"
    Value 1,"Data X"
    Value 2,"Data Y"
    ```

## Input Format Notes

*   **CSV:** Expects a standard comma-separated values file with a header row as the first line. Fields containing commas, double quotes, or leading/trailing spaces should ideally be enclosed in double quotes (`"`) in the source CSV for reliable parsing by `Import-Csv`.
*   **Gherkin Table:** The script looks for consecutive lines starting and ending with the pipe (`|`) character, forming a table structure. It does not require full Gherkin `Feature` or `Scenario` syntax surrounding the table when parsing, but the table itself (header row + data rows) must be present.

## Testing

Unit tests are provided in `Convert-CsvGherkin.Tests.ps1`. To run them:

1.  Make sure the [Pester](https://pester.dev/) module is installed (`Install-Module Pester -Scope CurrentUser`).
2.  Navigate to this directory (`Convert-CsvGherkin`) in PowerShell.
3.  Run the command: `Invoke-Pester`

The tests cover parameter validation, conversion logic for both directions, file output, and handling of pasted input scenarios.