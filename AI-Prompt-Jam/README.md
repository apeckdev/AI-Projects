# AI Prompt Party

Welcome to AI Prompt Party! This is a web-based, multiplayer party game where players compete to craft the best prompts for a generative AI based on a given problem. It's inspired by games like Jackbox, where players use their devices to interact with a central game screen.

## Features

-   **Multiplayer Gameplay**: Join a game lobby and compete with friends.
-   **Game Master Console**: A dedicated view for the game host to control the flow of the game.
-   **AI-Powered Judging**: Prompts are ranked by Google's Gemini AI, which also provides witty and sarcastic feedback.
-   **Dynamic Scoring**: Points are awarded based on your rank each round.
-   **Live Updates**: Real-time updates using Socket.IO for a seamless experience.
-   **Rejoin In-Progress Games**: If a player disconnects or refreshes, they can automatically rejoin the active game they were in.

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

## How to Play

1.  **Start the Game Master View**
    -   One person needs to be the Game Master (GM). They should open their browser to `http://localhost:3000/gm.html`. This is the main screen that everyone can watch, and it's where the GM controls the game.

2.  **Players Join the Game**
    -   All other players should navigate to `http://localhost:3000/`.
    -   They will be prompted to enter a name to join the lobby.
    -   As players join, their names will appear on both their screens and the GM's screen.

3.  **Start the Game**
    -   Once all players are in the lobby, the GM can click the "Start Game" button.

4.  **Submit Prompts**
    -   A problem or scenario will be presented to all players.
    -   Each player must write a prompt in their text box that they think will get the best response from an AI to solve the problem.
    -   After submitting, they will wait for others to finish. The GM's screen shows who has submitted.

5.  **Judging**
    -   The GM closes submissions once everyone is done.
    -   The server sends all prompts to the Gemini AI, which ranks them and provides feedback.

6.  **Results & Leaderboard**
    -   The results are displayed on all screens, showing the round's winner, the AI-generated solution from the winning prompt, and the rankings for all players.
    -   The GM then proceeds to the leaderboard, which shows the overall scores.

7.  **Continue Playing**
    -   The GM can start the next level, and the cycle continues until the game is over.