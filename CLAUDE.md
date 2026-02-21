# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Product Manager assistant toolkit for analyzing UiPath customer data. It aggregates information from multiple sources (Salesforce, Snowflake, ARR data) to generate comprehensive customer profiles and insights for account management and product decisions.

## Core Architecture

### Data Pipeline Flow

1. **Data Extraction Scripts** (bash shells in `scripts/` directory)
   - `scripts/subsidiary-license-info.sh` - Queries Snowflake for customer license data
   - `scripts/sf-cases.sh` - Queries Salesforce for support cases (with optional customer/product filters)
   - `scripts/snowflake-usage.sh` - Generic Snowflake usage query tool (modules in `snowflake-modules.conf`)
   - All scripts save results to `~/Documents/uipath-integration-analyst/` subdirectories with timestamped filenames

2. **Data Storage Locations**
   - `~/Documents/uipath-integration-analyst/arr/` - ARR and API usage CSV files (cached weekly)
   - `~/Documents/uipath-integration-analyst/snowflake-data/` - License consumption CSV files (cached per customer)
   - `~/Documents/uipath-integration-analyst/sf-cases/` - Support ticket JSON files (cached 24 hours)

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

## Skills Usage

```bash
# Generate comprehensive customer profile (includes web search automatically)
/customer-profile "Customer Name"

# Search for customer in news
/customer-in-news "Customer Name"

# Pull Salesforce cases (with optional customer and product filters)
/sf-cases 180 "Customer Name"                        # All products for customer
/sf-cases 180 "Customer Name" "Integration Service"  # IS cases only

# Query Snowflake license info (username from .env)
/snowflake-customer-license-info "Customer Name"

# Query Snowflake usage data (extensible via snowflake-modules.conf)
/snowflake-usage integration-service "Customer Name"
/snowflake-usage is "Customer Name"    # Short alias
/snowflake-usage                       # Show available modules
```

## Caching Strategy

All data-fetching skills implement intelligent caching with data validation to minimize authentication flows. For detailed caching logic and data parsing patterns, refer to individual skill documentation:

- **ARR data**: Manual cache management - use if < 7 days old
- **License data**: See `/snowflake-customer-license-info` skill - uses cache if customer file exists with data (any age)
- **IS Usage data**: See `/snowflake-usage` skill - per-module cache TTL (IS: 7 days), validated before use
- **Support tickets**: See `/sf-cases` skill - uses cache if < 24 hours old and has records

**Key Principle**: All skills validate cached files contain actual data before using them. Empty cache files trigger fresh queries automatically.

**Stale File Cleanup**: When cache expires and fresh data is pulled successfully, each skill automatically deletes older cache files for the same customer/query combination. Only the latest file is kept. Cleanup only runs after a successful fresh pull — on error, stale files are preserved as fallback.

## File Organization

```
${PROJECT_DIR}/                   # Base directory (configurable via .env)
├── snowflake-data/               # License consumption & ARR data (CSV)
├── sf-cases/                     # Support tickets (JSON)
├── sql/                          # SQL query files (modular)
│   ├── subsidiary_license_query.sql       # License consumption query
│   ├── is_usage_query_with_customer.sql   # IS usage with customer filter
│   └── is_usage_query_all.sql             # IS usage all customers
├── scripts/                      # Data extraction scripts
│   ├── subsidiary-license-info.sh         # Snowflake license query script
│   ├── sf-cases.sh                        # Salesforce case query script
│   └── snowflake-usage.sh                 # Generic Snowflake usage query tool
├── .claude/
│   └── skills/                   # Claude Code skills
│       ├── customer-profile/     # Main customer profiling skill
│       ├── sf-cases/             # Salesforce case fetching
│       ├── customer-in-news/     # Web search for customer news
│       ├── snowflake-customer-license-info/
│       └── snowflake-usage/      # Extensible Snowflake usage queries
└── .env                          # Configuration (not in repo)
```

**Note**:
- All data storage paths are relative to ${PROJECT_DIR} configured in .env
- Scripts automatically expand ~ to user home directory
- SQL queries are maintained separately in `sql/` directory for better modularity and version control

## Data Sources Overview

This project integrates data from two primary sources:

1. **Snowflake** - Customer license consumption, ARR, and usage data
   - Account: Configured in .env (SNOWFLAKE_ACCOUNT)
   - User: Configured in .env (SNOWFLAKE_USER)
   - **License & ARR data**: `prod_customer360.customerprofile.CustomerSubsidiaryLicenseProfile`
     - Includes: CUSTOMERARRBUCKET, CUSTOMERSALESREGION, CUSTOMERACCOUNTOWNER, CUSTOMERCSMNAME
     - Provides: License quantities by product, account metadata, ARR bucket
   - **IS telemetry**: `PROD_ELEMENTSERVICE.APPINS.INTEGRATIONSERVICE_TELEMETRY_STANDARDIZED`
     - Provides: API usage by connector, originator, and customer
   - See: `/snowflake-customer-license-info` and `/snowflake-usage` skills for details

2. **Salesforce** - Support cases and customer issues
   - Instance: Configured in .env (SALESFORCE_INSTANCE_URL)
   - Org: Configured in .env (SALESFORCE_ORG_ALIAS)
   - Case object with optional product component filter (e.g., Integration Service)
   - See: `/sf-cases` skill for details

For detailed query specifications, table schemas, and data parsing patterns, refer to individual skill documentation.

## Environment Setup

The `.env` file contains Salesforce and Snowflake configuration but NOT credentials (SSO-based auth).

## Communication Style

- **Be precise and data-driven**: All responses must include specific data, metrics, and quantifiable information
- Avoid vague statements like "might", "could", "possibly" without data to support them
- When analyzing customer data, always cite specific numbers, percentages, and trends
- If data is unavailable, explicitly state what's missing rather than making general statements

---

**Note**: For detailed instructions on data parsing, output formatting, and business logic (e.g., IS API licensing rules), refer to individual skill documentation in the `.claude/skills/` directory.
