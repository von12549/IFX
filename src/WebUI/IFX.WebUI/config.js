// API Configuration
const CONFIG = {
    // Base URL of the Auth API
    API_BASE_URL: 'http://localhost:5010',

    // OAuth endpoints
    ENDPOINTS: {
        AUTHORIZE: '/api/v1/auth/oauth/authorize',
        CALLBACK: '/api/v1/auth/oauth/callback',
        USERINFO: '/api/v1/auth/oauth/userinfo',
        LOGOUT: '/api/v1/auth/oauth/logout'
    },

    // Storage keys
    STORAGE_KEYS: {
        ACCESS_TOKEN: 'auth_access_token',
        ID_TOKEN: 'auth_id_token',
        REFRESH_TOKEN: 'auth_refresh_token',
        EXPIRES_AT: 'auth_expires_at',
        STATE: 'auth_state'
    }
};
