# Plan.md

This file will explain how we want to build this new solution and what we want to do in the projects.

# Architecture

Modular monolithic & Clean Architecture: The solution will be Modular Monolithic, and each modular will be clean Architecture.

At the very first stage, there will only be one solution named "AuthSamples" and one modular "Cognito" inside

Cognito Modular will be constructed with 4 layers:
1. Domin layer
2. Infrastructer layer
3. Application layer
4. API layer

# Technicals and skills

The solution and project will build with .Net 8 C#
The Cognito related function will use AWSSDK CognitoIdentityProvider 
API document and test will apply Swagger
CQRS: MediatR
SqlServer will be used as the local storage
Docker will be the container

# Functions
The main functions in the Cognito Modular API will include:
User Register,
Register Confirm,
User Login,
User Logout

When user register/login, sync user info with local database