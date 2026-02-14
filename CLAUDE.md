# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Product Manager assistant toolkit for analyzing UiPath customer data. It aggregates information from multiple sources (Salesforce, Snowflake, ARR data) to generate comprehensive customer profiles and insights for account management and product decisions.

## Core Architecture

### Data Pipeline Flow

1. **Data Extraction Scripts** (bash shells)
   - `subsidiary-license-info.sh` - Queries Snowflake for customer license data
   - `sf-integration-cases.sh` - Queries Salesforce for support tickets
   - `snowflake-is-usage.sh` - Queries Snowflake for Integration Service API usage
   - All scripts save results to `~/Documents/uipath-integration-analyst/` subdirectories with timestamped filenames

2. **Data Storage Locations**
   - `~/Documents/uipath-integration-analyst/arr/` - ARR and API usage CSV files (cached weekly)
   - `~/Documents/uipath-integration-analyst/snowflake-data/` - License consumption CSV files (cached per customer)
   - `~/Documents/uipath-integration-analyst/is-cases/` - Support ticket JSON files (cached 24 hours)

3. **Claude Skills** (in `skills/` directory)
   - Each skill has a `skill.md` file defining its behavior
   - Skills are invoked with `/skill-name` syntax
   - Primary skill: `/customer-profile` - aggregates all data sources into actionable customer profile

### Authentication Requirements

**Snowflake**: Uses `snowsql` CLI with SSO via `--authenticator externalbrowser`
- Account: `UIPATH-UIPATH_OBSERVABILITY`
- Database: `prod_customer360.customerprofile`
- User must pass email as parameter (e.g., `anurag.krishna@uipath.com`)

**Salesforce**: Uses `sf` CLI (Salesforce CLI v2)
- Target org: `--target-org uipath`
- Instance: `https://uipath.my.salesforce.com`
- Python fallback script (`fetch_salesforce_cases.py`) supports multiple auth methods

## Key Commands

### Data Fetching

```bash
# Fetch customer license data from Snowflake
./subsidiary-license-info.sh "Customer Name" "your.email@uipath.com"

# Fetch support tickets for a customer (last 180 days)
./sf-integration-cases.sh 180 "Customer Name"

# Fetch Integration Service API usage (last 3 months)
# Query all customers
./snowflake-is-usage.sh "your.email@uipath.com"

# Query specific customer (checks cache first, queries if not found)
./snowflake-is-usage.sh "Customer Name" "your.email@uipath.com"
```

### Skills

```bash
# Generate comprehensive customer profile (includes web search automatically)
/customer-profile "Customer Name"

# Search for customer in news
/customer-in-news "Customer Name"

# Pull Salesforce Integration Service cases
/sf-integration-cases 180 "Customer Name"

# Query Snowflake license info
/snowflake-customer-license-info "Customer Name"

# Query Snowflake IS usage (checks cache for customer, queries if not found)
/snowflake-is-usage "Customer Name" your.email@uipath.com
/snowflake-is-usage your.email@uipath.com
```

## Critical Business Logic

### IS API Licensing Rules (IMPORTANT)

When analyzing Integration Service API usage, **IS Poller calls DO NOT count toward API licensing limits**. Only non-poller originators are billable:
- **Billable**: Robot, Studio, Studio Web, Connections, Maestro, Agents, Autopilot, etc.
- **NOT billable**: IS Pollers, IS Internal Chained Calls

When calculating API capacity utilization:
1. Sum all API calls by originator from ARR data
2. Exclude IS Poller volume from billable calculation
3. Compare billable calls against licensed API capacity
4. High poller usage (>90%) is an efficiency concern, NOT a licensing issue

### Data Parsing Patterns

**License CSV files** (from Snowflake):
- Skip first 2 lines (auth output), header starts at line 3
- Column 0: `MONTH` (format: YYYY-MM-DD)
- Column 49: `PRODUCTORSERVICENAME`
- Column 50: `PRODUCTORSERVICEQUANTITY`
- Always use latest month data (sort and take max date)
- Files may be large (6MB+, 6000+ rows) - use Python csv module for parsing

**ARR CSV files**:
- Format: `NAME,GROUPEDORIGINATOR,APIUSAGE,ARR,Ticket Count`
- API usage numbers appear to be annual totals
- Multiple rows per customer (one per originator type)

