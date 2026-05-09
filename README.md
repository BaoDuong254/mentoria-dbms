# Mentoria - DBMS

A comprehensive mentorship platform connecting mentors and mentees through scheduled meetings, integrated payments, and real-time communication. Built as a full-stack monorepo application with modern technologies.

## ✨ Features

- 🔐 **Authentication & Authorization** - JWT-based auth with Google OAuth integration
- 👥 **User Roles** - Distinct interfaces for mentees, mentors, and administrators
- 📅 **Meeting Scheduling** - Calendar-based booking system with timezone support
- 💳 **Payment Integration** - Stripe checkout and subscription management
- 💬 **Real-time Communication** - Socket.io for live notifications and updates
- 🖼️ **Media Management** - Cloudinary integration for profile images and assets
- 📧 **Email Notifications** - Automated email system with Mailtrap
- 🔍 **Advanced Search** - Filter mentors by language, expertise, and availability
- 📊 **Admin Dashboard** - Comprehensive management tools for platform oversight
- 🐳 **Docker Support** - Containerized deployment with Docker Compose
- 📝 **API Documentation** - OpenAPI/Swagger specification

## 🛠 Tech Stack

### Frontend

- **Framework**: React 19 + TypeScript
- **Build Tool**: Vite
- **Routing**: React Router v7
- **State Management**: Zustand
- **Styling**: Tailwind CSS 4
- **HTTP Client**: Axios
- **UI Components**: Lucide Icons, Framer Motion
- **Form Validation**: Zod

### Backend

- **Runtime**: Node.js 24.12.0
- **Framework**: Express.js + TypeScript
- **Database**: Microsoft SQL Server 2022
- **ORM**: Native MSSQL driver
- **Authentication**: JWT + Passport.js
- **Payment**: Stripe
- **Email**: Nodemailer + Mailtrap
- **File Storage**: Cloudinary
- **Real-time**: Socket.io
- **API Docs**: Swagger/OpenAPI

### DevOps & Tools

- **Package Manager**: pnpm 10.28.2
- **Monorepo**: Turbo
- **Containerization**: Docker + Docker Compose
- **Database UI**: Adminer
- **Linting**: ESLint 9
- **Formatting**: Prettier
- **Git Hooks**: Husky + lint-staged
- **Commit Convention**: Commitlint

## 📋 Table of Contents

