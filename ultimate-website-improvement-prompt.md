
# The Ultimate Website Improvement Prompt (Strict, Actionable, and File-Referenced) To Increase Income from AdSense

You are tasked with improving a website so as to geneate more total revenue from Google AdSense ads. This means getting more visitors with high purchase intent via good SEO on related topics. Your goal is to maximize accuracy, usability, and helpfulness for all users. You must follow these explicit, non-negotiable instructions, referencing and updating the project’s `.private` and `.github` files as required. Do not rely on generic best practices—be precise, strict, and thorough.

## 1. General Improvement Instructions
- Review every HTML file for clarity, accuracy, and completeness. Use the `.private/fact-check-instructions.md` as your fact-checking and editorial baseline.
- Ensure all information is up-to-date, well-organized, and easy to understand. If you find outdated or unclear content, rewrite it for clarity and accuracy.
- Enhance user experience by improving navigation, accessibility, and visual appeal. Reference `.github/copilot-instructions.md` for template and navigation update rules.
- Remove redundant, outdated, or irrelevant content. Document all removals in `.private/CHANGELOG.md` and, if relevant, in `.private/errors.md` with date/time and reason.
- Check and fix all broken links, images, or interactive elements. Log any persistent issues in `.private/errors.md`.
- Ensure all text is free of spelling, grammar, and factual errors. Use the `.private/facts.xml` (create if missing) to log and verify all factual claims.
- Make sure the website is mobile-friendly and loads quickly. If not, document specific issues and proposed fixes in `.private/last-job.md`.

## 2. Fact-Checking and Data Validation
- For every fact, statistic, or claim, extract and log it in `.private/facts.xml` using the XML structure and BNF grammar in `.private/fact-check-instructions.md`.
- Independently verify every fact using Tavily Search and Extract, Google, and authoritative sources. Update the `status`, `citation_url`, and `date_checked` fields in `facts.xml`.
- If a location, business, or service is mentioned, confirm it is still open and operating as described. If closed, update the website and log the change in `.private/CHANGELOG.md`.
- Update all information about hours, contact details, or services to reflect the latest available data. If you cannot verify, mark the fact as `unverified` in `facts.xml` and flag it in `.private/errors.md`.
- For every new or changed fact, add a note in `.private/last-job.md` describing what was checked, the outcome, and next steps.

## 3. Deduplication and Generalization
- If multiple sections or pages repeat similar information, consolidate them for clarity and brevity. Document all consolidations in `.private/CHANGELOG.md`.
- Generalize specific fixes into broader rules. For example, if you fix a closed business, add a rule in `.github/copilot-instructions.md` to always check business status before publishing.
- Create or update reusable templates or guidelines for common content types (e.g., location listings, event announcements) in `.github/copilot-instructions.md`.

## 4. Error Prevention and Quality Assurance
- Anticipate common errors (e.g., outdated hours, closed locations, incorrect contact info) and implement checks to prevent them. Add reminders or automated checks where possible, and document them in `.github/copilot-instructions.md`.
- For time-sensitive information, add review reminders in `.private/last-job.md` and update the relevant HTML or template files to include review dates.
- Where possible, automate data updates or integrate with authoritative sources. Document any automation scripts or processes in `.private/` and reference them in `.github/copilot-instructions.md`.
- After every major edit, verify all changes by reviewing the affected files. Log the verification in `.private/last-job.md` and summarize in `.private/CHANGELOG.md`.

## 5. User-Focused Enhancements
- Solicit and incorporate user feedback to identify pain points and areas for improvement. If feedback is received, log it in `.private/feedback.md` and document actions taken in `.private/CHANGELOG.md`.
- Ensure all content is inclusive, accessible, and respectful of diverse audiences. Reference `.github/copilot-instructions.md` for accessibility and inclusivity guidelines.
- Provide clear calls to action and easy ways for users to report errors or suggest improvements. Add or update contact forms, feedback links, or email addresses as needed, and log changes in `.private/CHANGELOG.md`.
- Integrate new or improved pages into the site via relevant hyperlinks, navigation, or footers, as specified in `.github/copilot-instructions.md`.

## 6. Research, Logging, and Documentation
- Use MCP servers, Tavily, and Google Analytics/Search Console for all research. Store all research results and transcripts in `.private/` with meaningful filenames.
- Before starting any job, review `.private/last-job.md` and `.private/CHANGELOG.md` to understand previous work and avoid duplication.
- Log all activities, errors, and completed steps in `.private/last-job.md` and `.private/CHANGELOG.md`. When a job is finished, archive the old last-job file with a date/time stamp.
- If you encounter a task you cannot complete, document the reason and next steps in `.private/tasks-cannot-be-completed.md`.

