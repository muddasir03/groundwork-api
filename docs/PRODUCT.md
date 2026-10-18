# Groundwork — Product Brief

This document describes the product we are building and the thinking behind it. Use it to understand what Groundwork is, who it serves and what matters most, so that the README and other project documents reflect the product accurately. It deliberately contains no coding practices or technical conventions.

"Groundwork" is a working name; the final name will be chosen before launch.

## 1. The problem

Job seekers spend days researching each company, and still end up applying blindly, because they cannot quickly answer three questions:

1. **What does this company actually do?** Its problems, customers, competitors, direction and technology.
2. **Am I a good fit, and why or why not?**
3. **Who should I contact, and how should I approach them?**

Answering these properly takes hours per company, spread across company websites, job posts, funding news, review sites and professional profiles. Most people cannot afford that for every application, so they send generic CVs to dozens of companies, apply to poor fits and are ignored.

## 2. Why existing solutions fall short

- **Job boards and AI job-matching tools** match a CV to job listings and encourage people to apply to more of them. They optimise for volume, not understanding.
- **General chatbots** can research one company when prompted, but they start from zero each time, cannot compare companies, may give unsourced or outdated claims, and do not remember the user's profile.

No product today combines deep, sourced company research with a personal, reasoned fit verdict and a clear route to the right people.

## 3. What Groundwork is

Groundwork does the company research before you apply. A user uploads their profile once, searches companies by country, reads a verified research report on each company, sees whether they fit and why, and finds the senior people worth contacting.

**One-line pitch:** *Groundwork does the company research before you apply: what they do, whether you fit, and who to talk to, in minutes instead of days.*

**Product philosophy:** fewer applications, better matched, each backed by real knowledge. Groundwork is the opposite of mass-applying.

## 4. Who it is for

- **Primary users:** software engineers and other professionals applying to companies they do not already know, particularly those targeting employers in other countries.
- **Launch audience:** engineers seeking roles at software and SaaS companies in Spain.
- **Possible future customers:** universities, bootcamps and relocation agencies that support many job seekers.

## 5. The four promises

Every feature must strengthen at least one of these. They are what make Groundwork more valuable than a chatbot.

| Promise | What it means for the user |
| --- | --- |
| **Instant and comparable** | Companies are researched in advance. Users filter by country and sector and compare companies side by side. |
| **Verified and current** | Every claim shows its source and the date it was researched. Reports are refreshed regularly. |
| **Personal and persistent** | The profile is entered once. Every company shows a fit verdict for that user, saved for later. |
| **Actionable** | Each company lists its senior people and offers a suggested way to approach them. |

## 6. What the user can do

1. **Create a profile:** upload a CV, link GitHub, GitLab, LinkedIn and a portfolio, and choose target countries and sectors.
2. **Confirm the extracted profile:** review the skills, experience and languages Groundwork identified, and correct anything wrong.
3. **Search companies:** filter by country, sector, city, company size and fit level.
4. **Read a company report:** a clear, sourced overview covering what the company does, the problems it solves, its clients and competitors, its goals, business model, product and engineering, team and hiring, market and risks, and industry knowledge.
5. **See their fit:** a score, a band (strong, possible or weak), what matches, what is missing, and a short explanation.
6. **Rate the verdict:** mark it as correct or wrong, so the product improves.
7. **Find the right people:** the CEO, CTO, engineering leaders and talent leads, linked to their public profiles.
8. **Get an approach:** on request, a proof-of-work idea based on the company's real gaps, the best person to contact and a draft message.
9. **Compare and shortlist:** compare up to three companies, save companies with notes, and track each one from research to interview.

An internal admin area lets the team research, review, edit and publish companies, manage contacts, review verdict feedback and monitor costs.

## 7. Product principles

- **Trust over volume.** Never invent facts. Where information cannot be verified, say "Unconfirmed" or "Not public". Every report is reviewed by a person before it is published.
- **Show the reasons.** A verdict is never a bare number. Users must always see why they fit or do not.
- **Respect privacy.** Use only public information about companies and their people. Never scrape LinkedIn or collect private email addresses. A user's CV and profile belong to them; they can delete all their data at any time.
- **Help people act, not just read.** Every company page should lead naturally to a next step.
- **Be honest about limits.** The product informs decisions; it does not guarantee outcomes.
- **Stay affordable.** Research is done once per company and shared by all users, so the product can remain low-cost as it grows.

## 8. Experience and tone

- **Feel:** calm, credible and research-focused, like a well-prepared briefing rather than a job board.
- **Voice:** clear, direct and respectful. Plain language, no hype, no exaggerated promises.
- **Design:** clean white cards on a light background, a cobalt accent, and green, amber and grey badges for strong, possible and weak fit. The fit score is the signature visual element.
- **Platforms:** a responsive web application that works well on both desktop and mobile. On mobile, each company is organised into three tabs: Report, Your fit and People.
- **Accessibility:** usable by keyboard and screen reader, with readable contrast and comfortable touch targets.

## 9. MVP scope

**Included:** everything in section 6, launched with about 30 researched companies in Spain.

**Not included yet:** live job listings, visa sponsorship information, payments, sending messages or applying on the user's behalf, native mobile apps and countries beyond the launch market.

## 10. How we will know it works

The first test puts Groundwork in front of ten real job seekers.

| Signal | What it tells us |
| --- | --- |
| Most users complete their profile | Onboarding is clear |
| Users open five or more companies each | The research is valuable |
| Most verdicts are rated correct | The fit verdict is trustworthy |
| Several users return within two weeks without a reminder | Groundwork solves a real, recurring problem |
| Some users contact a company through Groundwork | It leads to action |

If users return on their own, Groundwork is a product worth growing. If they do not, it remains a strong demonstration of end-to-end product engineering, and the feedback shows what to change.

## 11. Guidance for project documentation

When writing the README and other project documents, they should:

- Open with the problem and the one-line pitch, before anything technical.
- Explain the four promises and the product principles in plain language.
- Describe the user journey from profile to shortlist.
- State clearly that Groundwork is an MVP with a defined scope, and list what is not yet included.
- Note that "Groundwork" is a working name.
- Present the project honestly, without claiming users, results or traction that do not yet exist.
