---
name: customer-profile
description: Generate comprehensive customer profile with ARR, license consumption, usage data, support tickets, and action items
user-invocable: true
argument-hint: "[customer_name]"
allowed-tools: Bash, Read, Glob, Grep, Task, AskUserQuestion, Skill
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

1. **License Consumption & ARR Data**: Snowflake CustomerSubsidiaryLicenseProfile (includes CUSTOMERARRBUCKET, account owner, CSM, region)
2. **IS Usage**: Snowflake Integration Service telemetry (last 3 months)
3. **Support Tickets**: Salesforce cases (last 6 months)
4. **Customer News**: Web search for recent news and strategic initiatives

## Instructions

When this skill is invoked:

### 1. Get Customer Name
- If argument provided (e.g., `/customer-profile "PepsiCo, Inc"`), use that
- **If no argument provided**: Show usage help with sample queries and STOP. Display:
  ```
  ## Customer Profile (`/customer-profile`)

  Generate a comprehensive 360-degree customer profile with data-driven action items.

  ### Options
  | Argument | Required | Description |
  |----------|----------|-------------|
  | customer_name | Yes | Customer/subsidiary name |

  ### Sample Queries
  /customer-profile "PepsiCo, Inc"
  /customer-profile "Microsoft Corporation"
  /customer-profile "T-Mobile"
  /customer-profile "Acme Corp"

  ### Data Sources Aggregated
  1. License & ARR Data — Snowflake (products, quantities, ARR bucket, account owner, CSM)
  2. IS Usage — Snowflake (API calls by connector/originator, billable vs non-billable)
  3. Support Tickets — Salesforce (last 180 days, Integration Service cases)
  4. Customer News — Web search (recent news, strategic initiatives)

  ### Output Format
  - Customer Data table (Account, Licenses, IS Usage, Support, News)
  - Action Items table (3-5 prioritized items with specific data points)

  ### Notes
  - Profile generation takes 1-3 minutes (queries multiple data sources)
  - Uses cached data when available to minimize auth flows
  - Automatically performs web search for customer context
  ```
- Normalize name for searches (handle variations)

### 2. Data Collection Strategy

All data gathering is delegated to specialized skills that handle caching automatically:
- **License & ARR Data**: Handled by `/snowflake-customer-license-info` skill (uses cached if exists, includes CUSTOMERARRBUCKET, account owner, CSM, region)
- **IS Usage Data**: Handled by `/snowflake-usage integration-service` skill (7-day cache)
- **Support Tickets**: Handled by `/sf-cases` skill with "Integration Service" filter (24-hour cache)
- **Customer News**: Handled by `/customer-in-news` skill (real-time web search)

**IMPORTANT - Provide Status Updates:**
After launching all data collection tasks in parallel, provide an initial status message showing:
- ✅ Completed tasks (e.g., ARR data already parsed)
- 🔄 Running tasks (e.g., querying Snowflake, Salesforce, searching web)
- Brief summary of what data is being collected from each source

Then, while waiting for sub-skills to complete:
- Check for newly created data files every 15-20 seconds using `ls -lt` commands
- Update the user when each data source completes (e.g., "✅ License data retrieved")
- Show a running count of completed vs total tasks (e.g., "3/5 data sources complete")
- This keeps the user informed during the 1-3 minute data collection period

Example status update format:
```
**Data Collection Status for <Customer>:**

🔄 License & ARR Data - Querying Snowflake CustomerSubsidiaryLicenseProfile
🔄 IS Usage Data - Querying Snowflake telemetry
🔄 Support Tickets - Querying Salesforce (last 180 days)
🔄 Customer News - Searching web

[0/4 data sources complete - gathering data...]
```

