---
name: customer-profile
description: Generate comprehensive customer profile with ARR, license consumption, usage data, support tickets, and action items
user-invocable: true
argument-hint: "[customer_name]"
allowed-tools: Bash, Read, Glob, Grep, Task, AskUserQuestion
---

# Customer Profile Skill

Generate a comprehensive customer profile combining ARR data, license consumption, Integration Service usage, support tickets, and actionable recommendations for Product Managers.

## Purpose

This skill provides a 360-degree view of a customer by aggregating:
- ARR and account information
- License consumption and utilization
- Integration Service API usage patterns
- Recent support ticket activity
- Data-driven action items for Product Managers

## Data Sources

1. **ARR Data**: `~/Documents/pm-assistant/arr/` folder (Excel/CSV files)
2. **License Consumption**: Snowflake CustomerSubsidiaryLicenseProfile
3. **IS Usage**: Snowflake Integration Service telemetry (last 3 months)
4. **Support Tickets**: Salesforce cases (last 6 months)

## Instructions

When this skill is invoked:

### 1. Get Customer Name
- If argument provided (e.g., `/customer-profile "PepsiCo, Inc"`), use that
- If not provided, ask user using AskUserQuestion
- Normalize name for searches (handle variations)

### 2. Check for Cached Data (Important!)

Before fetching new data, check local cache to avoid unnecessary API calls:

**ARR/IS Usage Data:**
- Check `~/Documents/pm-assistant/arr/` for CSV files
- Use `stat` or `ls -l` to get file modification date
- If file modified within last 7 days, use cached data
- If older than 7 days or not found, data will be fetched from source

**License Consumption Data:**
- Check `~/Documents/pm-assistant/snowflake-data/` for files matching pattern: `subsidiary_license_*<customer_name_normalized>*.csv`
- Normalize customer name (lowercase, replace spaces/commas with underscores)
- If customer-specific file exists (regardless of age), use it
- Only fetch if no file exists for this customer

**Support Tickets:**
- Check `~/Documents/pm-assistant/is-cases/` for files matching pattern: `sf_integration_cases_*<customer_name_normalized>*.json`
- Use `stat` or `ls -l` to get file modification date
- If file modified within last 24 hours, use cached data
- If older than 24 hours or not found, fetch new data

### 3. Gather ARR Data
- Search for ARR data in `~/Documents/pm-assistant/arr/` folder
- Look for most recent CSV file (check modification date)
- Search for customer name in the file using Grep
- Extract: ARR bucket, region, account owner, CSM, ticket count

### 4. Gather License Consumption Data
- First check cache (see step 2)
- If not cached, execute: `bash ~/Documents/pm-assistant/subsidiary-license-info.sh "<customer_name>" "your.email@company.com"`
- Parse the output CSV from `~/Documents/pm-assistant/snowflake-data/`
- Extract latest month data:
  - Total licenses by product type
  - Key products (Studio, StudioX, robots, DU units, AI units, API calls)
  - MAU/MEU numbers

### 5. Gather Integration Service Usage
- Check ARR CSV file for IS usage by originator (already contains this data)
- Extract:
  - Total API calls
  - Top originators (IS Pollers, Robot, etc.) with percentages
  - Identify primary integration pattern

**IMPORTANT - IS Licensing Rules:**
- **IS Poller calls do NOT count toward API licensing limits**
- Only non-poller calls (Robot, Studio, Connections, etc.) count toward licensed API capacity
- When assessing API overages, exclude IS Poller volume from licensed capacity calculations
- High poller usage (>90%) is an efficiency concern, NOT a licensing concern

### 6. Gather Support Tickets (Last 6 Months)
- First check cache (see step 2)
- If not cached, execute: `bash ~/Documents/pm-assistant/sf-integration-cases.sh 180 "<customer_name>"`
- Parse the output JSON from `~/Documents/pm-assistant/is-cases/`
- Extract:
  - Total tickets
  - Open vs closed tickets
  - Priority distribution
  - Common themes from ticket subjects

### 7. Format Output

Present data in a single consolidated table with insights after each section, followed by action items:

