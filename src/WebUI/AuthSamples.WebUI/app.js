// DOM Elements
const loginSection = document.getElementById('login-section');
const loadingSection = document.getElementById('loading-section');
const userSection = document.getElementById('user-section');
const userinfoSection = document.getElementById('userinfo-section');
const loginBtn = document.getElementById('login-btn');
const logoutBtn = document.getElementById('logout-btn');
const userinfoBtn = document.getElementById('userinfo-btn');
const loginError = document.getElementById('login-error');
const debugLog = document.getElementById('debug-log');

// Token storage
let tokens = {
    accessToken: null,
    idToken: null,
    refreshToken: null,
    expiresAt: null
};

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    log('info', 'App initialized');

    // Check for tokens in URL fragment (from backend redirect)
    const fragment = window.location.hash.substring(1);
    if (fragment) {
        const fragmentParams = new URLSearchParams(fragment);
        const accessToken = fragmentParams.get('access_token');
        const error = fragmentParams.get('error');
        const errorDescription = fragmentParams.get('error_description');

        if (error) {
            // Handle OAuth error from fragment
            log('error', `OAuth error: ${error} - ${errorDescription}`);
            showError(errorDescription || error);
            showLoginSection();
            // Clean URL
            window.history.replaceState({}, document.title, window.location.pathname);
        } else if (accessToken) {
            // Handle tokens from fragment
            log('info', 'Tokens received from callback redirect');
            handleFragmentTokens(fragmentParams);
        }
    } else {
        // Check for existing session
        loadTokensFromStorage();
        if (tokens.accessToken && !isTokenExpired()) {
            log('success', 'Existing session found');
            showUserSection();
        } else {
            log('info', 'No active session');
            clearTokens();
            showLoginSection();
        }
    }

    // Event listeners
    loginBtn.addEventListener('click', initiateLogin);
    logoutBtn.addEventListener('click', logout);
    userinfoBtn.addEventListener('click', fetchUserInfo);
});

// Initiate OAuth login flow
async function initiateLogin() {
    log('info', 'Initiating OAuth login...');
    loginBtn.disabled = true;
    hideError();

    try {
        const url = `${CONFIG.API_BASE_URL}${CONFIG.ENDPOINTS.AUTHORIZE}?response_mode=json`;
        log('info', `Fetching: ${url}`);

        const response = await fetch(url);
        const data = await response.json();

        if (!response.ok || !data.success) {
            throw new Error(data.message || 'Failed to get authorization URL');
        }

        log('success', `Got authorization URL, state: ${data.data.state}`);

        // Store state for validation
        sessionStorage.setItem(CONFIG.STORAGE_KEYS.STATE, data.data.state);

        // Redirect to Cognito
        log('info', 'Redirecting to Cognito Hosted UI...');
        window.location.href = data.data.authorizationUrl;

    } catch (error) {
        log('error', `Login failed: ${error.message}`);
        showError(error.message);
        loginBtn.disabled = false;
    }
}

// Handle tokens received in URL fragment (from backend redirect)
function handleFragmentTokens(params) {
    showLoadingSection();

    try {
        // Extract tokens from fragment parameters
        tokens.accessToken = params.get('access_token');
        tokens.idToken = params.get('id_token');
        tokens.refreshToken = params.get('refresh_token');
        const expiresIn = parseInt(params.get('expires_in') || '3600');
        tokens.expiresAt = Date.now() + (expiresIn * 1000);

        log('success', 'Tokens extracted from URL fragment');

        saveTokensToStorage();

        // Clean URL (remove fragment) and show user section
        window.history.replaceState({}, document.title, window.location.pathname);
        showUserSection();

    } catch (error) {
        log('error', `Failed to process tokens: ${error.message}`);
        showError(error.message);
        showLoginSection();
        window.history.replaceState({}, document.title, window.location.pathname);
    }
}

// Fetch user info from backend
async function fetchUserInfo() {
    log('info', 'Fetching user info...');
    userinfoBtn.disabled = true;

    try {
        const response = await fetch(`${CONFIG.API_BASE_URL}${CONFIG.ENDPOINTS.USERINFO}`, {
            headers: {
                'Authorization': `Bearer ${tokens.accessToken}`
            }
        });

        const data = await response.json();

        if (!response.ok || !data.success) {
            throw new Error(data.message || 'Failed to fetch user info');
        }

        log('success', 'User info retrieved');

        // Display user info
        document.getElementById('userinfo-json').textContent = JSON.stringify(data.data, null, 2);
        userinfoSection.classList.remove('hidden');

    } catch (error) {
        log('error', `User info failed: ${error.message}`);
        alert(`Failed to get user info: ${error.message}`);
    } finally {
        userinfoBtn.disabled = false;
    }
}

// Logout
function logout() {
    log('info', 'Logging out...');
    clearTokens();

    // Optionally redirect to Cognito logout
    // window.location.href = `${CONFIG.API_BASE_URL}${CONFIG.ENDPOINTS.LOGOUT}`;

    showLoginSection();
    log('success', 'Logged out successfully');
}