### 3. Gather License Consumption & ARR Data
- Invoke the `/snowflake-customer-license-info` skill with customer name
- The skill will handle caching automatically (uses cached data if customer file exists)
- After skill completes, read the cached CSV file from `${PROJECT_DIR}/snowflake-data/`
- Extract from the CSV data:
  - **ARR bucket** (from CUSTOMERARRBUCKET column)
  - **Region** (from CUSTOMERSALESREGION column)
  - **Account Owner** (from CUSTOMERACCOUNTOWNER column)
  - **CSM Name** (from CUSTOMERCSMNAME column)
  - **Latest month license data**:
    - Total licenses by product type
    - Key products (Studio, StudioX, robots, DU units, AI units, API calls)
    - MAU/MEU numbers

### 4. Gather Integration Service Usage

**Invoke the skill:**
- Invoke the `/snowflake-usage integration-service` skill with customer name only
- The skill reads SNOWFLAKE_USER from .env file automatically
- The skill will handle caching automatically (7-day cache, fetches if expired or customer not found)
- After skill completes, read the cached CSV file from `${PROJECT_DIR}/snowflake-data/`

**Extract from data:**
- Total API calls
- Top originators (IS Pollers, Robot, etc.) with percentages
- Top connector keys by usage
- Identify primary integration pattern

**IMPORTANT - IS Licensing Rules:**
- **IS Poller calls do NOT count toward API licensing limits**
- Only non-poller calls (Robot, Studio, Connections, etc.) count toward licensed API capacity
- When assessing API overages, exclude IS Poller volume from licensed capacity calculations
- High poller usage (>90%) is an efficiency concern, NOT a licensing concern

### 5. Gather Support Tickets (Last 6 Months)
- Invoke the `/sf-cases` skill with 180 days, customer name, and "Integration Service" product filter
  - Example: `/sf-cases 180 "PepsiCo, Inc" "Integration Service"`
- The skill will handle caching automatically (24-hour cache, fetches if expired or customer not found)
- After skill completes, read the cached JSON file from `${PROJECT_DIR}/sf-cases/`
- Extract:
  - Total tickets
  - Open vs closed tickets
  - Priority distribution
  - Common themes from ticket subjects

### 6. Research Customer Context (Always Required)

**Invoke the customer news skill:**
- Invoke the `/customer-in-news` skill with customer name using the Skill tool
- The skill will perform web search for recent news about the customer
- Look for: strategic initiatives, partnerships, digital transformation efforts, industry trends
- Incorporate findings into recommendations and action items

### 7. Format Output

**ALWAYS present data in TWO ASCII tables with box-drawing borders** - this is the ONLY acceptable output format:
1. **Customer Data table** with Category/Data/Insights columns (5 rows)
2. **Action Items table** with Priority/Category/Data Point/Action columns (3-5 rows)

**CRITICAL FORMATTING REQUIREMENTS:**
- Use ASCII box-drawing characters: ┌─┬─┐ │ ├─┼─┤ └─┴─┘
- Tables MUST be wrapped in code blocks with triple backticks
- DO NOT use markdown tables (| --- |) - ONLY use ASCII tables with visible borders
- DO NOT use any other format (no bullet lists, no paragraphs, no alternative layouts)

