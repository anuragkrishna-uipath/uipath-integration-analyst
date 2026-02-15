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
   git clone <repo-url> <project-directory>
   cd <project-directory>
   cp .env.example .env
   # Edit .env with your email and credentials
   ```

3. **Authenticate**:
   ```bash
   source .env
   sf org login web --instance-url ${SALESFORCE_INSTANCE_URL} --alias ${SALESFORCE_ORG_ALIAS}
   ```

4. **Add ARR data file**:
   ```bash
   # Place your ARR CSV file in the arr/ directory
   # File should be named: Customer_Connector_Originator_APIUsage_YYYY-MM-DD-HHMM.csv
   mkdir -p arr
   # Copy your ARR CSV file to arr/ directory
   ```

5. **Generate your first customer profile**:
   ```bash
   cd ${PROJECT_DIR}
   claude  # Start Claude Code
   /customer-profile "Example Corporation"
   ```

**Don't have Claude Code?** You can still use the scripts directly:
```bash
bash scripts/subsidiary-license-info.sh "Example Corporation"
```

See [detailed setup instructions](#setup) below for step-by-step guidance.

## What is Claude Code?

[Claude Code](https://claude.ai/code) is an AI-powered CLI tool that helps you work with codebases, run scripts, and perform analysis through natural language commands. This project is designed to work with Claude Code's skill system, allowing you to generate customer profiles and query data sources using simple commands like `/customer-profile "Customer Name"`.

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
git clone <repository-url> <project-directory>
cd <project-directory>
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
PROJECT_DIR=<full-path-to-project-directory>

# Salesforce Configuration
SALESFORCE_INSTANCE_URL=https://yourorg.my.salesforce.com
SALESFORCE_ORG_ALIAS=yourorg

# Snowflake Configuration
SNOWFLAKE_ACCOUNT=YOUR_SNOWFLAKE_ACCOUNT
SNOWFLAKE_USER=your.email@company.com
```

**Replace** the placeholder values with your actual configuration.

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

### 5. Create Data Directories and Add ARR Data

```bash
# Create directories for cached data
mkdir -p ${PROJECT_DIR}/{arr,snowflake-data,is-cases}
```

**Important - ARR Data Setup**:
The customer profile skill requires ARR (Annual Recurring Revenue) data to be present in the `arr/` directory:

1. **Obtain ARR CSV file** from your internal data source
2. **File format**: Should contain columns: `NAME,GROUPEDORIGINATOR,APIUSAGE,ARR,Ticket Count`
3. **Place in arr/ directory**:
   ```bash
   # Copy your ARR CSV file to arr/ directory
   cp /path/to/Customer_Connector_Originator_APIUsage_YYYY-MM-DD-HHMM.csv ${PROJECT_DIR}/arr/
   ```
4. **File naming**: Use format `Customer_Connector_Originator_APIUsage_YYYY-MM-DD-HHMM.csv`
5. **Cache duration**: ARR files are cached for 7 days (use most recent file if < 7 days old)

**Note**: Without ARR data, the customer profile skill will still work but will note "ARR data not available".

### 6. Verify Claude Code Skills

The skills are included in the repository under `.claude/skills/` and are automatically available when you run Claude Code in the project directory.

Verify skills are available:
```bash
cd ${PROJECT_DIR}
claude
# Then run: /help
# You should see the skills listed: customer-profile, sf-integration-cases, etc.
```

**Available skills**:
- `/customer-profile` - Comprehensive customer analysis
- `/sf-integration-cases` - Pull Salesforce support tickets
- `/snowflake-customer-license-info` - Query license consumption
- `/snowflake-is-usage` - Query Integration Service API usage
- `/customer-in-news` - Search for recent customer news

### 7. Test Your Setup

Run a quick test to verify everything is working:

```bash
cd ${PROJECT_DIR}
claude

# In Claude Code, try:
/customer-in-news "Microsoft"  # Should search web and return news

# Then try a customer profile (if you have ARR data):
/customer-profile "Your Customer Name"
```

### 8. Install Python Dependencies (Optional)

Only needed if you want to use the Python Salesforce fallback client:

```bash
cd ${PROJECT_DIR}
python3 -m venv venv
source venv/bin/activate
pip install simple-salesforce
```

## Usage

### Option 1: Using Claude Code Skills (Recommended)

If you have Claude Code installed, you can use natural language and slash commands to analyze customers:

