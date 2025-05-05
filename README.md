# AI Project Viability Assessment

This repository explores the practical viability of applying Artificial Intelligence (or related automation techniques as a baseline for AI) to various tasks through hands-on projects and experiments.

## 🎯 Goal

The primary goal is to build, document, and assess the effectiveness, challenges, and feasibility of using AI and advanced automation for specific real-world use cases. Each project serves as a case study.

## 📚 Overall Assessment Approach

Viability is assessed by:

1.  **Developing Prototypes:** Building functional scripts or applications.
2.  **Identifying Challenges:** Documenting hurdles related to data, APIs, algorithms, setup, and integration.
3.  **Measuring Effectiveness:** Evaluating how well the solution meets the initial requirements (e.g., automation level, accuracy, usability).
4.  **Exploring AI Potential:** Considering where current limitations could potentially be overcome by more sophisticated AI techniques (e.g., using LLMs for generation, ML for prediction/classification).

## 🚀 Projects

This section lists the assessment projects currently included in this repository. For detailed setup and usage instructions, please refer to the `README.md` file within each project's directory.

### 1. Generate Pester Suite from OpenAPI Schema

*   **Directory:** [`Generate-PesterSuite/`](./Generate-PesterSuite/)
*   **Status:** Proof of Concept
*   **Technology Stack:** PowerShell, OpenAPI (v2/v3), Pester
*   **Description:** This project assesses the viability of **automating API test scaffolding**. It provides a PowerShell script (`Generate-PesterFromOpenAPI.ps1`) that generates a basic Pester test suite structure from an OpenAPI specification.
*   **Viability Assessment Focus:**
    *   Feasibility of parsing complex OpenAPI schemas.
    *   Level of effort saved vs. manual test creation.
    *   Limitations of template-based generation (requires significant manual enhancement for auth, parameters, complex assertions).
    *   Potential for future AI enhancement (e.g., using an LLM to suggest more intelligent tests or parameter values based on schema descriptions).

### 2. Jira Workflow UI

*   **Directory:** [`JiraWorkflowUI/`](./JiraWorkflowUI/)
*   **Status:** In Development
*   **Technology Stack:** PowerShell, PowerShell Forms (GUI), Jira REST API, JSON
*   **Description:** This project explores the creation of a custom, actionable **workflow interface interacting with an external API (Jira)**. It features a PowerShell GUI application (`JiraActionBoard.ps1`) displaying Jira tickets fetched via the API, organized into actionable columns.
*   **Viability Assessment Focus:**
    *   Feasibility of building functional GUI applications using PowerShell.
    *   Challenges of interacting with complex APIs (Jira) and handling authentication.
    *   Usability of custom UIs compared to standard web interfaces.
    *   Potential for future AI integration (e.g., AI-powered ticket prioritization, suggesting next actions, summarizing comments).

### 3. CSV <=> Gherkin Data Table Converter

*   **Directory:** [`Convert-CsvGherkin/`](./Convert-CsvGherkin/)
*   **Status:** Utility / Tool
*   **Technology Stack:** PowerShell, Pester (for tests)
*   **Description:** This project provides a PowerShell script (`Convert-CsvGherkin.ps1`) to convert data between CSV format and Gherkin data table format (and vice-versa). It can process files or pasted Gherkin input, useful for managing test data or generating documentation snippets.
*   **Viability Assessment Focus:**
    *   Assess the utility of PowerShell for text parsing and data format transformation tasks, common in test automation and data preparation.
    *   Explore robust handling of file I/O, user input (pasting), and parameter-driven script logic.
    *   Provides a baseline tool against which potential AI-driven data generation or transformation for testing could be compared.

### 4. Gemma Training - Gherkin Generation from CSV

*   **Directory:** [`Gemma-Training/`](./Gemma-Training/)
*   **Status:** Experiment / Proof of Concept
*   **Technology Stack:** PowerShell, Ollama, LLMs (e.g., Gemma, Llama 3), CSV
*   **Description:** This project assesses the use of locally-run Large Language Models (LLMs) via Ollama to **generate Gherkin test scenarios from structured data**. It provides a script (`Generate-GherkinFromCsv.ps1`) that feeds test case descriptions and steps from a CSV to an LLM, prompting it to create corresponding Gherkin `Scenario:` blocks.
*   **Viability Assessment Focus:**
    *   Effectiveness of LLMs (like Gemma 3) for structured code/text generation based on prompts (in-context learning).
    *   Impact of prompt engineering on the quality and consistency of generated Gherkin.
    *   Feasibility of using local LLMs (via Ollama) for development workflow automation.
    *   Comparison of this approach to traditional templating or manual creation.
    *   Understanding the limitations of prompt-based generation vs. fine-tuning for specific formats.

---

## 🛠️ Prerequisites

*   Git (for cloning the repository)
*   PowerShell (specific version requirements may be listed in individual project READMEs)
*   Any other dependencies specific to individual projects (see project READMEs).

## ⚙️ Getting Started

1.  **Clone the repository:**
    ```bash
    git clone <your-repository-url>
    cd <repository-name>
    ```
2.  **Navigate to a project directory:**
    ```bash
    cd Generate-PesterSuite
    # or
    cd JiraWorkflowUI
    # or
    cd Convert-CsvGherkin
    # or
    cd Gemma-Training
    ```
3.  **Follow the instructions** in the `README.md` file within that project's directory for specific setup and execution steps.


---

*This README will be updated as more projects are added or existing ones evolve.*