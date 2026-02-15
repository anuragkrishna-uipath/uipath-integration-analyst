# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Product Manager assistant toolkit for analyzing UiPath customer data. It aggregates information from multiple sources (Salesforce, Snowflake, ARR data) to generate comprehensive customer profiles and insights for account management and product decisions.

## Core Architecture

### Data Pipeline Flow

1. **Data Extraction Scripts** (bash shells in `scripts/` directory)
   - `scripts/subsidiary-license-info.sh` - Queries Snowflake for customer license data
   - `scripts/sf-integration-cases.sh` - Queries Salesforce for support tickets
   - `scripts/snowflake-is-usage.sh` - Queries Snowflake for Integration Service API usage
   - All scripts save results to `~/Documents/uipath-integration-analyst/` subdirectories with timestamped filenames

2. **Data Storage Locations**
   - `~/Documents/uipath-integration-analyst/arr/` - ARR and API usage CSV files (cached weekly)
   - `~/Documents/uipath-integration-analyst/snowflake-data/` - License consumption CSV files (cached per customer)
   - `~/Documents/uipath-integration-analyst/is-cases/` - Support ticket JSON files (cached 24 hours)

3. **Claude Skills** (in `.claude/skills/` directory)
   - Each skill has a `skill.md` file defining its behavior
   - Skills are invoked with `/skill-name` syntax
   - Primary skill: `/customer-profile` - aggregates all data sources into actionable customer profile

## Environment Configuration

All configuration is managed through the `.env` file in the project root. Required variables:

```bash
# Project Configuration
PROJECT_DIR=~/Documents/uipath-integration-analyst  # Base directory for all data storage

# Snowflake Configuration
SNOWFLAKE_ACCOUNT=UIPATH-UIPATH_OBSERVABILITY
SNOWFLAKE_USER=your.email@company.com

# Salesforce Configuration
SALESFORCE_INSTANCE_URL=https://uipath.my.salesforce.com
SALESFORCE_ORG_ALIAS=uipath
```

### Authentication Requirements

**Snowflake**: Uses `snowsql` CLI with SSO via `--authenticator externalbrowser`
- Account and user are read from .env file
- Database: `prod_customer360.customerprofile` and `PROD_ELEMENTSERVICE`
- First run requires browser authentication, subsequent runs use cached session

**Salesforce**: Uses `sf` CLI (Salesforce CLI v2)
- Target org configured via .env (SALESFORCE_ORG_ALIAS)
- Instance URL configured via .env (SALESFORCE_INSTANCE_URL)
- First run: `sf org login web --instance-url ${SALESFORCE_INSTANCE_URL} --alias ${SALESFORCE_ORG_ALIAS}`
- Python fallback script (`fetch_salesforce_cases.py`) supports multiple auth methods

## Skills Usage

```bash
# Generate comprehensive customer profile (includes web search automatically)
/customer-profile "Customer Name"

# Search for customer in news
/customer-in-news "Customer Name"

# Pull Salesforce Integration Service cases
/sf-integration-cases 180 "Customer Name"

# Query Snowflake license info (username from .env)
/snowflake-customer-license-info "Customer Name"

# Query Snowflake IS usage (username from .env, checks cache for customer, queries if not found)
/snowflake-is-usage "Customer Name"
/snowflake-is-usage  # All customers
```

## Caching Strategy

All data-fetching skills implement intelligent caching with data validation to minimize authentication flows. For detailed caching logic and data parsing patterns, refer to individual skill documentation:

- **ARR data**: Manual cache management - use if < 7 days old
- **License data**: See `/snowflake-customer-license-info` skill - uses cache if customer file exists with data (any age)
- **IS Usage data**: See `/snowflake-is-usage` skill - uses cache if < 7 days old and contains data rows
- **Support tickets**: See `/sf-integration-cases` skill - uses cache if < 24 hours old and has records

**Key Principle**: All skills validate cached files contain actual data before using them. Empty cache files trigger fresh queries automatically.

## File Organization

```
${PROJECT_DIR}/                   # Base directory (configurable via .env)
├── arr/                          # ARR and API usage data (CSV)
├── snowflake-data/               # License consumption data (CSV)
├── is-cases/                     # Support tickets (JSON)
├── sql/                          # SQL query files (modular)
│   ├── subsidiary_license_query.sql       # License consumption query
│   ├── is_usage_query_with_customer.sql   # IS usage with customer filter
│   └── is_usage_query_all.sql             # IS usage all customers
├── scripts/                      # Data extraction scripts
│   ├── subsidiary-license-info.sh         # Snowflake license query script
│   ├── sf-integration-cases.sh            # Salesforce case query script
│   ├── snowflake-is-usage.sh              # Snowflake API usage query script
│   └── fetch_salesforce_cases.py          # Python Salesforce client
├── .claude/
│   └── skills/                   # Claude Code skills
│       ├── customer-profile/     # Main customer profiling skill
│       ├── sf-integration-cases/ # Salesforce case fetching
│       ├── customer-in-news/     # Web search for customer news
│       ├── snowflake-customer-license-info/
│       └── snowflake-is-usage/
├── .env                          # Configuration (not in repo)
└── venv/                         # Python virtual environment
```

**Note**:
- All data storage paths are relative to ${PROJECT_DIR} configured in .env
- Scripts automatically expand ~ to user home directory
- SQL queries are maintained separately in `sql/` directory for better modularity and version control

## Data Sources Overview

This project integrates data from three primary sources:

1. **Snowflake** - Customer license consumption and usage data
   - Account: Configured in .env (SNOWFLAKE_ACCOUNT)
   - User: Configured in .env (SNOWFLAKE_USER)
   - License data: `prod_customer360.customerprofile.CustomerSubsidiaryLicenseProfile`
   - IS telemetry: `PROD_ELEMENTSERVICE.APPINS.INTEGRATIONSERVICE_TELEMETRY_STANDARDIZED`
   - See: `/snowflake-customer-license-info` and `/snowflake-is-usage` skills for details

2. **Salesforce** - Support cases and customer issues
   - Instance: Configured in .env (SALESFORCE_INSTANCE_URL)
   - Org: Configured in .env (SALESFORCE_ORG_ALIAS)
   - Case object with Integration Service product component filter
   - See: `/sf-integration-cases` skill for details

3. **ARR Data (Local CSV files)** - Annual Recurring Revenue and API usage metrics
   - Stored in: `${PROJECT_DIR}/arr/`
   - Format: Customer name, originator, API usage, ARR bucket, ticket count
   - See: `/customer-profile` skill for parsing logic

For detailed query specifications, table schemas, and data parsing patterns, refer to individual skill documentation.

## Environment Setup

This project uses a Python virtual environment for the Salesforce client:
```bash
source venv/bin/activate  # Activate venv
pip install simple-salesforce  # Required for fetch_salesforce_cases.py
```

The `.env` file contains Salesforce configuration but NOT credentials (SSO-based auth).

## Communication Style

- **Be precise and data-driven**: All responses must include specific data, metrics, and quantifiable information
- Avoid vague statements like "might", "could", "possibly" without data to support them
- When analyzing customer data, always cite specific numbers, percentages, and trends
- If data is unavailable, explicitly state what's missing rather than making general statements

---

**Note**: For detailed instructions on data parsing, output formatting, and business logic (e.g., IS API licensing rules), refer to individual skill documentation in the `.claude/skills/` directory.