```bash
# Start Claude Code in the project directory
cd ${PROJECT_DIR}
claude

# Generate comprehensive customer profile (includes all data sources + news)
/customer-profile "Example Corporation"
/customer-profile "Customer Name"

# Pull specific data sources
/sf-integration-cases 180 "Customer Name"              # Last 180 days of support tickets
/snowflake-customer-license-info "Customer Name"       # License consumption data
/snowflake-is-usage "Customer Name"                    # Integration Service API usage (last 3 months)
/customer-in-news "Customer Name"                      # Recent news articles

# Or just ask Claude naturally:
# "Generate a customer profile for Example Corporation"
# "What are the recent support tickets for Customer Name?"
# "Show me the license consumption for Customer Name"
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
cd ${PROJECT_DIR}

# Fetch customer license data from Snowflake
bash scripts/subsidiary-license-info.sh "Customer Name"

# Fetch support tickets from Salesforce (last 180 days)
bash scripts/sf-integration-cases.sh 180 "Customer Name"

# Fetch Integration Service API usage from Snowflake (last 3 months)
bash scripts/snowflake-is-usage.sh "Customer Name"

# Query all customers (no customer filter)
bash scripts/snowflake-is-usage.sh
```

**Note**: Scripts read credentials from `.env` file automatically. Results are saved to:
- License data: `${PROJECT_DIR}/snowflake-data/`
- Support tickets: `${PROJECT_DIR}/is-cases/`
- API usage: `${PROJECT_DIR}/snowflake-data/`

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

- **`arr/`** - ARR and API usage CSV files
  - **Source**: Manually placed by user (exported from internal data warehouse)
  - **Format**: `Customer_Connector_Originator_APIUsage_YYYY-MM-DD-HHMM.csv`
  - **Required columns**: `NAME,GROUPEDORIGINATOR,APIUSAGE,ARR,Ticket Count`
  - **Cache duration**: 7 days (use most recent file if < 7 days old)
  - **Purpose**: Provides ARR bucket, API usage totals, and ticket counts for customer profiles

- **`snowflake-data/`** - License consumption and IS usage CSV files (auto-generated)
  - License files: `subsidiary_license_<customer>_<timestamp>.csv`
  - IS usage files: `snowflake_is_usage_<timestamp>_<customer>.csv`
  - Cache duration: License data (no expiry), IS usage (7 days)

- **`is-cases/`** - Support ticket JSON files (auto-generated)
  - Format: `sf_integration_cases_<days>days_<customer>_<timestamp>.json`
  - Cache duration: 24 hours

**Note**: These directories are in `.gitignore` and will not be committed to version control.

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
├── .claude/
│   ├── skills/               # Claude Code interactive skills (project-level)
│   │   ├── customer-profile/     # Comprehensive customer analysis
│   │   ├── sf-integration-cases/ # Salesforce case retrieval
│   │   ├── customer-in-news/     # Web search for customer news
│   │   ├── snowflake-customer-license-info/ # License data retrieval
│   │   └── snowflake-is-usage/   # API usage analytics
│   └── settings.local.json   # Claude Code local settings (not in git)
│
├── arr/                      # ARR data (USER PROVIDED - place CSV files here!)
│   └── Customer_Connector_Originator_APIUsage_*.csv  # ARR CSV files
│
├── snowflake-data/           # License & IS usage CSV files (auto-generated, not in git)
├── is-cases/                 # Support ticket JSON files (auto-generated, not in git)
└── venv/                     # Python virtual environment (optional, not in git)
```

**Key Directories**:
- **`arr/`** - **IMPORTANT**: You must manually place ARR CSV files here for customer profiles to work
- **`scripts/`** - Bash scripts that query Snowflake and Salesforce
- **`.claude/skills/`** - Claude Code skills (automatically available when running Claude in project directory)
- **`snowflake-data/`, `is-cases/`** - Auto-generated cache directories (created automatically)

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
  cd ${PROJECT_DIR}
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
- Example: Different variations of company names may exist in different systems

**"Claude Code skills not showing up"**
- Not running Claude Code from the project directory
- Solution:
  ```bash
  # Make sure you're in the project directory
  cd ${PROJECT_DIR}

  # Start Claude Code
  claude

  # Verify skills with /help command
  ```
- Skills are in `.claude/skills/` and only available when running Claude in this directory

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

| Data Source | Cache Duration | Cache Location | Cache Behavior | Source |
|-------------|----------------|----------------|----------------|---------|
| ARR Data | 7 days | `arr/*.csv` | Manual - use most recent if < 7 days old | **User provides** (export from data warehouse) |
| License Data | No expiry | `snowflake-data/subsidiary_license_*.csv` | Per-customer - use if file exists | Auto-generated by scripts |
| IS Usage | 7 days | `snowflake-data/snowflake_is_usage_*.csv` | Per-customer - refresh if > 7 days old | Auto-generated by scripts |
| Support Tickets | 24 hours | `is-cases/sf_integration_cases_*.json` | Per-query - refresh if > 24 hours old | Auto-generated by scripts |

**ARR Data Setup**: Place your ARR CSV file in the `arr/` directory. The file should contain columns: `NAME,GROUPEDORIGINATOR,APIUSAGE,ARR,Ticket Count`.

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
