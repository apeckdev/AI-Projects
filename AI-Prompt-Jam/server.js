// Import necessary libraries
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const crypto = require('crypto');
require('dotenv').config();
const { GoogleGenerativeAI, HarmCategory, HarmBlockThreshold } = require('@google/generative-ai');

// --- Server Setup ---
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*", // Allow connections from any origin
    methods: ["GET", "POST"]
  }
});
const PORT = process.env.PORT || 3000;

app.use(express.static('public'));

// --- Gemini API Setup ---
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({
    model: "gemini-2.5-pro",
    safetySettings: [
        { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
        { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
    ],
    generationConfig: {
        responseMimeType: "application/json" // Enforce JSON output for ranking
    }
});
const solutionModel = genAI.getGenerativeModel({ model: "gemini-1.5-pro-latest" });


// --- Hardcoded Game Content (Reformatted for Readability) ---
const gameLevels = [
    {
        level: 1,
        problem: `A junior developer has created a non-RESTful API endpoint:

    \`POST /api/users?action=create&name=JohnDoe&email=john@example.com\`

Write a prompt for AI that refactors this into a proper RESTful endpoint and implements a testing solution for the endpoint.

Consider being creative with the tools used for testing (e.g., Postman, curl, unit tests).`
    },
    {
        level: 2,
        problem: `A frantic message comes from the support team: 'Our top enterprise client, MegaCorp, is completely blocked! They're getting a '500 Internal Server Error' on their main invoice processing page and threatening to cancel. We need a hotfix immediately!'
        
Write a prompt for AI to act as a team lead and create a comprehensive action plan.

Consider all team responsibilities, i.e. DEV/QA/PO`
    },
    {
        level: 3,
        problem: `You have a complex C# function:

    \`public decimal CalculateProratedSubscription(DateTime startDate, DateTime endDate, decimal monthlyRate)\`

Write a prompt for an AI to generate a comprehensive suite of xUnit tests for this function, ensuring it covers as many edge cases as possible.

Consider edge cases like leap years, month-end dates, and invalid date ranges.`
    },
    {
        level: 4,
        problem: `Management has submitted a vague feature request: 'We need to improve the user dashboard. Make it look better and run faster.'

Write a prompt for an AI to act as a product owner and break this request down into a structured set of Jira tickets.

Consider coming up with an Epic that would resolve the feature request and having AI create the tickets for it.`
    },
    {
        level: 5,
        problem: `A new user login page needs to be created. It should handle all the normal things a user login page handles.

Write a prompt for AI to prototype the login page. 

Consider including notes about styling and security features.`
    }
];

// --- Game State Management ---
let gameState = { players: {}, gameMasterSocketId: null, currentLevel: 0, gameStarted: false, prompts: {}, phase: 'LOBBY', lastRoundResults: null };
let socketIdToPlayerIdMap = {};

// --- Helper Functions ---
async function getGeminiRanking(playerPrompts, problem) {
    console.log("Calling Gemini API for structured ranking...");
    const metaPrompt = `
        You are a judge for an AI a prompt-crafting game. Your personality is but brilliant prompt engineer who has used AI on a daily basis seen it all.

        The problem is: "${problem}"

        Here are the user prompts to rank:
        ${JSON.stringify(playerPrompts, null, 2)}

        Your task is to rank these prompts from best to worst.
        - For the top-ranked prompt, explain why it was selected as the top prompt and what if anything could be improved.
        - For lower-ranked prompts, point out the good things about their prompts but also what the flaws were.
        - For joke or troll prompts, rank them last and explain clearly why they were ranked last.

        Return a single, valid JSON object with a key "rankings". The value should be an array of objects, ordered from best prompt to worst. Each object must contain the player's "id", "name", and a short "reason" (1-2 sentences) embodying your personality.

        Example JSON output format:
        { "rankings": [ { "id": "some_id_1", "name": "Alice", "reason": "Finally! A prompt with some substance. It's almost like you've done this before. Well done." }, { "id": "some_id_2", "name": "Bob", "reason": "Did you even read the problem? This is so vague, I'd expect the AI to return a recipe for banana bread." } ] }
    `;

    try {
        const result = await model.generateContent(metaPrompt);
        const text = result.response.text();
        const parsedResponse = JSON.parse(text);
        if (parsedResponse.rankings && Array.isArray(parsedResponse.rankings)) {
            console.log("Successfully received and parsed structured ranking.");
            return parsedResponse.rankings;
        } else { throw new Error("Invalid JSON structure received from API."); }
    } catch (error) {
        console.error("Error in getGeminiRanking:", error);
        console.log("Falling back to random ranking.");
        const shuffled = playerPrompts.sort(() => Math.random() - 0.5);
        return shuffled.map(p => ({ ...p, reason: "Judge Lexi's processor overheated from reading so many bad prompts. Ranks were assigned by a random number generator while she gets a new fan." }));
    }
}

async function getGeminiSolution(winningPrompt, problem) {
    console.log("Calling Gemini API for the solution...");
    const metaPrompt = `
        You are a senior software engineering AI assistant. Your task is to provide a high-quality, expert-level solution to the following problem, based *only* on the user's provided prompt. Format your answer clearly using markdown.

        ---
        **THE ORIGINAL PROBLEM:**
        ${problem}
        ---
        **THE WINNING PROMPT:**
        ${winningPrompt}
        ---

        Now, generate the solution based on the winning prompt.
    `;
    try {
        const result = await solutionModel.generateContent(metaPrompt);
        return result.response.text();
    } catch (error) {
        console.error("Error in getGeminiSolution:", error);
        return `The AI tried to generate a solution for the prompt "${winningPrompt}" but encountered an error. It might have been too powerful!`;
    }
}

// --- Socket.IO Connection Handling ---
io.on('connection', (socket) => {
    console.log(`New client connected: ${socket.id}`);

    socket.on('createGame', () => {
        if (gameState.gameMasterSocketId) {
            socket.emit('errorMsg', 'A game is already in progress.');
            return;
        }
        console.log(`Game Master has connected: ${socket.id}`);
        gameState.gameMasterSocketId = socket.id;
        socket.emit('gameCreated', 'You are the Game Master. Waiting for players...');
    });

    socket.on('joinGame', (playerName) => {
        if (gameState.gameStarted) {
             socket.emit('errorMsg', 'Sorry, the game has already started.');
             return;
        }
        console.log(`Player '${playerName}' with ID ${socket.id} is joining.`);
        const playerId = crypto.randomUUID();
        gameState.players[playerId] = { id: playerId, name: playerName, score: 0, socketId: socket.id, isActive: true };
        socketIdToPlayerIdMap[socket.id] = playerId;

        socket.emit('joinSuccess', { message: `Welcome, ${playerName}!`, playerId: playerId });
        io.emit('updatePlayerList', Object.values(gameState.players));
    });

    socket.on('rejoinGame', (playerId) => {
        const player = gameState.players[playerId];
        if (player) {
            console.log(`Player '${player.name}' with ID ${playerId} is rejoining.`);
            player.isActive = true;
            player.socketId = socket.id;
            socketIdToPlayerIdMap[socket.id] = playerId;
            
            io.emit('updatePlayerList', Object.values(gameState.players));

            // Sync the rejoining player's client with the current game state
            switch (gameState.phase) {
                case 'LOBBY':
                    socket.emit('joinSuccess', { message: `Welcome back, ${player.name}!`, playerId: player.id });
                    break;
                case 'INSTRUCTIONS':
                    socket.emit('showInstructions');
                    break;
                case 'PROMPTING':
                    const currentProblem = gameLevels[gameState.currentLevel - 1];
                    socket.emit('levelStart', currentProblem);
                    if (gameState.prompts[playerId]) {
                        socket.emit('promptAccepted');
                    }
                    break;
                case 'RESULTS':
                    if(gameState.lastRoundResults) {
                        socket.emit('showRoundResults', { roundResults: gameState.lastRoundResults });
                    } else { // Fallback if no results are available
                         socket.emit('joinSuccess', { message: `Welcome back, ${player.name}!`, playerId: player.id });
                    }
                    break;
                case 'LEADERBOARD':
                    const overallLeaderboard = Object.values(gameState.players).sort((a, b) => b.score - a.score);
                    socket.emit('showLeaderboard', { overallLeaderboard, currentLevel: gameState.currentLevel, totalLevels: gameLevels.length });
                    break;
                case 'GAMEOVER':
                     const finalLeaderboard = Object.values(gameState.players).sort((a, b) => b.score - a.score);
                     io.emit('gameOver', { finalLeaderboard });
                    break;
            }
        } else {
            socket.emit('rejoinError', 'Could not find that game session. Please join as a new player.');
        }
    });
    
    socket.on('startGame', () => {
        if (socket.id !== gameState.gameMasterSocketId) return;
        
        console.log('Game Master is starting the game. Showing instructions.');
        gameState.gameStarted = true;
        gameState.phase = 'INSTRUCTIONS';
        io.emit('showInstructions');
    });

    socket.on('startFirstRound', () => {
        if (socket.id !== gameState.gameMasterSocketId) return;
        
        console.log('Starting first round...');
        gameState.currentLevel = 1;
        gameState.prompts = {}; 
        gameState.phase = 'PROMPTING';

        const currentProblem = gameLevels[gameState.currentLevel - 1];
        io.emit('levelStart', currentProblem);
        io.to(gameState.gameMasterSocketId).emit('updateSubmissionStatus', {
            players: Object.values(gameState.players),
            prompts: gameState.prompts
        });
    });

    socket.on('submitPrompt', (prompt) => {
        const playerId = socketIdToPlayerIdMap[socket.id];
        if (playerId && gameState.players[playerId] && !gameState.prompts[playerId]) {
            console.log(`Received prompt from ${gameState.players[playerId].name}: "${prompt}"`);
            gameState.prompts[playerId] = prompt;
            socket.emit('promptAccepted');
            io.to(gameState.gameMasterSocketId).emit('updateSubmissionStatus', {
                players: Object.values(gameState.players),
                prompts: gameState.prompts
            });
            
            const activePlayers = Object.values(gameState.players).filter(p => p.isActive);
            if (Object.keys(gameState.prompts).length >= activePlayers.length) {
                io.to(gameState.gameMasterSocketId).emit('allPromptsReceived');
            }
        }
    });
    
    socket.on('closeSubmissions', async () => {
        if (socket.id !== gameState.gameMasterSocketId) return;
        console.log("Submissions closed. Evaluating...");
        gameState.phase = 'RESULTS';

        const promptsToRank = Object.entries(gameState.prompts).map(([playerId, promptText]) => ({
            id: playerId, name: gameState.players[playerId].name, prompt: promptText
        }));

        if (promptsToRank.length === 0) {
            console.log("No prompts submitted. Waiting.");
            return;
        };
        
        const problemForRound = gameLevels[gameState.currentLevel - 1].problem;
        const rankedPlayersWithReasons = await getGeminiRanking(promptsToRank, problemForRound);
        
        if (!rankedPlayersWithReasons || rankedPlayersWithReasons.length === 0) {
             console.error("Ranking failed to return valid data.");
             return;
        }

        const winnerId = rankedPlayersWithReasons[0].id;
        const winningPrompt = gameState.prompts[winnerId];
        const aiSolution = winningPrompt ? await getGeminiSolution(winningPrompt, problemForRound) : "No winning prompt was found to generate a solution.";
        
        const activePlayersCount = Object.values(gameState.players).filter(p => p.isActive).length;
        const roundScores = [];

        rankedPlayersWithReasons.forEach((player, index) => {
            const rank = index + 1;
            const points = Math.max(0, activePlayersCount - (rank - 1));
            if (gameState.players[player.id]) { 
                gameState.players[player.id].score += points; 
            }
            roundScores.push({ name: player.name, rank: rank, points: points, prompt: gameState.prompts[player.id] || "Prompt not found.", reason: player.reason });
        });

        const roundResults = {
            problem: problemForRound,
            winnerName: rankedPlayersWithReasons[0].name,
            aiSolution: aiSolution,
            rankings: roundScores
        };
        gameState.lastRoundResults = roundResults;
        io.emit('showRoundResults', { roundResults });
    });
    
    socket.on('showLeaderboard', () => {
        if (socket.id !== gameState.gameMasterSocketId) return;
        console.log("GM requested leaderboard. Broadcasting to all players.");
        gameState.phase = 'LEADERBOARD';
        const overallLeaderboard = Object.values(gameState.players).sort((a, b) => b.score - a.score);
        io.emit('showLeaderboard', { 
            overallLeaderboard,
            currentLevel: gameState.currentLevel,
            totalLevels: gameLevels.length 
        });
    });

    socket.on('nextLevel', () => {
        if (socket.id !== gameState.gameMasterSocketId) return;
        if (gameState.currentLevel >= gameLevels.length) {
            const finalLeaderboard = Object.values(gameState.players).sort((a, b) => b.score - a.score);
            io.emit('gameOver', { finalLeaderboard });
            return;
        }
        gameState.currentLevel++;
        console.log(`Starting next level: ${gameState.currentLevel}`);
        gameState.prompts = {};
        gameState.phase = 'PROMPTING';
        gameState.lastRoundResults = null;
        const currentProblem = gameLevels[gameState.currentLevel - 1];
        io.emit('levelStart', currentProblem);
        io.to(gameState.gameMasterSocketId).emit('updateSubmissionStatus', {
            players: Object.values(gameState.players),
            prompts: gameState.prompts
        });
    });

    socket.on('showFinalResults', () => {
        if (socket.id !== gameState.gameMasterSocketId) return;
        console.log('Game is over. Showing final results.');
        gameState.phase = 'GAMEOVER';
        const finalLeaderboard = Object.values(gameState.players).sort((a, b) => b.score - a.score);
        io.emit('gameOver', { finalLeaderboard });
    });

    socket.on('disconnect', () => {
        console.log(`Client disconnected: ${socket.id}`);
        const playerId = socketIdToPlayerIdMap[socket.id];

        if (socket.id === gameState.gameMasterSocketId) {
            console.log('Game Master disconnected. Resetting game.');
            gameState = { players: {}, gameMasterSocketId: null, gameStarted: false, currentLevel: 0, prompts: {}, phase: 'LOBBY', lastRoundResults: null };
            socketIdToPlayerIdMap = {};
            io.emit('gameReset', 'The Game Master has disconnected. The game has been reset.');
        } else if (playerId && gameState.players[playerId]) {
            const player = gameState.players[playerId];
            console.log(`Player ${player.name} disconnected.`);
            player.isActive = false;
            delete socketIdToPlayerIdMap[socket.id];
            io.emit('updatePlayerList', Object.values(gameState.players));
            io.to(gameState.gameMasterSocketId).emit('updateSubmissionStatus', {
                players: Object.values(gameState.players),
                prompts: gameState.prompts
            });
        }
    });
});

server.listen(PORT, () => { console.log(`Server listening on port ${PORT}`); });