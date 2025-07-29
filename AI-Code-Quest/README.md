# AI Code Quest

## Description

AI Code Quest is an interactive role-playing game designed for developers and QA professionals to test their skills in a series of coding and testing challenges. Players choose a role (DEV or QA) and connect to a game server to receive tasks, submit solutions, and advance through levels. The game master uses an AI-powered validation system to check submissions, providing a dynamic and challenging experience.

## Features

*   **Role-Based Gameplay:** Choose between a Developer (DEV) or Quality Assurance (QA) role, each with a unique set of tasks.
*   **Interactive Client/Server Model:** Players use a PowerShell client to connect to a central game server.
*   **AI-Powered Validation:** The server utilizes an AI model (Ollama) to evaluate player submissions against predefined criteria.
*   **Configurable Quests:** Game quests, tasks, and validation criteria are defined in easily editable JSON files.
*   **Real-time Progress:** Players receive immediate feedback on their submissions and progress through levels upon successful completion of tasks.

## Requirements

*   **PowerShell 5.1 or higher:** The client and server are both PowerShell scripts.
*   **Ollama with a running model (e.g., Gemma):** The server requires access to an Ollama instance for AI-based validation of player submissions. You can download Ollama from [https://ollama.com/](https://ollama.com/).

## How to Play

### 1. Start the Server

First, you need to start the game server. The server listens for player connections, manages game state, and validates submissions.

```powershell
./server.ps1
```

You can also run the server in verbose mode to get more detailed logging:

```powershell
./server.ps1 -Verbose
```

### 2. Start the Client

Once the server is running, players can connect using the client script.

```powershell
./client.ps1
```

The client will prompt you to:
1.  Choose your role (`DEV` or `QA`).
2.  Enter the server's IP address (defaults to `127.0.0.1`).
3.  Enter your name.

After registering, you will receive your first task.

## Roles

### Developer (DEV)

The DEV role focuses on writing and refactoring code. Tasks include creating functions, implementing classes, handling errors, and writing asynchronous code.

### Quality Assurance (QA)

The QA role focuses on testing and quality. Tasks include identifying bugs, writing test cases (in Gherkin and PyTest), creating test plans, and writing formal bug reports.

## Configuration

The game's quests and tasks are configured through JSON files:

*   `po_server_config.json`: This is the main configuration file for the server. It contains the tasks, initial code snippets, and validation criteria for both the DEV and QA roles. You can edit this file to create new quests or modify existing ones.
*   `dev_client_config.json` and `qa_client_config.json`: These files are placeholders for potential client-side configurations based on the chosen role.
