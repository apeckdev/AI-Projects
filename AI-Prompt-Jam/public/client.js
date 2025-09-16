const socket = io({
    reconnection: true,
    reconnectionAttempts: 5,
    reconnectionDelay: 1000,
});

// --- Screen Management ---
const screens = document.querySelectorAll('.screen');
function showScreen(screenId) {
    screens.forEach(screen => {
        screen.style.display = screen.id === screenId ? 'flex' : 'none';
    });
}

// --- Get DOM Elements ---
const nameInput = document.getElementById('name-input');
const joinButton = document.getElementById('join-button');
const welcomeMessage = document.getElementById('welcome-message');
const playerList = document.getElementById('player-list');
const levelNumber = document.getElementById('level-number');
const problemText = document.getElementById('problem-text');
const promptInput = document.getElementById('prompt-input');
const submitPromptButton = document.getElementById('submit-prompt-button');
const resultsProblemText = document.getElementById('results-problem-text');
const winnerName = document.getElementById('winner-name');
const aiSolution = document.getElementById('ai-solution');
const roundRankings = document.getElementById('round-rankings');
const overallLeaderboard = document.getElementById('overall-leaderboard');
const gameOverScreen = document.getElementById('game-over-screen');
const winnerPodium = document.getElementById('winner-podium');

// --- Rejoin Logic on page load ---
const storedPlayerId = localStorage.getItem('ai_prompt_party_player_id');
if (storedPlayerId) {
    console.log("Found player ID, attempting to rejoin:", storedPlayerId);
    socket.emit('rejoinGame', storedPlayerId);
} else {
    showScreen('join-screen');
}


// --- Event Listeners ---
joinButton.addEventListener('click', () => {
    const playerName = nameInput.value.trim();
    if (playerName) {
        socket.emit('joinGame', playerName);
    }
});

submitPromptButton.addEventListener('click', () => {
    const promptText = promptInput.value.trim();
    if (promptText) {
        socket.emit('submitPrompt', promptText);
        promptInput.disabled = true;
        submitPromptButton.disabled = true;
    }
});

// --- Socket Event Handlers ---
socket.on('joinSuccess', ({ message, playerId }) => {
    localStorage.setItem('ai_prompt_party_player_id', playerId);
    showScreen('lobby-screen');
    welcomeMessage.textContent = message;
});

socket.on('updatePlayerList', (players) => {
    playerList.innerHTML = '';
    players.forEach(player => {
        const li = document.createElement('li');
        li.textContent = `${player.name} - Score: ${player.score}`;
        if (!player.isActive) {
            li.classList.add('disconnected');
        }
        playerList.appendChild(li);
    });
});

socket.on('showInstructions', () => {
    showScreen('instructions-screen');
});

socket.on('levelStart', (levelData) => {
    showScreen('game-screen');
    promptInput.disabled = false;
    submitPromptButton.disabled = false;
    promptInput.value = '';
    levelNumber.textContent = levelData.level;
    problemText.textContent = levelData.problem;
});

socket.on('promptAccepted', () => {
    showScreen('waiting-screen');
});

socket.on('showRoundResults', ({ roundResults }) => {
    showScreen('results-screen');
    resultsProblemText.textContent = roundResults.problem;
    winnerName.textContent = roundResults.winnerName;
    aiSolution.textContent = roundResults.aiSolution;
    roundRankings.innerHTML = '';
    roundResults.rankings.forEach(p => {
        const li = document.createElement('li');
        li.innerHTML = `
            <div class="rank-header">
                <span class="rank-position">#${p.rank}</span>
                <span class="rank-name">${p.name}</span>
                <span class="rank-points">(+${p.points} pts)</span>
            </div>
            <div class="player-prompt"><b>Their Prompt:</b> "${p.prompt}"</div>
            <div class="ai-feedback"><b>AI Feedback:</b> "${p.reason}"</div>
        `;
        roundRankings.appendChild(li);
    });
});

socket.on('showLeaderboard', ({ overallLeaderboard: leaderboardData }) => {
    showScreen('leaderboard-screen');
    overallLeaderboard.innerHTML = '';
    leaderboardData.forEach((player, index) => {
        const li = document.createElement('li');
        li.textContent = `#${index + 1}: ${player.name} - Total Score: ${player.score}`;
        overallLeaderboard.appendChild(li);
    });
});

socket.on('gameOver', ({ finalLeaderboard }) => {
    showScreen('game-over-screen');
    localStorage.removeItem('ai_prompt_party_player_id'); // Game is over, clear the ID
    winnerPodium.innerHTML = '';
    const places = ['🥇 1st Place', '🥈 2nd Place', '🥉 3rd Place'];
    for (let i = 0; i < Math.min(finalLeaderboard.length, 3); i++) {
        const player = finalLeaderboard[i];
        const podiumElement = document.createElement('h3');
        podiumElement.innerHTML = `${places[i]}: ${player.name} <br> <small>(${player.score} points)</small>`;
        winnerPodium.appendChild(podiumElement);
    }
});

socket.on('rejoinError', (message) => {
    alert(message);
    localStorage.removeItem('ai_prompt_party_player_id');
    window.location.reload();
});


socket.on('errorMsg', (message) => { alert(message); });
socket.on('gameReset', (message) => { alert(message); localStorage.removeItem('ai_prompt_party_player_id'); window.location.reload(); });