```markdown
# Customer Profile: <Customer Name>

| Category | Metric | Value |
|----------|--------|-------|
| **Account** | Customer Name | <Name> |
| | Primary Use Case | <Derived from usage patterns> |
| | ARR Bucket | <Bucket> (e.g., $3M-5M) |
| | Region | <Region> |
| | Account Owner | <Name> |
| | CSM | <Name> |

**Account Insight:** <1-2 sentences about customer profile, maturity, deployment scale>

| **Licenses (Q)** | Studio | <qty> |
| | StudioX | <qty> |
| | Assistant | <qty> |
| | Robot Units | <qty> |
| | DU Units | <qty> |
| | AI Units | <qty> |
| | API Calls (licensed) | <qty> |

**License Insight:** <1-2 sentences about license mix, deployment strategy, key products>

| **IS Usage (3mo)** | Total API Calls | <qty> (e.g., 3.4B) |
| | Primary Originator | <Type> (<pct>%, e.g., IS Pollers 98.9%) |
| | Billable API Calls | <qty non-poller calls> |
| | Licensed API Capacity | <qty from license data> |
| | Integration Pattern | <Pattern> (e.g., Polling-based) |

**IS Usage Insight:** <1-2 sentences about usage patterns, optimization opportunities. IMPORTANT: Note that IS Poller calls don't count toward licensing - only assess overage for non-poller calls vs licensed capacity>

| **Support (6mo)** | Total Tickets | <count> |
| | Open Tickets | <count> |
| | Priority Distribution | <summary> (e.g., 11 Medium) |
| | Top Issue Theme | <theme> (<count> tickets) |

**Support Insight:** <1-2 sentences about support health, common issues, customer experience>

---

## Action Items

1. **<Category>**: <Specific action based on data>
   - *Data point*: <Supporting metric>
   - *Action*: <What to do>

2. **<Category>**: <Specific action based on data>
   - *Data point*: <Supporting metric>
   - *Action*: <What to do>

3. **<Category>**: <Specific action based on data>
   - *Data point*: <Supporting metric>
   - *Action*: <What to do>

---
*Profile generated: <Timestamp> | Data sources: ARR (<file_date>), Licenses (<file_date>), Tickets (<file_date>)*
```

**Formatting Guidelines:**
- Merge related metrics into single table with Category column
- Keep licenses concise - only show key products with quantities
- For IS Usage, focus on top 2 originators and overall pattern
- For Support, summarize themes rather than listing individual tickets
- Action items should be 3-5 items maximum, prioritized by impact

### 8. Generate Action Items

Action items should be derived from data patterns. Limit to 3-5 high-impact items:

**Data Pattern → Action Mapping:**

- **Excessive IS Poller usage (>90%)** → Recommend polling-to-webhook migration audit for efficiency (NOTE: Poller calls don't count toward licensing, so this is optimization-focused, not compliance)
- **Non-poller API usage exceeds licensed capacity** → Urgent capacity planning discussion / true-up (CRITICAL: Only count Robot, Studio, Connections, and other non-poller originators against licensed API capacity)
- **Multiple connector authentication tickets** → Proactive Azure AD/OAuth configuration review
- **Low license utilization (<30% MAU/MEU)** → Adoption program or downsell risk mitigation
- **Multiple open/high-priority tickets** → Schedule health check call and escalation review
- **High robot units with low runtime** → ROI optimization opportunity
- **Large StudioX deployment** → Citizen developer enablement and governance check
- **No recent support tickets + high usage** → Customer health signal - schedule QBR
- **Growing usage trend** → Upsell/expansion opportunity

Prioritize action items by:
1. Revenue impact (overages, downsell risk, upsell opportunities)
2. Customer experience (open tickets, authentication issues)
3. Optimization opportunities (efficiency gains, cost reduction)

## Use Case Detection

Infer primary use case from usage patterns:

- **Document Processing**: High DU Units consumption
- **Email Automation**: High Outlook/Gmail connector usage
- **Data Integration**: High Snowflake/Salesforce/database connector usage
- **API Orchestration**: High IS Pollers, diverse connectors
- **Development/Testing**: High Studio/Test Robot usage
- **Attended Automation**: High Assistant licenses, moderate robot usage

## Example Usage

```bash
/customer-profile "PepsiCo, Inc"
/customer-profile "Microsoft Corporation"
/customer-profile "Acme Corp"
```

## Error Handling

- If ARR data not found: Note "ARR data not available"
- If no Snowflake access: Use "Authentication required"
- If customer not found in any system: Provide partial profile with available data
- Always provide action items even with incomplete data

## Notes

- **Caching behavior**: Automatically uses cached data when available to reduce API calls
  - ARR/IS Usage: Uses cached data if < 7 days old
  - License data: Uses cached data if customer file exists
  - Support tickets: Uses cached data if < 24 hours old
- **IS API Licensing (CRITICAL)**: IS Poller calls do NOT count toward licensed API capacity. Only non-poller originators (Robot, Studio, Connections, Studio Web, etc.) are billable. Always exclude poller volume when assessing API overages.
- Requires authentication to both Snowflake and Salesforce (only when fetching new data)
- Profile generation may take 2-5 minutes when parsing large license files locally
- Profile generation with fresh data fetch may take longer if API calls are required
- Action items should be specific, data-driven, and prioritized by revenue impact