```
# Customer Profile: <Customer Name>

## Customer Data

```
┌────────────────────┬─────────────────────────────────────────────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────────────────┐
│ Category           │ Data                                                                            │ Insights                                                                         │
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ Account            │ Customer Name: <Name> • Primary Use Case: <Use case> • ARR Bucket: <Bucket> • │ <1-2 sentences about customer profile, maturity, deployment scale>               │
│                    │ Region: <Region> • Account Owner: <Name> • CSM: <Name>                         │                                                                                  │
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ Licenses           │ API Calls (licensed): <qty> • DU Units: <qty> • AI Units: <qty> • Task         │ <1-2 sentences about license mix, deployment strategy, key products>             │
│ (Q1 2026)          │ Capture: <qty> • Assistant: <qty> • Agentic Units: <qty> • Action Center:      │                                                                                  │
│                    │ <qty> • Data Service: <qty> • Studio: <qty> • StudioX: <qty> • Apps: <qty> •   │                                                                                  │
│                    │ Test Robot: <qty> • [other products...]                                         │                                                                                  │
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ IS Usage (3mo)     │ Total API Calls: <qty> • Billable API Calls: <qty non-poller> • Licensed API   │ <1-2 sentences about usage patterns, optimization opportunities. IMPORTANT: Note │
│                    │ Capacity: <qty> • Capacity Utilization: <X>x over/under licensed capacity •    │ that IS Poller calls don't count toward licensing - only assess overage for     │
│                    │ Primary Originator: <Type> (<pct>%) • Top Connector: <Name> (<pct>%) •         │ non-poller calls vs licensed capacity>                                          │
│                    │ Secondary Connectors: <Names> • Integration Pattern: <Pattern> • IS Pollers:    │                                                                                  │
│                    │ <pct>% (non-billable)                                                           │                                                                                  │
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ Support            │ Total Tickets: <count> • Open Tickets: <count> • Priority Distribution:        │ <1-2 sentences about support health, common issues, customer experience>         │
│ (180 days)         │ <summary> • Top Issue Theme: <theme>                                            │                                                                                  │
├────────────────────┼─────────────────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ Customer News      │ <Recent news headlines with key metrics> • <Strategic initiatives> •            │ <1-2 sentences about customer strategic direction and alignment opportunities> • │
│                    │ <Financial/operational updates>                                                 │ Sources: [Source 1](URL1), [Source 2](URL2), [Source 3](URL3)                   │
└────────────────────┴─────────────────────────────────────────────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────────────────┘
```

## Action Items

```
┌──────────┬─────────────────────────┬────────────────────────────────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────────────────┐
│ Priority │ Category                │ Data Point                                                         │ Action                                                                           │
├──────────┼─────────────────────────┼────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 1        │ <Category>              │ <Specific metric or observation>                                   │ <Detailed action with timeline and stakeholders>                                 │
├──────────┼─────────────────────────┼────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 2        │ <Category>              │ <Specific metric or observation>                                   │ <Detailed action with timeline and stakeholders>                                 │
├──────────┼─────────────────────────┼────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 3        │ <Category>              │ <Specific metric or observation>                                   │ <Detailed action with timeline and stakeholders>                                 │
├──────────┼─────────────────────────┼────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 4        │ <Category>              │ <Specific metric or observation>                                   │ <Detailed action with timeline and stakeholders>                                 │
├──────────┼─────────────────────────┼────────────────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────┤
│ 5        │ <Category>              │ <Specific metric or observation>                                   │ <Detailed action with timeline and stakeholders>                                 │
└──────────┴─────────────────────────┴────────────────────────────────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────────────────┘
```

---
*Profile generated: <Timestamp> | Data sources: ARR (<file_date>), Licenses (<file_date>), IS Usage (<date_range>), Support Tickets (<date_range>)*
```

**Formatting Guidelines (MANDATORY):**
- **ALWAYS use ASCII tables with box-drawing borders** - this is the only acceptable format:
  1. **Customer Data table**: Category │ Data │ Insights columns (3 columns, 5 rows)
  2. **Action Items table**: Priority │ Category │ Data Point │ Action columns (4 columns, 3-5 rows)
