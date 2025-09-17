const socket = io();

// --- State Management ---
let currentRoomId = null;

// --- Screen & Modal Management ---
const screens = document.querySelectorAll('.screen');
const createGameModal = document.getElementById('create-game-modal');
const enterNameModal = document.getElementById('enter-name-modal');

function showScreen(screenId) {
    screens.forEach(screen => screen.style.display = 'none');
    const screenToShow = document.getElementById(screenId);
    if(screenToShow) screenToShow.style.display = 'flex';
}

// --- Get DOM Elements ---
const showCreateGameModalButton = document.getElementById('show-create-game-modal-button');
const submitCreateGameButton = document.getElementById('submit-create-game-button');
const closeModalButton = document.querySelector('.close-modal');
const roomNameInput = document.getElementById('room-name-input');
const levelPackSelect = document.getElementById('level-pack-select');
const joinableGamesList = document.getElementById('joinable-games-list');
const activeGamesList = document.getElementById('active-games-list');
const nameInput = document.getElementById('name-input');
const joinButton = document.getElementById('join-button');
const joiningRoomName = document.getElementById('joining-room-name');
const playerList = document.getElementById('player-list');
const welcomeMessage = document.getElementById('welcome-message');


// --- Modal Controls ---
showCreateGameModalButton.addEventListener('click', () => createGameModal.style.display = 'flex');
closeModalButton.addEventListener('click', () => createGameModal.style.display = 'none');
window.addEventListener('click', (event) => {
    if (event.target === createGameModal) createGameModal.style.display = 'none';
    if (event.target === enterNameModal) enterNameModal.style.display = 'none';
});

// --- Event Listeners ---
submitCreateGameButton.addEventListener('click', () => {
    const roomName = roomNameInput.value.trim();
    const levelPackName = levelPackSelect.value;
    if (roomName && levelPackName) {
        socket.emit('createGame', { roomName, levelPackName });
    }
});

joinableGamesList.addEventListener('click', (event) => {
    if (event.target.classList.contains('join-room-button')) {
        currentRoomId = event.target.dataset.roomId;
        const roomName = event.target.dataset.roomName;
        joiningRoomName.textContent = roomName;
        enterNameModal.style.display = 'flex';
        nameInput.focus();
    }
});

joinButton.addEventListener('click', () => {
    const playerName = nameInput.value.trim();
    if (playerName && currentRoomId) {
        socket.emit('joinGame', { playerName, roomId: currentRoomId });
        enterNameModal.style.display = 'none';
    }
});

// --- Socket Event Handlers ---
socket.on('levelPacksAvailable', (packNames) => {
    levelPackSelect.innerHTML = '';
    packNames.forEach(name => {
        const option = document.createElement('option');
        option.value = name;
        option.textContent = name;
        levelPackSelect.appendChild(option);
    });
});

socket.on('updateGameList', ({ joinableGames, activeGames }) => {
    joinableGamesList.innerHTML = '';
    if (joinableGames.length === 0) {
        joinableGamesList.innerHTML = '<li>No games available. Create one!</li>';
    } else {
        joinableGames.forEach(game => {
            const li = document.createElement('li');
            li.innerHTML = `
                <div class="game-info">
                    <strong>${game.roomName}</strong>
                    <span>Pack: ${game.levelPackName}</span>
                    <span>Players: ${game.playerCount}</span>
                </div>
                <button class="join-room-button" data-room-id="${game.roomId}" data-room-name="${game.roomName}">Join</button>
            `;
            joinableGamesList.appendChild(li);
        });
    }

    activeGamesList.innerHTML = '';
    if (activeGames.length === 0) {
        activeGamesList.innerHTML = '<li>No games currently running.</li>';
    } else {
        activeGames.forEach(game => {
            const li = document.createElement('li');
            li.innerHTML = `
                <div class="game-info">
                    <strong>${game.roomName}</strong>
                    <span>Pack: ${game.levelPackName}</span>
                    <span>Players: ${game.playerCount}</span>
                </div>
                <span>In Progress</span>`;
            activeGamesList.appendChild(li);
        });
    }
});

socket.on('gameCreated', ({ roomId }) => {
    window.location.href = `/gm.html?roomId=${roomId}`;
});

socket.on('joinSuccess', ({ message, playerId }) => {
    localStorage.setItem(`ai_prompt_party_player_id_${currentRoomId}`, playerId);
    showScreen('player-lobby-screen');
    welcomeMessage.textContent = message;
});

socket.on('updatePlayerList', (players) => {
    if(playerList){
        playerList.innerHTML = '';
        players.forEach(player => {
            const li = document.createElement('li');
            li.textContent = `${player.name} - Score: ${player.score}`;
            if (!player.isActive) li.classList.add('disconnected');
            playerList.appendChild(li);
        });
    }
});

socket.on('gameReset', (message) => { 
    alert(message); 
    window.location.href = '/'; 
});

socket.on('errorMsg', (message) => { alert(message); });