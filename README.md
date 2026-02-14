# PM Assistant

A Product Manager assistant toolkit for analyzing UiPath customer data. Aggregates information from Salesforce, Snowflake, and ARR data to generate comprehensive customer profiles and actionable insights.

## Features

- **Customer Profile Generation**: 360-degree view combining ARR, license consumption, API usage, and support tickets
- **Salesforce Integration**: Pull Integration Service cases with flexible filtering
- **Snowflake Analytics**: Query license consumption and API usage data
- **Customer News Search**: Find recent news articles about customers
- **Claude Code Skills**: Interactive skills for common PM workflows

## Prerequisites

- **Salesforce CLI**: `sf` CLI v2 ([installation guide](https://developer.salesforce.com/tools/salesforcecli))
- **SnowSQL CLI**: For Snowflake queries ([installation guide](https://docs.snowflake.com/en/user-guide/snowsql-install-config))
- **Python 3.x**: For Salesforce fallback client
- **Claude Code**: For using the interactive skills

## Setup

### 1. Clone and Configure

```bash
cd ~/Documents/uipath-integration-analyst
```

### 2. Set Up Environment Variables

Copy the example environment file and configure your credentials:

```bash
cp .env.example .env
```

Edit `.env` and configure:

```bash
# Salesforce Configuration
SALESFORCE_INSTANCE_URL=https://your-instance.my.salesforce.com
SALESFORCE_ORG_ALIAS=your-org-alias

# Snowflake Configuration
SNOWFLAKE_ACCOUNT=YOUR-SNOWFLAKE-ACCOUNT
SNOWFLAKE_USER=your.email@company.com
```

**Important**: Never commit the `.env` file to git. It's already in `.gitignore`.

### 3. Authenticate

**Salesforce**:
```bash
sf org login web --instance-url $SALESFORCE_INSTANCE_URL --alias $SALESFORCE_ORG_ALIAS
```

**Snowflake**: Authentication happens automatically via SSO when running queries.

### 4. Install Python Dependencies (optional)

For the Salesforce Python fallback client:

```bash
python3 -m venv venv
source venv/bin/activate
pip install simple-salesforce
```

### 5. Set Up Claude Code Skills (optional)

If using Claude Code, create a symlink to make skills discoverable:

```bash
ln -s ~/Documents/uipath-integration-analyst/skills ~/.claude/skills
```

## Usage

### Direct Script Execution

**Fetch Customer License Data**:
```bash
./subsidiary-license-info.sh "Customer Name" "your.email@company.com"
```

**Fetch Support Tickets**:
```bash
./sf-integration-cases.sh 180 "Customer Name"
```

**Fetch API Usage Data**:
```bash
./snowflake-is-usage.sh "your.email@company.com"
```

### Claude Code Skills

If using Claude Code, invoke skills with slash commands:

```bash
/customer-profile "Customer Name"
/sf-integration-cases 180 "Customer Name"
/snowflake-customer-license-info "Customer Name"
/customer-in-news "Customer Name"
```

## Data Storage

All data is cached locally to minimize authentication requests:

- `arr/` - ARR and API usage CSV files (cached 7 days)
- `snowflake-data/` - License consumption CSV files (cached per customer)
- `is-cases/` - Support ticket JSON files (cached 24 hours)

**Note**: These directories are in `.gitignore` and will not be committed.

## Project Structure

```
uipath-integration-analyst/
├── .env.example              # Environment configuration template
├── .gitignore                # Git ignore rules
├── README.md                 # This file
├── CLAUDE.md                 # Claude Code guidance
├── subsidiary-license-info.sh    # Snowflake license query
├── sf-integration-cases.sh       # Salesforce cases query
├── snowflake-is-usage.sh         # Snowflake API usage query
├── fetch_salesforce_cases.py     # Python Salesforce client
└── skills/                   # Claude Code skills
    ├── customer-profile/
    ├── sf-integration-cases/
    ├── customer-in-news/
    ├── snowflake-customer-license-info/
    └── snowflake-is-usage/
```

## Security Notes

- Never commit `.env` file or any files containing credentials
- The `.gitignore` is configured to exclude sensitive data
- All authentication uses SSO/OAuth - no passwords in scripts
- Data directories are excluded from version control

## License

Internal tool for UiPath Product Management use.