- **Use box-drawing characters**: ┌─┬─┐ │ ├─┼─┤ └─┴─┘
- **Wrap tables in code blocks** using triple backticks (```)
- **DO NOT use markdown tables** (| --- |) - they don't render with visible borders
- **Never use alternative formats** (no paragraphs, no bullet lists, no other layouts)
- In the Data column, separate each metric with bullet point (•) and space - do NOT use line breaks
- Keep license data comprehensive but concise - show top 10-15 products by quantity
- For IS Usage, always calculate and display capacity utilization (billable calls vs licensed capacity)
- For Customer News, include 2-3 key headlines with metrics, then provide insight with source links
- Action items should be 3-5 items maximum, prioritized by revenue impact
- Always include source citations for customer news at the end of insights
- Text within cells should wrap naturally - use multiple lines within a cell if needed to keep columns readable

### 8. Generate Action Items

Action items should be derived from data patterns AND web search findings. Limit to 3-5 high-impact items:

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
2. Alignment with customer's strategic initiatives (from web search)
3. Customer experience (open tickets, authentication issues)
4. Optimization opportunities (efficiency gains, cost reduction)

**Incorporate web search findings:**
- If customer is pursuing digital transformation → Recommend aligning automation roadmap with their strategic goals
- If customer in growth phase → Position expansion opportunities and scalability features
- If customer facing challenges → Proactive support and optimization recommendations

## Use Case Detection

Infer primary use case from usage patterns (KEEP IT GENERAL - avoid specific connector names):

- **Document Processing**: High DU Units consumption, document-related API activity
- **Email & Communication Automation**: High communication-related connector usage patterns
- **Data Integration & Synchronization**: High database and enterprise system integration activity
- **API Orchestration & Event-Driven Automation**: High IS Pollers activity, diverse connector portfolio
- **Development & Testing**: High Studio usage, test automation patterns
- **Attended Automation**: High Assistant licenses, moderate robot usage for desktop workflows
- **Hybrid Automation**: Balanced mix of attended and unattended robots with integration services

## Example Usage

```bash
/customer-profile "PepsiCo, Inc"
/customer-profile "Microsoft Corporation"
/customer-profile "Acme Corp"
```

## Error Handling

- If no Snowflake access: Use "Authentication required" for license/ARR data
- If customer not found in Snowflake: Note "License and ARR data not available"
- If customer not found in any system: Provide partial profile with available data
- Always provide action items even with incomplete data

## Data Parsing Patterns

### License CSV Files (includes ARR data)
- Skip first 2 lines (auth output), header starts at line 3
- Key columns for licenses: `MONTH` (YYYY-MM-DD), `PRODUCTORSERVICENAME`, `PRODUCTORSERVICEQUANTITY`
- Key columns for ARR & account info: `CUSTOMERARRBUCKET`, `CUSTOMERSALESREGION`, `CUSTOMERACCOUNTOWNER`, `CUSTOMERCSMNAME`
- Always use latest month data (sort by MONTH and take max date)
- Files may be large (1-6MB, 2000-6000 rows) - use Python csv module for parsing
- Use `python3` to parse and aggregate by product
- Extract ARR bucket and account metadata from any row (same values across all rows for a customer)

### IS Usage CSV Files
- Skip first 2 lines (auth output), header starts at line 3
- Columns: `NAME`, `CONNECTORKEY`, `GROUPEDORIGINATOR`, `APIUSAGE`
- Aggregate by originator to calculate billable vs non-billable usage
- **Calculate billable calls**: Total API calls minus IS Pollers and IS Internal Chained Calls

### Support Ticket JSON Files
- Structure: `{result: {records: [...], totalSize: N}}`
- Each record has: `Status`, `Priority`, `Subject`, `Description`, `Solution__c`, `Account.Name`, `Owner.Name`
- Check `result.totalSize` to validate data exists before parsing

## Notes

- **Configuration**: Requires PROJECT_DIR, SNOWFLAKE_USER, SNOWFLAKE_ACCOUNT in .env file
- **Caching behavior**: Automatically uses cached data when available to reduce API calls
  - License & ARR data: Uses cached data if customer file exists (any age), fetches if customer not found
  - IS Usage data: Uses cached data if < 7 days old, fetches from Snowflake if older or customer not found
  - Support tickets: Uses cached data if < 24 hours old, fetches if older or customer not found
  - **Stale file cleanup**: Each sub-skill automatically deletes older cache files for the same customer after a successful fresh pull (only the latest file is kept)
- **IS API Licensing (CRITICAL)**: IS Poller calls do NOT count toward licensed API capacity. Only non-poller originators (Robot, Studio, Connections, Studio Web, etc.) are billable. Always exclude poller volume when assessing API overages.
- **Web search (REQUIRED)**: Always perform web search to gather customer context and incorporate findings into recommendations
- Requires authentication to both Snowflake and Salesforce (only when fetching new data)
- Profile generation may take 2-5 minutes when parsing large license files locally
- Profile generation with fresh data fetch may take longer if API calls are required
- Action items should be specific, data-driven, aligned with customer strategy, and prioritized by revenue impact
