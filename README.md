# Automation & AI Experiments Showcase

## 🎯 Goal

This repository contains a collection of tools, utilities, and proof-of-concept projects designed to explore the practical application of automation and Artificial Intelligence (AI) techniques to various development and workflow tasks.

The primary goals are to:

1.  **Build Prototypes:** Create functional examples demonstrating specific capabilities.
2.  **Assess Viability:** Evaluate the effectiveness, challenges, and feasibility of each approach.
3.  **Explore Techniques:** Experiment with different technologies, including PowerShell scripting, API interactions, GUI development, and both local and cloud-based AI models.
4.  **Promote Safe AI Use:** Understand the implications of different approaches, particularly the distinction between local processing (safe for internal data) and external API calls (requires careful consideration of data sensitivity).

Each project serves as a case study, documented within its respective directory.

---

## 🚀 Projects Overview

Here's a summary of the projects included in this repository. **For detailed setup, usage, and specific requirements, please refer to the `README.md` file within each project's directory.**

---

### 1. Convert-CsvGherkin

*   **Directory:** [`./Convert-CsvGherkin/`](./Convert-CsvGherkin/)
*   **Description:** A PowerShell utility script for converting data between standard CSV format and Gherkin data table format (used in Cucumber/SpecFlow `.feature` files), and vice-versa. Operates entirely locally.
*   **Technology Stack:** PowerShell
*   **Purpose:** Facilitates test data management and manipulation for BDD workflows through local automation.
*   **Status:** Utility / Tool

---

### 2. Gemini Assistant - Godot Editor Plugin

*   **Directory:** [`./Gemini-Assistant-Godot/`](./Gemini-Assistant-Godot/) *(Assuming a directory name, adjust if different)*
*   **Description:** A plugin for the Godot game engine editor that integrates Google's Gemini AI models. Allows sending prompts and project context (code, scene info) to the external Gemini API for assistance with coding, debugging, etc.
*   **Technology Stack:** Godot (GDScript), Google Gemini API
*   **Purpose:** Demonstrates direct integration of a cloud-based AI assistant into a development environment. **Note:** Requires an API key and sends data externally.
*   **Status:** Plugin / Tool

---

### 3. Gemma Training - Gherkin Generation from CSV

*   **Directory:** [`./Gemma-Training/`](./Gemma-Training/)
*   **Description:** A PowerShell script that uses **locally running** Large Language Models (LLMs like Gemma, Llama 3) via the Ollama framework to generate Gherkin test scenarios (`.feature` file content) from structured data in a CSV file.
*   **Technology Stack:** PowerShell, Ollama, LLMs, CSV
*   **Purpose:** Explores the use of *local* AI (in-context learning) for code/text generation tasks, keeping sensitive data internal. Automates Gherkin creation from test case descriptions.
*   **Status:** Experiment / Proof of Concept

---

### 4. OpenAPI to Pester Test Suite Generator

*   **Directory:** [`./Generate-PesterSuite/`](./Generate-PesterSuite/) *(Assuming a directory name, adjust if different)*
*   **Description:** A PowerShell script that parses an OpenAPI (v2/v3) specification file (JSON) and automatically generates a basic Pester test suite structure, including `.feature` and `.tests.ps1` files for each API endpoint.
*   **Technology Stack:** PowerShell, OpenAPI (JSON), Pester
*   **Purpose:** Assesses the viability of automating API test scaffolding using rule-based generation from API specifications. Provides a non-AI automation baseline.
*   **Status:** Proof of Concept / Tool

---

### 5. Jira Action Board GUI (JiraWorkflowUI)

*   **Directory:** [`./JiraWorkflowUI/`](./JiraWorkflowUI/)
*   **Description:** A PowerShell GUI application (using Windows Forms) that connects to a Jira instance via its REST API to display relevant issues in a customizable, actionable board format.
*   **Technology Stack:** PowerShell (Windows Forms), Jira REST API, JSON
*   **Purpose:** Explores building custom graphical interfaces for interacting with external (non-AI) APIs like Jira to improve specific workflows. Demonstrates handling API keys and data retrieval locally.
*   **Status:** In Development / Tool

---

## 🛠️ General Prerequisites

*   **Git:** For cloning the repository.
*   **PowerShell:** Most scripts require PowerShell 5.1 or later. Specific version requirements may be listed in individual project READMEs.
*   **Other Dependencies:** Individual projects may have unique requirements (e.g., Ollama, Pester module, .NET Framework, API keys) detailed in their respective README files.

## ⚙️ Getting Started

1.  **Clone the repository:**
    ```bash
    git clone <your-repository-url>
    cd <repository-name>
    ```
2.  **Navigate to a project directory:**
    ```bash
    cd Convert-CsvGherkin
    # or
    cd Gemini-Assistant-Godot # Adjust name if needed
    # or
    cd Gemma-Training
    # or
    cd Generate-PesterSuite   # Adjust name if needed
    # or
    cd JiraWorkflowUI
    ```
3.  **Follow the specific instructions** in the `README.md` file within that project's directory for detailed setup, configuration, and usage.

---

*This README provides a high-level overview. Please consult the documentation within each project folder for specifics.*