**Support Ticket JSON files**:
- Structure: `{result: {records: [...], totalSize: N}}`
- Each record has: `Status`, `Priority`, `Subject`, `Description`, `Solution__c`, etc.

### Caching Strategy

The customer-profile skill implements intelligent caching with data validation to minimize authentication flows:
- **ARR data**: Check `~/Documents/uipath-integration-analyst/arr/` - use if < 7 days old
- **License data**: Check `~/Documents/uipath-integration-analyst/snowflake-data/` - use if customer-specific file exists AND contains data rows (any age)
- **IS Usage data**: Check `~/Documents/uipath-integration-analyst/snowflake-data/` - use if customer-specific file exists AND < 7 days old AND contains data rows (pattern: `snowflake_is_usage_*<customer_name>*.csv`)
- **Support tickets**: Check `~/Documents/uipath-integration-analyst/is-cases/` - use if < 24 hours old AND contains records (totalSize > 0)

**Data Validation**: All skills validate cached files contain actual data before using them. Empty cache files (no data rows/records) trigger fresh queries automatically. This prevents false positives from empty result files caused by query failures or missing data.

## File Organization

```
uipath-integration-analyst/
├── arr/                          # ARR and API usage data (CSV)
├── snowflake-data/               # License consumption data (CSV)
├── is-cases/                     # Support tickets (JSON)
├── skills/                       # Claude skills
│   ├── customer-profile/         # Main customer profiling skill
│   ├── sf-integration-cases/     # Salesforce case fetching
│   ├── customer-in-news/         # Web search for customer news
│   ├── snowflake-customer-license-info/
│   └── snowflake-is-usage/
├── subsidiary-license-info.sh    # Snowflake license query
├── sf-integration-cases.sh       # Salesforce case query
├── snowflake-is-usage.sh         # Snowflake API usage query
├── fetch_salesforce_cases.py     # Python Salesforce client
├── .env                          # Configuration (not in repo)
└── venv/                         # Python virtual environment
```

## Data Sources

**Primary Table: Snowflake `prod_customer360.customerprofile.CustomerSubsidiaryLicenseProfile`**
- Contains license consumption by month, customer, subsidiary, product
- 63 columns including account metadata, license details, usage metrics (MAU/MEU)
- Query by `SUBSIDIARYNAME ILIKE '%Customer Name%'` (partial, case-insensitive matching)
- No record limit - retrieves all matching records for complete customer view

**Salesforce Cases**
- Filter: `Deployment_Type_Product_Component__c LIKE '%Integration Service%'`
- Date range: `CreatedDate = LAST_N_DAYS:N`
- Key fields: `Status`, `Priority`, `Subject`, `Description`, `Solution__c`

**Snowflake IS Usage Telemetry**
- Source: `PROD_ELEMENTSERVICE.APPINS.INTEGRATIONSERVICE_TELEMETRY_STANDARDIZED`
- Filter: `s.name ILIKE '%Customer Name%'` (partial, case-insensitive matching)
- Time range: Last 3 months
- Limited to 500 records per query

## Environment Setup

This project uses a Python virtual environment for the Salesforce client:
```bash
source venv/bin/activate  # Activate venv
pip install simple-salesforce  # Required for fetch_salesforce_cases.py
```

The `.env` file contains Salesforce configuration but NOT credentials (SSO-based auth).

## Output Format Standards

When generating customer profiles:
1. Use consolidated markdown tables with Category column
2. Include 4 sections: Account, Licenses, IS Usage, Support
3. Follow each section with **Insight:** commentary (1-2 sentences)
4. **Always perform web search** for customer context using `/customer-in-news` skill
5. Generate 3-5 data-driven Action Items prioritized by revenue impact and aligned with customer's strategic initiatives
6. Incorporate web search findings into recommendations
7. Keep use cases general (avoid connector-specific recommendations)
8. Include metadata footer with data source dates

 ## Communication Style

  - **Be precise and data-driven**: All responses must include specific data, metrics, and quantifiable information
  - Avoid vague statements like "might", "could", "possibly" without data to support them
  - When analyzing customer data, always cite specific numbers, percentages, and trends
  - If data is unavailable, explicitly state what's missing rather than making general statements
