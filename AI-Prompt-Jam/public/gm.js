const socket = io();

// --- Screen Management ---
const screens = document.querySelectorAll('.screen');
function showScreen(screenId) {
    screens.forEach(screen => {
        screen.style.display = screen.id === screenId ? 'flex' : 'none';
    });
}

// --- Get DOM Elements ---
const gmStatus = document.getElementById('gm-status');
const playerList = document.getElementById('player-list');
const levelPackSelect = document.getElementById('level-pack-select');
const startGameButton = document.getElementById('start-game-button');
const startFirstRoundButton = document.getElementById('start-first-round-button');
const levelNumber = document.getElementById('level-number');
const problemText = document.getElementById('problem-text');
const submissionList = document.getElementById('submission-list');
const closeSubmissionsButton = document.getElementById('close-submissions-button');
const resultsProblemText = document.getElementById('results-problem-text');
const winnerName = document.getElementById('winner-name');
const aiSolution = document.getElementById('ai-solution');
const roundRankings = document.getElementById('round-rankings');
const overallLeaderboard = document.getElementById('overall-leaderboard');
const nextLevelButton = document.getElementById('next-level-button');
const finalResultsButton = document.getElementById('final-results-button');
const gameOverScreen = document.getElementById('game-over-screen');
const winnerPodium = document.getElementById('winner-podium');
const showLeaderboardButton = document.getElementById('show-leaderboard-button');

// --- On connect, declare this client as the Game Master ---
socket.on('connect', () => { socket.emit('createGame'); });

// --- Event Listeners ---
startGameButton.addEventListener('click', () => {
    const selectedPack = levelPackSelect.value;
    if (selectedPack) {
        socket.emit('startGame', { levelPackName: selectedPack });
    }
});
startFirstRoundButton.addEventListener('click', () => { socket.emit('startFirstRound'); });
closeSubmissionsButton.addEventListener('click', () => {
    if (confirm('Are you sure you want to close submissions and evaluate the prompts?')) {
        socket.emit('closeSubmissions');
        closeSubmissionsButton.disabled = true;
    }
});
showLeaderboardButton.addEventListener('click', () => { socket.emit('showLeaderboard'); });
nextLevelButton.addEventListener('click', () => { socket.emit('nextLevel'); });
finalResultsButton.addEventListener('click', () => { socket.emit('showFinalResults'); });

// --- Socket Event Handlers ---
socket.on('gameCreated', (message) => { gmStatus.textContent = message; });

socket.on('levelPacksAvailable', (packNames) => {
    levelPackSelect.innerHTML = ''; // Clear loading message
    packNames.forEach(name => {
        const option = document.createElement('option');
        option.value = name;
        option.textContent = name;
        levelPackSelect.appendChild(option);
    });
    levelPackSelect.disabled = false;
    startGameButton.disabled = false;
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
    showScreen('gm-instructions-wait-screen');
});

socket.on('levelStart', (levelData) => {
    showScreen('gm-game-view');
    closeSubmissionsButton.disabled = false;
    levelNumber.textContent = levelData.level;
    problemText.textContent = levelData.problem;
});

socket.on('updateSubmissionStatus', ({ players, prompts }) => {
    submissionList.innerHTML = '';
    const activePlayerIds = new Set(players.filter(p => p.isActive).map(p => p.id));
    
    players.forEach(player => {
        const li = document.createElement('li');
        const hasSubmitted = prompts[player.id];
        let statusIcon = '⏳'; // Waiting

        if (hasSubmitted) {
            statusIcon = '✅'; // Submitted
        } else if (!player.isActive) {
            statusIcon = '❌'; // Disconnected
        }
        
        li.textContent = `${statusIcon} ${player.name}`;

        if (hasSubmitted) li.classList.add('submitted');
        if (!player.isActive) li.classList.add('disconnected');

        submissionList.appendChild(li);
    });
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

socket.on('showLeaderboard', ({ overallLeaderboard: leaderboardData, currentLevel, totalLevels }) => {
    showScreen('leaderboard-screen');
    overallLeaderboard.innerHTML = '';
    leaderboardData.forEach((player, index) => {
        const li = document.createElement('li');
        li.textContent = `#${index + 1}: ${player.name} - Total Score: ${player.score}`;
        overallLeaderboard.appendChild(li);
    });

    if (currentLevel >= totalLevels) {
        finalResultsButton.style.display = 'block';
        nextLevelButton.style.display = 'none';
    } else {
        finalResultsButton.style.display = 'none';
        nextLevelButton.style.display = 'block';
    }
});

socket.on('gameOver', ({ finalLeaderboard }) => {
    showScreen('game-over-screen');
    winnerPodium.innerHTML = '';
    const places = ['🥇 1st Place', '🥈 2nd Place', '🥉 3rd Place'];
    for (let i = 0; i < Math.min(finalLeaderboard.length, 3); i++) {
        const player = finalLeaderboard[i];
        const podiumElement = document.createElement('h3');
        podiumElement.innerHTML = `${places[i]}: ${player.name} <br> <small>(${player.score} points)</small>`;
        winnerPodium.appendChild(podiumElement);
    }
});

socket.on('errorMsg', (message) => { alert(message); });
socket.on('gameReset', (message) => { alert(message); window.location.reload(); });