---
name: customer-in-news
description: Search the web for top 3 recent news articles about a customer and provide summaries
user-invocable: true
argument-hint: "[customer_name]"
allowed-tools: WebSearch, WebFetch, AskUserQuestion
---

# Customer in News Skill

Search the web to find and summarize the top 3 most recent news articles about a specified customer/company.

## Purpose

This skill helps you quickly understand what's happening with a customer by:
- Finding the most recent news coverage
- Summarizing key developments
- Providing context for customer conversations
- Identifying potential risks or opportunities

## Instructions

When this skill is invoked:

1. **Get customer name**:
   - If an argument is provided (e.g., `/customer-in-news PepsiCo`), use that as the customer name
   - If no argument is provided, ask the user for the customer name using AskUserQuestion

2. **Search for recent news**:
   - Use WebSearch with a query like: `"<customer_name>" news 2026`
   - Focus on recent, relevant news articles
   - Prioritize: press releases, industry publications, major news outlets

3. **Analyze and collate**:
   - Identify the top 3 most relevant and recent news items
   - Extract key information from all 3 articles
   - Synthesize into a cohesive narrative

4. **Format the output**:
   ```
   ## <Customer Name> - Recent News Summary

   [3-line maximum summary that collates all major news items into a concise narrative. Each sentence should cover one major news item or theme. Connect related points using conjunctions like "while," "and," or "as." Focus on concrete facts: numbers, partnerships, strategic moves, financial metrics, or operational changes.]

   ### Sources:
   - [Source 1 Title](URL1)
   - [Source 2 Title](URL2)
   - [Source 3 Title](URL3)
   - [Additional relevant sources...]
   ```

   **Example format:**
   ```
   ## PepsiCo - Recent News Summary

   PepsiCo is cutting snack prices by up to 15% on major brands (Lay's, Doritos, Cheetos) to drive affordability and volume growth, while simultaneously announcing a 4% dividend increase reflecting confidence in its 2026 outlook (2-4% organic revenue growth, 4-6% EPS growth). The company unveiled an industry-first AI collaboration with Siemens and NVIDIA at CES 2026, deploying digital twin technology that has already achieved 20% throughput improvements in manufacturing operations.

   ### Sources:
   - [PepsiCo makes iconic snacks more affordable](https://...)
   - [PepsiCo Declares Quarterly Dividend](https://...)
   - [AI Collaboration with Siemens and NVIDIA](https://...)
   ```

5. **Handle edge cases**:
   - If no recent news found, inform the user and suggest alternative search terms
   - If customer name is ambiguous, clarify with the user
   - If only 1-2 relevant articles found, present what's available

## Search Strategy

**Good search queries:**
- `"Company Name" news 2026`
- `"Company Name" announcement 2026`
- `"Company Name" press release 2026`
- `"Company Name" earnings OR acquisition OR partnership 2026`

**Filter criteria:**
- Prioritize articles from the last 30 days
- Prefer reputable news sources
- Focus on business-relevant news (not opinion pieces or rumors)

## Example Usage

```bash
/customer-in-news "PepsiCo"
/customer-in-news "Microsoft Corporation"
/customer-in-news "Acme Corp"
/customer-in-news Walmart
```

## Output Guidelines

- **Maximum 3 lines** (3 sentences) for the entire summary
- **Collate all news items** into a cohesive narrative (don't list separately)
- **Include specific numbers** and metrics when available (percentages, dollar amounts, dates)
- **Connect related points** using conjunctions for smooth reading
- **Focus on facts**: strategic moves, partnerships, financial metrics, operational changes
- **Always cite all sources** with URLs in the Sources section
- Present information neutrally without editorial commentary
- If news is negative (layoffs, lawsuits, etc.), present it factually

## Notes

- Uses real-time web search (current as of search date)
- Limited to English language results
- News availability depends on customer size and media coverage
- Smaller companies may have limited or no recent news coverage
- Always include a "Sources:" section at the end with all URLs