- [Mentoria - DBM](#mentoria---dbm)
  - [✨ Features](#-features)
  - [🛠 Tech Stack](#-tech-stack)
    - [Frontend](#frontend)
    - [Backend](#backend)
    - [DevOps \& Tools](#devops--tools)
  - [📋 Table of Contents](#-table-of-contents)
  - [🛠 System Requirements](#-system-requirements)
    - [Install pnpm](#install-pnpm)
  - [🚀 Project Installation](#-project-installation)
    - [1. Clone repository](#1-clone-repository)
    - [2. Install dependencies](#2-install-dependencies)
  - [⚙️ Environment Variables](#️-environment-variables)
    - [Server Environment (Required)](#server-environment-required)
    - [Client Environment (Required)](#client-environment-required)
    - [Root Environment (For Docker)](#root-environment-for-docker)
    - [Getting API Keys](#getting-api-keys)
  - [📦 Managing Packages](#-managing-packages)
    - [Installing packages](#installing-packages)
    - [Removing packages](#removing-packages)
    - [Update packages](#update-packages)
  - [🏃‍♂️ Running the Project](#️-running-the-project)
    - [Development mode](#development-mode)
    - [First-time setup](#first-time-setup)
    - [Production build](#production-build)
  - [Local Database Setup](#local-database-setup)
    - [1. Create tables](#1-create-tables)
    - [2. Create triggers](#2-create-triggers)
    - [3. Create stored procedures](#3-create-stored-procedures)
    - [4. Create functions](#4-create-functions)
    - [5. Insert seed data](#5-insert-seed-data)
    - [6. Seed availability slots](#6-seed-availability-slots)
  - [📚 API Documentation](#-api-documentation)
    - [Accessing API Docs](#accessing-api-docs)
    - [Updating API Documentation](#updating-api-documentation)
  - [📮 Testing with Postman](#-testing-with-postman)
    - [Setup](#setup)
    - [Features](#features)
  - [🔧 Testing Stripe Webhooks on Localhost](#-testing-stripe-webhooks-on-localhost)
    - [Install Stripe CLI](#install-stripe-cli)
    - [Start Listening for Webhooks](#start-listening-for-webhooks)
    - [Test Checkout using Stripe Test Card](#test-checkout-using-stripe-test-card)
  - [🔄 Git Workflow](#-git-workflow)
    - [Commit Message Convention](#commit-message-convention)
    - [Hooks](#hooks)
    - [Branch Naming](#branch-naming)
    - [Standard Workflow](#standard-workflow)
  - [📜 Available Scripts](#-available-scripts)
    - [Root level](#root-level)
    - [Client](#client)
    - [Server](#server)

## 🛠 System Requirements

- Node.js >= 24.12.0
- pnpm >= 10.28.2
- Git

### Install pnpm

If you don't have pnpm installed, you can install it using one of the following methods:

**Using npm:**

```bash
npm install -g pnpm
```

For more installation options, visit [pnpm installation guide](https://pnpm.io/installation).

## 🚀 Project Installation

### 1. Clone repository

```bash
git clone <repository-url>
cd mentoria
```

### 2. Install dependencies

The project uses pnpm workspaces. Simply run from the root directory:

```bash
pnpm install
```

This will install all dependencies for root, client, and server automatically.

## ⚙️ Environment Variables

The project requires environment configuration for both client and server. Copy the example files and configure them:

### Server Environment (Required)

```bash
cd server
cp .env.example .env
```

**Configuration:**

```env
# Environment
NODE_ENV=development
PORT=3000

# Database
DB_USER=sa
DB_PASS=YourStrong@Password
DB_SERVER=localhost
DB_NAME=mentoria
DB_INIT=true  # Set to true on first run to initialize database

# JWT
JWT_SECRET=your_super_secret_jwt_key_here_min_32_chars

# Email
MAIL_USER=your_email@gmail.com
MAIL_PASS=your_app_password
MAIL_SEND=true  # Set false to disable email verification during development

# URLs
CLIENT_URL=http://localhost:5173

# Google OAuth (Get from Google Cloud Console)
GOOGLE_CLIENT_ID=your_google_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Cloudinary (Get from Cloudinary Dashboard)
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# Stripe (Get from Stripe Dashboard)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLIC_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...  # Get from Stripe CLI or Dashboard
```

### Client Environment (Required)

```bash
cd client
cp .env.example .env
```

**Configuration:**

```env
VITE_API_ENDPOINT=http://localhost:3000
```

### Root Environment (For Docker)

Create a `.env` file in the root directory for Docker Compose:

```env
# Docker Hub (optional - for pushing images)
DOCKERHUB_USERNAME=your_dockerhub_username

# Database credentials (must match server .env)
DB_USER=sa
DB_PASS=YourStrong@Password
DB_NAME=mentoria
```

### Getting API Keys

<details>
<summary><b>Google OAuth Setup</b></summary>

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google+ API
4. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
5. Set authorized redirect URIs:
   - `http://localhost:3000/api/auth/google/callback` (development)
   - `https://your-domain.com/api/auth/google/callback` (production)
6. Copy **Client ID** and **Client Secret** to your `.env`

</details>

<details>
<summary><b>Cloudinary Setup</b></summary>

1. Sign up at [Cloudinary](https://cloudinary.com/)
2. Go to **Dashboard**
3. Copy **Cloud Name**, **API Key**, and **API Secret** to your `.env`

</details>

<details>
<summary><b>Stripe Setup</b></summary>

1. Sign up at [Stripe](https://stripe.com/)
2. Go to **Developers** → **API Keys**
3. Copy **Publishable Key** (starts with `pk_`) and **Secret Key** (starts with `sk_`)
4. For webhooks, see [Testing Stripe Webhooks](#-testing-stripe-webhooks-on-localhost)

</details>

<details>
<summary><b>Email Setup (Gmail)</b></summary>

1. Enable 2-Factor Authentication on your Gmail account
2. Go to **Google Account** → **Security** → **App Passwords**
3. Generate a new app password for "Mail"
4. Use your Gmail address and the generated password in `.env`

</details>

## 📦 Managing Packages

### Installing packages

**Install package for all workspaces (root):**

```bash
pnpm add <package-name> -w
```

**Install package for specific workspace:**

```bash
# For client
pnpm add <package-name> --filter client

# For server
pnpm add <package-name> --filter server
```

**Install dev dependencies:**

```bash
# For client
pnpm add -D <package-name> --filter client

# For server
pnpm add -D <package-name> --filter server

# For root
pnpm add -D <package-name> -w
```

**Examples:**

```bash
# Install axios for client
pnpm add axios --filter client

# Install express types for server
pnpm add -D @types/express --filter server

# Install husky for root workspace
pnpm add -D husky -w
```

### Removing packages

```bash
# Remove from client
pnpm remove <package-name> --filter client

# Remove from server
pnpm remove <package-name> --filter server

# Remove from root
pnpm remove <package-name> -w
```

### Update packages

```bash
# Update specific package
pnpm update <package-name>

# Update all packages
pnpm update

# Update packages for specific workspace
pnpm update --filter client
```

## 🏃‍♂️ Running the Project

### Development mode

The project uses Turbo for monorepo management. Run both client and server simultaneously:

```bash
# From root directory - runs both client and server in parallel
pnpm dev
```

Or run them separately:

```bash
# Terminal 1 - Run server only
cd server
pnpm dev

# Terminal 2 - Run client only
cd client
pnpm dev
```

Server will run on `http://localhost:3000`
Client will run on `http://localhost:5173`

### First-time setup

On your first run, the database will be automatically initialized if `DB_INIT=true` is set in your server `.env` file. This will:

- Create all necessary tables
- Set up relationships and constraints
- Seed initial data (optional)

### Production build

```bash
# Build all packages from root
pnpm build

# Or build individually
cd client
pnpm build
pnpm start       # Preview production build

cd server
pnpm build
pnpm start       # Start production server
```

## Local Database Setup

To set up the database locally using SQL Server Management Studio (SSMS), follow these steps in order:

### 1. Create tables

Open `server/src/database/SQL.sql` in SSMS, copy the entire content, and execute it in SQL Server to create the database schema and tables.

### 2. Create triggers

Open `server/src/database/trigger.sql`, copy and execute it in SQL Server.

### 3. Create stored procedures

Open `server/src/database/procedure.sql`, copy and execute it in SQL Server.

### 4. Create functions

Open `server/src/database/function.sql`, copy and execute it in SQL Server.

### 5. Insert seed data

Open `server/src/database/INSERT_DATA.sql`, copy and execute it in SQL Server to populate the database with initial data.

### 6. Seed availability slots

Finally, run the following command to generate additional mentor availability slots:

```bash
cd server
pnpm seed:slot
```

> **Note:** Make sure your SQL Server is running and the connection details in `server/.env` match your local SQL Server configuration before executing the SQL files.

## 🔬 DBMS Comparison (SQL Server vs Cassandra)

This project includes a research component comparing **Microsoft SQL Server 2022** and **Apache Cassandra** in terms of query processing, optimization, and data storage mechanisms. If you are interested in this part, see the setup guide and test scenarios at:

**[`server/src/database/README.md`](server/src/database/README.md)**

That document covers how to start both systems via Docker, how to initialize the schema and seed data, and links to the specific benchmark query scripts.

## 📚 API Documentation

The server includes comprehensive API documentation using OpenAPI/Swagger.

### Accessing API Docs

1. **Start the server** (development or production)
2. **Open your browser** to: `http://localhost:3000/api-docs`

The interactive Swagger UI allows you to:

- Browse all available endpoints
- View request/response schemas
- Test API calls directly in the browser
- Download the OpenAPI specification

### Updating API Documentation

If you modify API endpoints, update the OpenAPI specification:

```bash
cd server
pnpm bundle:swagger
```

This bundles all YAML files in `src/openapi/` into a single specification.

## 📮 Testing with Postman

The project includes a Postman collection with pre-configured requests.

### Setup

1. **Import Collection**
   - Open Postman
   - Click **Import**
   - Select `postman/collections/Mentoria.postman_collection.json`

2. **Import Environment**
   - Click **Import**
   - Select `postman/environments/Mentoria.postman_environment.json`

3. **Configure Environment**
   - Select "Mentoria" environment in Postman
   - Update variables if needed:
     - `host`: `http://localhost:3000`

### Features

The collection includes:

- All API endpoints organized by category
- Pre-configured authentication headers
- Example request bodies
- Environment variables for tokens
- Test scripts for automated assertions

## 🔧 Testing Stripe Webhooks on Localhost

To test Stripe webhooks in your local development environment, you need to install the **Stripe CLI** and forward incoming webhook events to your local API endpoint.

### Install Stripe CLI

Download and install Stripe CLI from:
[https://stripe.com/docs/stripe-cli](https://stripe.com/docs/stripe-cli)

### Start Listening for Webhooks

Run the following command to forward all Stripe webhook events to your local server:

```bash
stripe listen --forward-to localhost:3000/api/pay/webhook
```

After running this command, Stripe CLI will generate a **Webhook Signing Secret**, which you must set in your environment variables:

```bash
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx
```

### Test Checkout using Stripe Test Card

Use the following **Stripe test card** to simulate a successful payment inside Stripe Checkout:

| Card Number             | Expiry          | CVC          | ZIP |
| ----------------------- | --------------- | ------------ | --- |
| **4242 4242 4242 4242** | Any future date | Any 3 digits | Any |

Example:

```bash
Card number: 4242 4242 4242 4242
Expiry: 12/34
CVC: 123
ZIP: 10000
```

## 🔄 Git Workflow

### Commit Message Convention

The project uses [Conventional Commits](https://www.conventionalcommits.org/):

```bash
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation update
- `style`: Formatting changes that don't affect code logic
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `test`: Adding or fixing tests
- `chore`: Build tasks, package manager configs, etc.

**Examples:**

```bash
git commit -m "feat(auth): add user login functionality"
git commit -m "fix(api): resolve user data fetching issue"
git commit -m "docs: update installation guide"
git commit -m "style(client): format code with prettier"
```

### Hooks

The project has built-in git hooks to ensure code quality:

- **pre-commit**: Run lint and format code
- **commit-msg**: Check commit message format

### Branch Naming

- `main`: Production branch
- `feature/feature-name`: For new features
- `bugfix/bug-description`: For bug fixes
- `hotfix/issue-description`: For urgent production issues

### Standard Workflow

1. **Create a new branch**
   Always branch off from the latest version of `main`.

   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature-name
   ```

2. **Work on your feature**
   Make your code changes and commit them using the [Conventional Commits](https://www.conventionalcommits.org/) format:

   ```bash
   git add .
   git commit -m "feat(auth): add login functionality"
   ```

3. **Rebase with the latest main branch**
   Before pushing, make sure your branch is up to date with `main`:

   ```bash
   git fetch origin
   git rebase origin/main
   ```

4. **Push your branch to remote**

   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request (PR)**
   Open a PR to merge your branch into `main` using the project’s PR template.
   Wait for review and approval before merging.

6. **After Merge — Sync and Clean Up**
   Once your PR is merged:

   ```bash
   git checkout main
   git pull origin main
   git branch -d feature/your-feature-name     # delete local branch
   git push origin --delete feature/your-feature-name   # delete remote branch
   ```

## 📜 Available Scripts

### Root level

```bash
pnpm prepare        # Setup husky hooks
pnpm dev            # Run both client and server in development mode (parallel)
pnpm build          # Build both client and server
pnpm start          # Start both client and server (parallel)
pnpm lint           # Run linting for all packages
pnpm lint:fix       # Fix linting errors for all packages
pnpm format         # Check code formatting for all packages
pnpm format:fix     # Auto-format code for all packages
pnpm clean          # Clean build artifacts for all packages
```

### Client

```bash
pnpm dev           # Start development server
pnpm build         # Build for production
pnpm start         # Preview production build
pnpm lint          # Check for linting errors
pnpm lint:fix      # Fix auto-fixable linting errors
pnpm format        # Check code formatting
pnpm format:fix    # Auto-format code
pnpm clean         # Clean build artifacts
```

### Server

```bash
pnpm dev            # Start development server with nodemon
pnpm build          # Build TypeScript to JavaScript
pnpm start          # Start production server
pnpm debug          # Start server in debug mode
pnpm seed           # Seed database with mock data
pnpm lint           # Check for linting errors
pnpm lint:fix       # Fix auto-fixable linting errors
pnpm format         # Check code formatting
pnpm format:fix     # Auto-format code
pnpm bundle:swagger # Bundle swagger yaml file
pnpm clean          # Clean build artifacts
```
