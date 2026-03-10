# IFX Web UI

A simple OAuth 2.0 demo client for testing the Cognito Managed Login flow.

## Prerequisites

1. Backend API running at `http://localhost:5000`
2. Cognito User Pool configured with:
   - Domain set up
   - Callback URL: `http://localhost:5000/api/v1/auth/oauth/callback`

## Running the UI

### Option 1: Using Python (Recommended)

```bash
cd src/WebUI/IFX.WebUI
python -m http.server 3000
```

Then open: http://localhost:3000

### Option 2: Using Node.js

```bash
cd src/WebUI/IFX.WebUI
npx serve -p 3000
```

Then open: http://localhost:3000

### Option 3: Using VS Code Live Server

1. Install "Live Server" extension
2. Right-click `index.html` -> "Open with Live Server"

### Option 4: Open directly in browser

Simply open `index.html` in your browser. Note: Some features may not work due to file:// protocol restrictions.

## Configuration

Edit `config.js` to change the API base URL:

```javascript
const CONFIG = {
    API_BASE_URL: 'http://localhost:5000',
    // ...
};
```

## OAuth Flow

1. Click "Sign in with Cognito"
2. UI fetches authorization URL from `/api/v1/auth/oauth/authorize?response_mode=json`
3. Browser redirects to Cognito Hosted UI
4. User authenticates
5. Cognito redirects back to callback URL with authorization code
6. Backend exchanges code for tokens
7. UI displays tokens and user info

## Features

- OAuth 2.0 Authorization Code flow with PKCE
- Token display and copy functionality
- User info retrieval via `/oauth/userinfo`
- Debug console for troubleshooting
- Session persistence in localStorage
