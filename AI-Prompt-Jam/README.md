# AI Prompt Jam

Welcome to AI Prompt Jam! This is a web-based, multiplayer party game where players compete to craft the best prompts for a generative AI. It's inspired by games like Jackbox, where anyone can create or join a game room from a central lobby using their own device.

## Features

-   **Multi-Room Lobbies**: The main page serves as a lobby where players can see all available games, create new ones, and join the game of their choice.
-   **Dynamic Game Creation**: Any player can become a Game Master by creating a new game room with a custom name.
-   **Customizable Level Packs**: Game Masters can choose from different sets of problems (level packs) when creating a game. New packs can be easily added by editing `levels.json`.
-   **AI-Powered Judging**: Prompts are ranked by Google's Gemini AI, which provides witty and insightful feedback on each submission.
-   **Dynamic Scoring**: Points are awarded based on your rank each round, rewarding clever and effective prompt crafting.
-   **Live Updates**: Real-time updates using Socket.IO for a seamless, interactive experience for both players and the Game Master.
-   **Rejoin In-Progress Games**: If a player disconnects, they can rejoin the active game they were in.

## Tech Stack

-   **Backend**: Node.js, Express, Socket.IO
-   **Frontend**: HTML, CSS, JavaScript (no framework)
-   **AI**: Google Gemini API (`@google/generative-ai`)

## Local Setup & Installation

Follow these steps to run the game on your local machine.

1.  **Clone the Repository**
    ```bash
    git clone <your-repo-url>
    cd <repo-directory>
    ```

2.  **Install Dependencies**
    ```bash
    npm install
    ```

3.  **Set Up Environment Variables**
    You'll need a Google Gemini API key.

    -   Create a file named `.env` in the root of the project.
    -   Add your API key to this file:
        ```
        GEMINI_API_KEY="YOUR_API_KEY_HERE"
        ```

4.  **Run the Server**
    ```bash
    node server.js
    ```
    The server will start, typically on port 3000. You'll see the message `Server listening on port 3000` in your console.

5.  **(Optional) Customize Levels**
    -   Open the `levels.json` file to edit existing problems or add your own new level packs.

## How to Play

1.  **Everyone Navigates to the Lobby**
    -   All players should open their browser and navigate to `http://localhost:3000/`.
    -   This page shows two lists: "Joinable Games" and "Active Games".

2.  **Create a Game (Game Master)**
    -   One person who will be the Game Master (GM) should click the "Create New Game" button.
    -   A modal will appear. The GM must enter a unique **Room Name** and select a **Level Pack** for the game.
    -   Upon clicking "Create Game", they will be automatically redirected to the Game Master view for their new room. This GM view (`gm.html?roomId=...`) should be the main screen that everyone can watch (e.g., shared on a TV or via screen share).

3.  **Join the Game (Players)**
    -   Once the GM creates the game, it will appear in the "Joinable Games" list on the main lobby page for all other players.
    -   Players click the "Join" button next to the correct room name.
    -   A modal will appear asking for their name. After entering a name, they will be taken to that room's private lobby.
    -   As players join, their names will appear on their screens and on the GM's main screen.

4.  **Start the Game**
    -   Once all players are in the room's lobby, the GM can click the "Start Game" button on their console to begin.

5.  **Gameplay Loop**
    -   **Submit Prompts**: A problem is presented to all players. Each player writes a prompt to solve the problem and submits it. The GM's screen shows who has submitted.
    -   **Judging**: Once everyone is done, the GM closes submissions. All prompts are sent to the Gemini AI for ranking and feedback.
    -   **Results & Leaderboard**: The results are displayed on all screens, showing the round's winner, the AI-generated solution from the winning prompt, and player rankings. The GM then shows the overall leaderboard.
    -   **Continue Playing**: The GM starts the next level, and the cycle continues until all levels in the pack are completed.