## 7. Quality Control and Continuous Improvement
- Always check your work—never assume edits or commands executed correctly. Review files to confirm expected changes occurred.
- Update `.github/copilot-instructions.md` with new learnings, rules, or corrections as you go.
- Constantly strive to make the website more informative, accurate, and superior to its previous version, as a reliable resource for travelers.

## 8. Localization, Language, and Style
- Always write in English but use local terms and currency formats as appropriate (see `.github/copilot-instructions.md`).
- Use full, rich prose suitable for a travel guide. Break up text with tips, recommendations, lists, and links, but ensure paragraphs are well-written and accessible.
- For every recommended place, dish, or activity, research and provide specifics (names, addresses, prices, hours) and store the research in `.private/` for future reference.


## 9. Monetization (AdSense Only)
- Monetize the website exclusively using Google AdSense AutoAds. Do NOT add individual AdSense units or any affiliate links. Ensure the AutoAds script is present in the site header as specified in `.github/copilot-instructions.md`.
- Prioritize content and page creation that targets high-CPC (cost-per-click) keywords and topics, as identified in `.private/detailed-action-plan-*.md` and through research using KeywordsEverywhere and Tavily.
- Integrate new high-value pages into the site structure (navigation, footers, internal links) to maximize visibility and revenue potential. Document all monetization-related changes in `.private/CHANGELOG.md`.
- Regularly review AdSense performance using Google Analytics and Search Console data. Store reports and insights in `.private/google-search-console-reports/` and reference them in `.private/last-job.md` for ongoing optimization.

## 10. SEO (Search Engine Optimization)
- Optimize every page for search engines by following the latest SEO best practices, as outlined in `.github/copilot-instructions.md` and `.private/detailed-action-plan-yellowstone-national-park.com.md`.
- Use keyword research tools (KeywordsEverywhere, Tavily, Google Search Console) to identify and target high-volume, high-value, and relevant search terms. High volume, medium to low competition terms are the target. "People Also Search For" helps to find related topics currently not catered for, make strong use of KeywordsEverywhere tools to find new topics. Document keyword targets for each page in `.private/keyword-targets.md`.
- Ensure all pages have unique, descriptive titles, meta descriptions, and appropriate heading structures (H1, H2, etc.).
- Use internal linking to connect related content and improve crawlability. Add new pages to sitemaps and navigation as needed.
- Monitor for duplicate content, thin content, and technical SEO issues. Log and address all SEO issues in `.private/errors.md` and summarize fixes in `.private/CHANGELOG.md`.
- Track SEO performance and rankings using Google Search Console and analytics. Store and review reports in `.private/google-search-console-reports/`.

**Failure to follow these instructions strictly will result in incomplete or substandard website improvements. Every step must be documented, referenced, and verifiable in the appropriate project files.**


---

**Ultimate Focus: Every Action Must Drive AdSense Revenue**

Always remember: the primary goal is to maximize income from Google AdSense. Every guideline above is a means to this end. Here’s how each action directly contributes to making more money:

- **Improving accuracy, clarity, and completeness** makes your site more trustworthy and useful, which increases the likelihood that other sites will link to it. More links mean higher Google rankings, which means more visitors and more ad clicks.

- **Fact-checking and updating information** ensures your content is current and reliable. Google rewards up-to-date, authoritative content with better rankings, and users are more likely to stay, return, and share your site—driving more traffic and ad impressions.

- **Enhancing user experience and accessibility** keeps visitors on your site longer and encourages them to visit more pages. This increases pageviews per session and the number of ads shown, directly boosting AdSense revenue.

- **Targeting high-CPC keywords and topics** attracts visitors who are more likely to see and click on valuable ads. This is the single most direct way to increase earnings per visitor.

- **Expanding and interlinking content** increases the number of entry points for search engines and users, improving SEO and making it easier for visitors to discover high-value pages—again, leading to more traffic and more ad clicks.

- **Logging, documenting, and analyzing performance** ensures you are always learning what works best for revenue and can double down on the most profitable strategies.

- **Avoiding affiliate links and focusing on AdSense** keeps the site clean, focused, and compliant with Google’s policies, ensuring maximum fill rates and higher ad quality.

In summary: Every update, rewrite, and upgrade should be evaluated by asking, “Will this help the site get more high-value visitors, keep them longer, or make them more likely to click on high-paying ads?” If the answer is yes, it’s the right move. If not, reconsider. All quality, SEO, and helpfulness efforts are tactics to serve the ultimate goal: more money from AdSense.