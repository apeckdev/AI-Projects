// Import necessary libraries
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const crypto = require('crypto');
const fs = require('fs');
require('dotenv').config();
const { GoogleGenerativeAI, HarmCategory, HarmBlockThreshold } = require('@google/generative-ai');

// --- Server Setup ---
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: { origin: "*", methods: ["GET", "POST"] }
});
const PORT = process.env.PORT || 3000;
app.use(express.static('public'));

// --- Load Game Content ---
let levelPacks = {};
try {
    const levelData = fs.readFileSync('levels.json', 'utf8');
    levelPacks = JSON.parse(levelData);
} catch (err) {
    console.error("Error reading or parsing levels.json:", err);
    process.exit(1);
}

// --- Gemini API Setup ---
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({
    model: "gemini-2.5-pro",
    safetySettings: [
        { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
        { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
    ],
    generationConfig: { responseMimeType: "application/json" }
});
const solutionModel = genAI.getGenerativeModel({ model: "gemini-2.5-pro" });


// --- Game State Management (Multi-Room) ---
let games = new Map(); // Use a Map to store all active game rooms by ID.

// --- Helper Functions ---
function getGameLists() {
    const joinableGames = [];
    const activeGames = [];
    for (const [roomId, game] of games.entries()) {
        const gameInfo = {
            roomId: roomId,
            roomName: game.roomName,
            levelPackName: game.levelPackName,
            playerCount: Object.values(game.players).filter(p => p.isActive).length,
        };
        if (game.gameStarted) {
            activeGames.push(gameInfo);
        } else {
            joinableGames.push(gameInfo);
        }
    }
    return { joinableGames, activeGames };
}

function broadcastGameLists() {
    io.to('main-lobby').emit('updateGameList', getGameLists());
}

async function getGeminiRanking(playerPrompts, problem) { /* ... (no changes) ... */ }
async function getGeminiSolution(winningPrompt, problem) { /* ... (no changes) ... */ }


// --- Socket.IO Connection Handling ---
io.on('connection', (socket) => {
    console.log(`New client connected: ${socket.id}`);
    socket.join('main-lobby');
    socket.emit('levelPacksAvailable', Object.keys(levelPacks));
    socket.emit('updateGameList', getGameLists());

    socket.on('createGame', (payload) => {
        if (!payload || !payload.roomName || !payload.levelPackName) {
            console.error(`Malformed 'createGame' event received from socket ${socket.id}. Payload:`, payload);
            return; 
        }
        const { roomName, levelPackName } = payload;

        const roomId = crypto.randomUUID();
        const selectedLevels = levelPacks[levelPackName];
        if (!selectedLevels) {
            socket.emit('errorMsg', 'Invalid level pack selected.');
            return;
        }

        const newGame = {
            roomName,
            levelPackName,
            players: {},
            gameMasterSocketId: socket.id,
            currentLevel: 0,
            gameStarted: false,
            prompts: {},
            phase: 'LOBBY',
            lastRoundResults: null,
            levels: selectedLevels,
            socketIdToPlayerIdMap: {},
            deletionTimer: null, // Add a property to hold the deletion timer
        };
        games.set(roomId, newGame);

        socket.leave('main-lobby');
        socket.join(roomId);
        socket.data.roomId = roomId;

        console.log(`Game created by ${socket.id}: Room '${roomName}' (ID: ${roomId})`);
        socket.emit('gameCreated', { roomId });
        broadcastGameLists();
    });

    socket.on('gmConnect', ({ roomId }) => {
        const game = games.get(roomId);
        if (game) {
            // --- FIX: When the GM connects, cancel any pending deletion timer ---
            if (game.deletionTimer) {
                clearTimeout(game.deletionTimer);
                game.deletionTimer = null;
                console.log(`Deletion timer for room ${roomId} cancelled.`);
            }
            // --- END FIX ---

            socket.leave('main-lobby');
            socket.join(roomId);
            socket.data.roomId = roomId;
            game.gameMasterSocketId = socket.id; // CRITICAL: Update to the new socket ID
            console.log(`Game Master ${socket.id} connected to room ${roomId}`);
            socket.emit('gameCreated', { roomId }); // Re-confirm to GM
            io.to(roomId).emit('updatePlayerList', Object.values(game.players));
        } else {
            socket.emit('errorMsg', 'The game you were hosting could not be found.');
        }
    });

    socket.on('joinGame', ({ playerName, roomId }) => {
        const game = games.get(roomId);
        if (!game) {
            socket.emit('errorMsg', 'Game not found.');
            return;
        }
        if (game.gameStarted) {
             socket.emit('errorMsg', 'Sorry, the game has already started.');
             return;
        }

        socket.leave('main-lobby');
        socket.join(roomId);
        socket.data.roomId = roomId;

        const playerId = crypto.randomUUID();
        game.players[playerId] = { id: playerId, name: playerName, score: 0, socketId: socket.id, isActive: true };
        game.socketIdToPlayerIdMap[socket.id] = playerId;

        socket.emit('joinSuccess', { message: `Welcome, ${playerName}!`, playerId: playerId });
        io.to(roomId).emit('updatePlayerList', Object.values(game.players));
        broadcastGameLists();
    });

    const getSocketGameInfo = () => {
        const roomId = socket.data.roomId;
        if (!roomId) return { game: null, player: null, playerId: null, roomId: null };
        const game = games.get(roomId);
        if (!game) return { game: null, player: null, playerId: null, roomId };
        const playerId = game.socketIdToPlayerIdMap[socket.id];
        const player = playerId ? game.players[playerId] : null;
        return { game, player, playerId, roomId };
    };

    socket.on('disconnect', () => {
        console.log(`Client disconnected: ${socket.id}`);
        const { game, playerId, roomId } = getSocketGameInfo();

        if (!game) return;

        if (socket.id === game.gameMasterSocketId) {
            console.log(`Game Master disconnected from room ${roomId}. Starting 5-second deletion timer.`);
            game.deletionTimer = setTimeout(() => {
                const gameStillExists = games.get(roomId);
                if (gameStillExists) { // Check if game wasn't deleted for other reasons
                    console.log(`Timer expired for room ${roomId}. Deleting game.`);
                    io.to(roomId).emit('gameReset', 'The Game Master has disconnected. The game has ended.');
                    games.delete(roomId);
                    broadcastGameLists();
                }
            }, 5000); // 5-second grace period for the GM to reconnect
        } 
        else if (playerId && game.players[playerId]) {
            console.log(`Player ${game.players[playerId].name} disconnected from room ${roomId}.`);
            game.players[playerId].isActive = false;
            delete game.socketIdToPlayerIdMap[socket.id];
            io.to(roomId).emit('updatePlayerList', Object.values(game.players));
            io.to(game.gameMasterSocketId).emit('updateSubmissionStatus', {
                players: Object.values(game.players), prompts: game.prompts
            });
            broadcastGameLists();
        }
    });
    
    socket.on('closeSubmissions', async () => {
        const { game, roomId } = getSocketGameInfo();
        if (!game || socket.id !== game.gameMasterSocketId) return;

        console.log(`Submissions closed in room ${roomId}.`);
        game.phase = 'RESULTS';
        const promptsToRank = Object.entries(game.prompts).map(([pId, promptText]) => ({
            id: pId, name: game.players[pId].name, prompt: promptText
        }));

        if (promptsToRank.length === 0) return;
        
        const problemForRound = game.levels[game.currentLevel - 1].problem;
        const rankedPlayersWithReasons = await getGeminiRanking(promptsToRank, problemForRound);
        
        if (!rankedPlayersWithReasons || rankedPlayersWithReasons.length === 0) return;

        const winnerId = rankedPlayersWithReasons[0].id;
        const winningPrompt = game.prompts[winnerId];
        const aiSolution = winningPrompt ? await getGeminiSolution(winningPrompt, problemForRound) : "No winner.";
        
        const activePlayersCount = Object.values(game.players).filter(p => p.isActive).length;
        const roundScores = [];

        rankedPlayersWithReasons.forEach((player, index) => {
            const rank = index + 1;
            const points = Math.max(0, activePlayersCount - (rank - 1));
            if (game.players[player.id]) { game.players[player.id].score += points; }
            roundScores.push({ name: player.name, rank: rank, points: points, prompt: game.prompts[player.id] || "N/A", reason: player.reason });
        });

        const roundResults = { problem: problemForRound, winnerName: rankedPlayersWithReasons[0].name, aiSolution, rankings: roundScores };
        game.lastRoundResults = roundResults;
        io.to(roomId).emit('showRoundResults', { roundResults });
    });

    socket.on('showLeaderboard', () => {
        const { game, roomId } = getSocketGameInfo();
        if (!game || socket.id !== game.gameMasterSocketId) return;
        game.phase = 'LEADERBOARD';
        const overallLeaderboard = Object.values(game.players).sort((a, b) => b.score - a.score);
        io.to(roomId).emit('showLeaderboard', { 
            overallLeaderboard,
            currentLevel: game.currentLevel,
            totalLevels: game.levels.length 
        });
    });

    socket.on('nextLevel', () => {
        const { game, roomId } = getSocketGameInfo();
        if (!game || socket.id !== game.gameMasterSocketId) return;

        if (game.currentLevel >= game.levels.length) {
            const finalLeaderboard = Object.values(game.players).sort((a, b) => b.score - a.score);
            io.to(roomId).emit('gameOver', { finalLeaderboard });
            return;
        }

        game.currentLevel++;
        game.prompts = {};
        game.phase = 'PROMPTING';
        game.lastRoundResults = null;
        const currentProblem = game.levels[game.currentLevel - 1];
        io.to(roomId).emit('levelStart', currentProblem);
        io.to(game.gameMasterSocketId).emit('updateSubmissionStatus', {
            players: Object.values(game.players),
            prompts: game.prompts
        });
    });

     socket.on('showFinalResults', () => {
        const { game, roomId } = getSocketGameInfo();
        if (!game || socket.id !== game.gameMasterSocketId) return;
        game.phase = 'GAMEOVER';
        const finalLeaderboard = Object.values(game.players).sort((a, b) => b.score - a.score);
        io.to(roomId).emit('gameOver', { finalLeaderboard });
    });
});


server.listen(PORT, () => { console.log(`Server listening on port ${PORT}`); });