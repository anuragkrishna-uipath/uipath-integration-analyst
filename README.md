# uipath-integration-analyst

A Intefration assistant toolkit for analyzing UiPath customer data w.r.t integrations. Aggregates information from Salesforce, Snowflake, and ARR data to generate comprehensive customer profiles and actionable insights.

## Features

- **Customer Profile Generation**: 360-degree view combining ARR, license consumption, API usage, and support tickets
- **Salesforce Integration**: Pull Integration Service cases with flexible filtering
- **Snowflake Analytics**: Query license consumption and API usage data
- **Customer News Search**: Find recent news articles about customers
- **Claude Code Skills**: Interactive AI-powered skills for common PM workflows

## Table of Contents

- [Quick Start](#quick-start)
- [What is Claude Code?](#what-is-claude-code)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Usage](#usage)
- [Data Storage](#data-storage)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Data Caching](#data-caching)
- [Security Notes](#security-notes)
- [Contributing](#contributing)

## Quick Start

**New to this project?** Follow these steps to get started:

1. **Install prerequisites** (one-time setup):
   ```bash
   # Install Claude Code from https://claude.ai/code
   # Install Salesforce CLI: brew install sf
   # Install SnowSQL from Snowflake downloads
   ```

2. **Clone and configure**:
   ```bash
   git clone <repo-url> ~/Documents/uipath-integration-analyst
   cd ~/Documents/uipath-integration-analyst
   cp .env.example .env
   # Edit .env with your email and credentials
   ```

3. **Authenticate**:
   ```bash
   source .env
   sf org login web --instance-url ${SALESFORCE_INSTANCE_URL} --alias ${SALESFORCE_ORG_ALIAS}
   ```

4. **Link Claude Code skills** (optional but recommended):
   ```bash
   ln -s ~/Documents/uipath-integration-analyst/skills ~/.claude/skills/uipath-pm
   ```

5. **Generate your first customer profile**:
   ```bash
   cd ~/Documents/uipath-integration-analyst
   claude  # Start Claude Code
   /customer-profile "BMW Group"
   ```

**Don't have Claude Code?** You can still use the scripts directly:
```bash
bash scripts/subsidiary-license-info.sh "BMW Group"
```

See [detailed setup instructions](#setup) below for step-by-step guidance.

## What is Claude Code?

[Claude Code](https://claude.ai/code) is an AI-powered CLI tool that helps you work with codebases, run scripts, and perform analysis through natural language commands. This project is designed to work with Claude Code's skill system, allowing you to generate customer profiles and query data sources using simple commands like `/customer-profile "BMW"`.

## Prerequisites

Before setting up this project, you'll need to install the following tools:

### Required Tools

1. **Claude Code CLI** (recommended)
   - Visit [claude.ai/code](https://claude.ai/code) to download and install
   - Provides AI-powered interactive skills for customer analysis
   - Not strictly required - scripts can be run directly without Claude Code

2. **Salesforce CLI v2** (`sf` command)
   - Installation: [Salesforce CLI Setup Guide](https://developer.salesforce.com/tools/salesforcecli)
   - macOS: `brew install sf`
   - Verify installation: `sf --version`

3. **SnowSQL CLI**
   - Installation: [SnowSQL Install Guide](https://docs.snowflake.com/en/user-guide/snowsql-install-config)
   - macOS: Download from Snowflake downloads page
   - Verify installation: `snowsql --version`

4. **Python 3.x** (optional, for Salesforce fallback client)
   - macOS: `brew install python3`
   - Verify installation: `python3 --version`

5. **Git** (to clone this repository)
   - macOS: `brew install git` or use built-in git
   - Verify installation: `git --version`

## Setup

### 1. Clone the Repository

```bash
# Clone the repository to your local machine
git clone <repository-url> ~/Documents/uipath-integration-analyst
cd ~/Documents/uipath-integration-analyst
```

### 2. Install Claude Code CLI (Recommended)

If you haven't installed Claude Code yet:

1. Visit [claude.ai/code](https://claude.ai/code)
2. Download the installer for your platform
3. Follow the installation instructions
4. Verify installation: `claude --version`

**Note**: You can use this project without Claude Code by running scripts directly (see "Direct Script Execution" below).

### 3. Configure Environment Variables

Create a `.env` file with your credentials:

```bash
# Create .env file from example (if it exists)
cp .env.example .env 2>/dev/null || touch .env

# Edit .env file
nano .env
```

Add the following configuration to `.env`:

```bash
# Project Configuration
PROJECT_DIR=~/Documents/uipath-integration-analyst

# Salesforce Configuration
SALESFORCE_INSTANCE_URL=https://uipath.my.salesforce.com
SALESFORCE_ORG_ALIAS=uipath

# Snowflake Configuration
SNOWFLAKE_ACCOUNT=UIPATH-UIPATH_OBSERVABILITY
SNOWFLAKE_USER=your.email@uipath.com
```

**Replace** `your.email@uipath.com` with your actual UiPath email address.

**Important**:
- Never commit the `.env` file to git (it's already in `.gitignore`)
- This file contains configuration only - no passwords are stored

### 4. Authenticate to Data Sources

**Salesforce Authentication**:
```bash
# Load environment variables
source .env

# Login via SSO (opens browser)
sf org login web --instance-url ${SALESFORCE_INSTANCE_URL} --alias ${SALESFORCE_ORG_ALIAS}
```

**Snowflake Authentication**:
```bash
# Test Snowflake connection (opens browser for SSO)
snowsql -a ${SNOWFLAKE_ACCOUNT} -u ${SNOWFLAKE_USER} --authenticator externalbrowser
```

Snowflake authentication happens automatically via SSO when running queries - no separate login required.

### 5. Create Data Directories

```bash
# Create directories for cached data
mkdir -p ~/Documents/uipath-integration-analyst/{arr,snowflake-data,is-cases}
```

### 6. Set Up Claude Code Skills (If Using Claude Code)

Link the skills directory so Claude Code can discover them:

```bash
# Option 1: Symlink the entire skills directory (recommended)
ln -s ~/Documents/uipath-integration-analyst/skills ~/.claude/skills/uipath-pm

# Option 2: Symlink individual skills
mkdir -p ~/.claude/skills
ln -s ~/Documents/uipath-integration-analyst/skills/customer-profile ~/.claude/skills/customer-profile
ln -s ~/Documents/uipath-integration-analyst/skills/sf-integration-cases ~/.claude/skills/sf-integration-cases
ln -s ~/Documents/uipath-integration-analyst/skills/snowflake-customer-license-info ~/.claude/skills/snowflake-customer-license-info
ln -s ~/Documents/uipath-integration-analyst/skills/snowflake-is-usage ~/.claude/skills/snowflake-is-usage
ln -s ~/Documents/uipath-integration-analyst/skills/customer-in-news ~/.claude/skills/customer-in-news
```

Verify skills are available:
```bash
# In Claude Code CLI
/help
# You should see the skills listed
```

### 7. Install Python Dependencies (Optional)

Only needed if you want to use the Python Salesforce fallback client:

```bash
cd ~/Documents/uipath-integration-analyst
python3 -m venv venv
source venv/bin/activate
pip install simple-salesforce
```

## Usage

### Option 1: Using Claude Code Skills (Recommended)

If you have Claude Code installed, you can use natural language and slash commands to analyze customers:

```bash
# Start Claude Code in the project directory
cd ~/Documents/uipath-integration-analyst
claude

# Generate comprehensive customer profile (includes all data sources + news)
/customer-profile "BMW Group"
/customer-profile "PepsiCo, Inc"

# Pull specific data sources
/sf-integration-cases 180 "BMW Group"              # Last 180 days of support tickets
/snowflake-customer-license-info "BMW Group"       # License consumption data
/snowflake-is-usage "BMW Group"                    # Integration Service API usage (last 3 months)
/customer-in-news "BMW Group"                      # Recent news articles

# Or just ask Claude naturally:
# "Generate a customer profile for BMW"
# "What are the recent support tickets for PepsiCo?"
# "Show me the license consumption for Microsoft"
```

**Benefits of Claude Code**:
- Automatically handles caching (checks for recent data before querying)
- Provides formatted analysis and insights
- Searches the web for customer news
- Generates actionable recommendations
- Parses large CSV/JSON files automatically

### Option 2: Direct Script Execution

You can also run the data collection scripts directly without Claude Code:

```bash
cd ~/Documents/uipath-integration-analyst

# Fetch customer license data from Snowflake
bash scripts/subsidiary-license-info.sh "BMW Group"

# Fetch support tickets from Salesforce (last 180 days)
bash scripts/sf-integration-cases.sh 180 "BMW Group"

# Fetch Integration Service API usage from Snowflake (last 3 months)
bash scripts/snowflake-is-usage.sh "BMW Group"

# Query all customers (no customer filter)
bash scripts/snowflake-is-usage.sh
```

**Note**: Scripts read credentials from `.env` file automatically. Results are saved to:
- License data: `~/Documents/uipath-integration-analyst/snowflake-data/`
- Support tickets: `~/Documents/uipath-integration-analyst/is-cases/`
- API usage: `~/Documents/uipath-integration-analyst/snowflake-data/`

### Understanding the Output

**Customer Profile Output** (from `/customer-profile`):
- **Customer Data Table**: ARR, licenses, IS usage, support tickets, recent news
- **Action Items Table**: 3-5 prioritized recommendations based on data analysis
- **Insights**: Each data category includes analysis and recommendations
- **Sources**: All customer news includes source citations

**Data Files**:
- CSV files: Can be opened in Excel or analyzed with Python/pandas
- JSON files: Salesforce case data in structured format
- Files include timestamps in filename for tracking freshness

## Data Storage

All data is cached locally to minimize authentication requests:

- `arr/` - ARR and API usage CSV files (cached 7 days)
- `snowflake-data/` - License consumption CSV files (cached per customer)
- `is-cases/` - Support ticket JSON files (cached 24 hours)

**Note**: These directories are in `.gitignore` and will not be committed.

## Project Structure

```
uipath-integration-analyst/
├── .env                      # Environment configuration (not in git)
├── .env.example              # Environment configuration template
├── .gitignore                # Git ignore rules
├── README.md                 # This file - setup and usage guide
├── CLAUDE.md                 # Claude Code AI guidance and project context
│
├── scripts/                  # Data extraction bash scripts
│   ├── README.md             # Detailed script documentation
│   ├── subsidiary-license-info.sh      # Snowflake license query
│   ├── sf-integration-cases.sh         # Salesforce cases query
│   ├── snowflake-is-usage.sh           # Snowflake API usage query
│   └── fetch_salesforce_cases.py       # Python Salesforce client (fallback)
│
├── sql/                      # SQL query files for Snowflake
│   ├── README.md             # SQL query documentation
│   ├── subsidiary_license_query.sql    # Customer license query
│   ├── is_usage_query_with_customer.sql # IS usage (customer filter)
│   └── is_usage_query_all.sql          # IS usage (all customers)
│
├── skills/                   # Claude Code interactive skills
│   ├── customer-profile/     # Comprehensive customer analysis
│   ├── sf-integration-cases/ # Salesforce case retrieval
│   ├── customer-in-news/     # Web search for customer news
│   ├── snowflake-customer-license-info/ # License data retrieval
│   └── snowflake-is-usage/   # API usage analytics
│
├── arr/                      # ARR and API usage data (cached, not in git)
├── snowflake-data/           # License & IS usage CSV files (cached, not in git)
├── is-cases/                 # Support ticket JSON files (cached, not in git)
└── venv/                     # Python virtual environment (optional, not in git)
```

## Troubleshooting

### Common Issues

**"Command not found: snowsql"**
- SnowSQL is not installed or not in PATH
- Solution: Install SnowSQL from [Snowflake downloads](https://docs.snowflake.com/en/user-guide/snowsql-install-config)
- Verify: `snowsql --version`

**"Command not found: sf"**
- Salesforce CLI v2 is not installed
- Solution: `brew install sf` or visit [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)
- Verify: `sf --version`

**"SQL file not found"**
- Running scripts from wrong directory
- Solution: Always run scripts from project root or use absolute paths:
  ```bash
  cd ~/Documents/uipath-integration-analyst
  bash scripts/snowflake-is-usage.sh "Customer Name"
  ```

**"Snowflake authentication failed"**
- SSO session expired or not authenticated
- Solution: Manually authenticate:
  ```bash
  source .env
  snowsql -a ${SNOWFLAKE_ACCOUNT} -u ${SNOWFLAKE_USER} --authenticator externalbrowser
  ```

**"Salesforce authentication failed"**
- Not logged in or session expired
- Solution: Re-authenticate:
  ```bash
  source .env
  sf org login web --instance-url ${SALESFORCE_INSTANCE_URL} --alias ${SALESFORCE_ORG_ALIAS}
  ```

**"No results found for customer"**
- Customer name spelling doesn't match Snowflake/Salesforce records
- Solution: Try partial names or check exact spelling in source systems
- Example: "T-Mobile" vs "T-Mobile USA, Inc" vs "T-Mobile US, Inc"

**"Claude Code skills not showing up"**
- Skills directory not linked correctly
- Solution:
  ```bash
  # Remove old symlink if exists
  rm ~/.claude/skills/uipath-pm

  # Create new symlink
  ln -s ~/Documents/uipath-integration-analyst/skills ~/.claude/skills/uipath-pm

  # Restart Claude Code
  ```

**"Permission denied" when running scripts**
- Scripts don't have execute permissions
- Solution:
  ```bash
  chmod +x scripts/*.sh
  ```

**"Environment variables not found"**
- .env file not loaded or missing variables
- Solution:
  ```bash
  # Check .env file exists
  ls -la .env

  # Verify contents
  cat .env

  # Load environment variables
  source .env
  echo $SNOWFLAKE_USER  # Should print your email
  ```

### Getting Help

- Check `scripts/README.md` for detailed script documentation
- Check `sql/README.md` for SQL query details
- Review individual skill README files in `skills/*/skill.md`
- For Claude Code issues: Run `/help` in Claude Code CLI

## Data Caching

This project uses intelligent caching to minimize authentication flows and API calls:

| Data Source | Cache Duration | Cache Location | Cache Behavior |
|-------------|----------------|----------------|----------------|
| ARR Data | 7 days | `arr/*.csv` | Manual upload - use if < 7 days old |
| License Data | No expiry | `snowflake-data/subsidiary_license_*.csv` | Per-customer cache - use if customer file exists |
| IS Usage | 7 days | `snowflake-data/snowflake_is_usage_*.csv` | Per-customer cache - refresh if > 7 days old |
| Support Tickets | 24 hours | `is-cases/sf_integration_cases_*.json` | Per-query cache - refresh if > 24 hours old |

**Cache Invalidation**: Delete specific files in cache directories to force fresh queries.

## Security Notes

- Never commit `.env` file or any files containing credentials
- The `.gitignore` is configured to exclude sensitive data:
  - `.env` (credentials and configuration)
  - `arr/`, `snowflake-data/`, `is-cases/` (cached customer data)
  - `venv/` (Python virtual environment)
- All authentication uses SSO/OAuth - no passwords in scripts
- Data directories are excluded from version control
- All data files are stored locally - nothing is sent to external services (except Claude Code analysis)

## Contributing

When contributing to this repository:

1. Never commit sensitive data or credentials
2. Test scripts with sample data before committing
3. Update documentation when adding new features
4. Follow existing code style and structure
5. Add new SQL queries to `sql/` directory
6. Document new skills in their respective `skill.md` files

## License

Internal tool for UiPath Product Management use.