// UI helpers
function showLoginSection() {
    loginSection.classList.remove('hidden');
    loadingSection.classList.add('hidden');
    userSection.classList.add('hidden');
    userinfoSection.classList.add('hidden');
    loginBtn.disabled = false;
}

function showLoadingSection() {
    loginSection.classList.add('hidden');
    loadingSection.classList.remove('hidden');
    userSection.classList.add('hidden');
    userinfoSection.classList.add('hidden');
}

function showUserSection() {
    loginSection.classList.add('hidden');
    loadingSection.classList.add('hidden');
    userSection.classList.remove('hidden');
    userinfoSection.classList.add('hidden');
    updateUserDisplay();
}

function hideUserInfo() {
    userinfoSection.classList.add('hidden');
}

function showError(message) {
    loginError.textContent = message;
    loginError.classList.remove('hidden');
}

function hideError() {
    loginError.classList.add('hidden');
}

function updateUserDisplay() {
    // Parse ID token to get user info
    if (tokens.idToken) {
        try {
            const payload = parseJwt(tokens.idToken);
            document.getElementById('user-name').textContent = payload.name || payload.email || 'User';
            document.getElementById('user-email').textContent = payload.email || '';
            document.getElementById('user-avatar').textContent = (payload.name || payload.email || 'U')[0].toUpperCase();
        } catch (e) {
            log('warn', 'Could not parse ID token');
        }
    }

    // Display tokens (truncated)
    document.getElementById('access-token-preview').textContent = truncateToken(tokens.accessToken);
    document.getElementById('id-token-preview').textContent = truncateToken(tokens.idToken);
    document.getElementById('refresh-token-preview').textContent = truncateToken(tokens.refreshToken);

    const expiresIn = tokens.expiresAt ? Math.max(0, Math.floor((tokens.expiresAt - Date.now()) / 1000)) : 0;
    document.getElementById('expires-in').textContent = `${expiresIn} seconds`;
}

// Token helpers
function saveTokensToStorage() {
    localStorage.setItem(CONFIG.STORAGE_KEYS.ACCESS_TOKEN, tokens.accessToken || '');
    localStorage.setItem(CONFIG.STORAGE_KEYS.ID_TOKEN, tokens.idToken || '');
    localStorage.setItem(CONFIG.STORAGE_KEYS.REFRESH_TOKEN, tokens.refreshToken || '');
    localStorage.setItem(CONFIG.STORAGE_KEYS.EXPIRES_AT, tokens.expiresAt?.toString() || '');
}

function loadTokensFromStorage() {
    tokens.accessToken = localStorage.getItem(CONFIG.STORAGE_KEYS.ACCESS_TOKEN) || null;
    tokens.idToken = localStorage.getItem(CONFIG.STORAGE_KEYS.ID_TOKEN) || null;
    tokens.refreshToken = localStorage.getItem(CONFIG.STORAGE_KEYS.REFRESH_TOKEN) || null;
    const expiresAt = localStorage.getItem(CONFIG.STORAGE_KEYS.EXPIRES_AT);
    tokens.expiresAt = expiresAt ? parseInt(expiresAt) : null;
}

function clearTokens() {
    tokens = { accessToken: null, idToken: null, refreshToken: null, expiresAt: null };
    localStorage.removeItem(CONFIG.STORAGE_KEYS.ACCESS_TOKEN);
    localStorage.removeItem(CONFIG.STORAGE_KEYS.ID_TOKEN);
    localStorage.removeItem(CONFIG.STORAGE_KEYS.REFRESH_TOKEN);
    localStorage.removeItem(CONFIG.STORAGE_KEYS.EXPIRES_AT);
}

function isTokenExpired() {
    if (!tokens.expiresAt) return true;
    return Date.now() >= tokens.expiresAt;
}

function parseJwt(token) {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(atob(base64).split('').map(c =>
        '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)
    ).join(''));
    return JSON.parse(jsonPayload);
}

function truncateToken(token) {
    if (!token) return 'N/A';
    if (token.length <= 40) return token;
    return token.substring(0, 20) + '...' + token.substring(token.length - 15);
}

// Copy token to clipboard
function copyToken(type) {
    let token = '';
    switch (type) {
        case 'access': token = tokens.accessToken; break;
        case 'id': token = tokens.idToken; break;
        case 'refresh': token = tokens.refreshToken; break;
    }

    if (token) {
        navigator.clipboard.writeText(token).then(() => {
            log('success', `${type} token copied to clipboard`);
        }).catch(err => {
            log('error', `Failed to copy: ${err.message}`);
        });
    }
}

// Debug logging
function log(level, message) {
    const time = new Date().toLocaleTimeString();
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.innerHTML = `<span class="log-time">${time}</span><span class="log-${level}">[${level.toUpperCase()}]</span> ${message}`;
    debugLog.appendChild(entry);
    debugLog.scrollTop = debugLog.scrollHeight;

    // Also log to console
    console[level === 'success' ? 'log' : level](`[${level.toUpperCase()}] ${message}`);
}

function clearLog() {
    debugLog.innerHTML = '';
    log('info', 'Log cleared');
}
