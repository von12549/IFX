# AWS Cognito Setup Guide

This guide will walk you through setting up AWS Cognito for use with the AuthSamples application.

## Prerequisites

- An AWS account
- AWS CLI configured (optional but recommended)
- Access to AWS Console

## Step-by-Step Setup

### 1. Create a User Pool

1. Navigate to the [AWS Cognito Console](https://console.aws.amazon.com/cognito)
2. Click "Create user pool"
3. Configure sign-in experience:
   - **Authentication providers**: Select "Email" and "Username"
   - **User name requirements**: Allow users to sign in with email and preferred username
   - Click "Next"

### 2. Configure Security Requirements

1. **Password policy**:
   - Minimum length: 8 characters
   - Require uppercase letters
   - Require lowercase letters
   - Require numbers
   - Require special characters
2. **Multi-factor authentication (MFA)**: Optional (recommended for production)
3. **User account recovery**: Email only (for development)
4. Click "Next"

### 3. Configure Sign-up Experience

1. **Self-service sign-up**: Enable
2. **Attribute verification and user account confirmation**:
   - Allow Cognito to automatically send messages to verify and confirm
   - Select "Send email message, verify email address"
3. **Required attributes**:
   - email (required)
   - given_name (required)
   - family_name (required)
4. **Custom attributes**: None required for basic setup
5. Click "Next"

### 4. Configure Message Delivery

1. **Email provider**: Choose "Send email with Cognito" for development
   - For production, configure SES (Simple Email Service)
2. **FROM email address**: Use default or configure custom domain
3. Click "Next"

### 5. Integrate Your App

1. **User pool name**: Enter a descriptive name (e.g., "authsamples-user-pool")
2. **Hosted authentication pages**: Not required for this setup
3. **Initial app client**:
   - **App client name**: "authsamples-api-client"
   - **Client secret**: Generate a client secret (REQUIRED)
   - **Authentication flows**: Enable the following:
     - ALLOW_USER_PASSWORD_AUTH
     - ALLOW_ADMIN_USER_PASSWORD_AUTH
     - ALLOW_REFRESH_TOKEN_AUTH
4. Click "Next"

### 6. Review and Create

1. Review all settings
2. Click "Create user pool"

## Extract Configuration Values

After creating the user pool, you need to extract the following values:

### 1. User Pool ID

- Location: User pool overview page
- Format: `us-east-1_XXXXXXXXX`
- Example: `us-east-1_AbCdEfGhI`

### 2. App Client ID

1. Navigate to your user pool
2. Click "App integration" tab
3. Scroll down to "App clients and analytics"
4. Click on your app client name
5. Copy the "Client ID"
- Format: 26-character alphanumeric string
- Example: `1a2b3c4d5e6f7g8h9i0j1k2l3m`

### 3. App Client Secret

1. In the same app client details page
2. Click "Show client secret"
3. Copy the secret
- Format: Long alphanumeric string
- Example: `abc123def456ghi789jkl012mno345pqr678stu901vwx234yz`

### 4. Region

- The AWS region where you created the user pool
- Example: `us-east-1`, `us-west-2`, `eu-west-1`

## Update Application Configuration

### Option 1: Using appsettings.json (Development)

Update `src/Modules/Cognito/AuthSamples.Modules.Cognito.API/appsettings.json`:

```json
{
  "CognitoSettings": {
    "UserPoolId": "us-east-1_XXXXXXXXX",
    "ClientId": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
    "ClientSecret": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    "Region": "us-east-1"
  }
}
```

### Option 2: Using Environment Variables (Docker)

Create a `.env` file in the project root (copy from `.env.example`):

```env
COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
COGNITO_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXX
COGNITO_CLIENT_SECRET=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
COGNITO_REGION=us-east-1
```

**Important**: Never commit the `.env` file to version control!

## Verify Setup

### 1. Test User Registration

```bash
curl -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test@12345",
    "username": "testuser",
    "firstName": "Test",
    "lastName": "User"
  }'
```

### 2. Check Cognito Console

1. Navigate to your user pool
2. Click "Users" tab
3. Verify the new user appears (status: UNCONFIRMED)

### 3. Get Confirmation Code

For development/testing:
1. Check the email address used during registration
2. Copy the 6-digit confirmation code

For production, users receive this via email automatically.

### 4. Confirm Registration

```bash
curl -X POST http://localhost:5000/api/v1/auth/confirm \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "confirmationCode": "123456"
  }'
```

### 5. Test Login

```bash
curl -X POST http://localhost:5000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test@12345"
  }'
```

Expected response:
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJraWQiOiI...",
    "idToken": "eyJraWQiOiJ...",
    "refreshToken": "eyJjdHkiOi...",
    "expiresIn": 3600,
    "user": {
      "id": "...",
      "email": "test@example.com",
      "username": "testuser",
      "firstName": "Test",
      "lastName": "User"
    }
  }
}
```

## Troubleshooting

### Error: "User pool client <client-id> does not have SECRET configured"

**Solution**: Recreate the app client with "Generate client secret" enabled.

### Error: "Unable to verify secret hash for client <client-id>"

**Solution**: Ensure you're NOT sending secret hash in the request. The API handles this internally.

### Error: "NotAuthorizedException: Incorrect username or password"

**Possible causes**:
1. User hasn't confirmed their email
2. Wrong password
3. User doesn't exist

### Error: "InvalidParameterException: Cannot reset password for the user as there is no registered/verified email"

**Solution**: Verify the user's email first through the confirmation flow.

## Advanced Configuration

### Enable MFA (Multi-Factor Authentication)

1. Navigate to your user pool
2. Go to "Sign-in experience" tab
3. Click "Edit" under "Multi-factor authentication"
4. Select "Optional MFA" or "Required MFA"
5. Choose SMS, TOTP, or both

### Custom Email Templates

1. Navigate to "Messaging" tab
2. Click "Edit" under "Email message customization"
3. Customize verification and invitation templates

### Advanced Security Features

1. Navigate to "App integration" tab
2. Configure:
   - Advanced security (risk-based adaptive authentication)
   - Device tracking
   - Token revocation

## Production Considerations

1. **Use SES for email**: Configure Amazon SES for production email delivery
2. **Enable MFA**: Require multi-factor authentication for sensitive operations
3. **Configure custom domain**: Use your own domain for email sender
4. **Set up CloudWatch**: Monitor authentication events and failures
5. **Enable advanced security**: Use risk-based adaptive authentication
6. **Backup user pool**: Regularly export user data
7. **Review token expiration**: Set appropriate token lifetimes

## Resources

- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [User Pool Best Practices](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-settings.html)
- [Security Best Practices](https://docs.aws.amazon.com/cognito/latest/developerguide/managing-security.html)
