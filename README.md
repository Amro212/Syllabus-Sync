<p align="center">
   <img src="./Syllabus%20Sync/Assets.xcassets/SyllabusIcon.imageset/app-icon.png" width="96" alt="Syllabus Sync logo" />
</p>

<h1 align="center">Syllabus Sync</h1>

<p align="center">
   Turn messy course PDFs into a clean, editable academic timeline with one-tap calendar sync.
</p>

<p align="center">
   <img src="./Syllabus%20Sync/Assets.xcassets/BooksIllustration.imageset/books-icon.png" width="140" alt="Books icon" />
</p>

<p align="center">
   <img src="https://img.shields.io/badge/Swift-FA7343?logo=swift&logoColor=white" alt="Swift" />
   <img src="https://img.shields.io/badge/SwiftUI-0B5FFF?logo=swift&logoColor=white" alt="SwiftUI" />
   <img src="https://img.shields.io/badge/iOS-111111?logo=apple&logoColor=white" alt="iOS" />
   <img src="https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white" alt="TypeScript" />
   <img src="https://img.shields.io/badge/Node.js-339933?logo=node.js&logoColor=white" alt="Node.js" />
   <img src="https://img.shields.io/badge/Cloudflare%20Workers-F38020?logo=cloudflare&logoColor=white" alt="Cloudflare Workers" />
   <img src="https://img.shields.io/badge/OpenAI-111111?logo=openai&logoColor=white" alt="OpenAI" />
   <img src="https://img.shields.io/badge/EventKit-0A84FF?logo=apple&logoColor=white" alt="EventKit" />
   <img src="https://img.shields.io/badge/Supabase-3FCF8E?logo=supabase&logoColor=white" alt="Supabase" />
</p>

## Overview

Syllabus Sync is a focused iOS app that transforms course syllabi into structured schedules. It extracts key dates, presents them in a clear timeline, and lets students sync reminders to Apple Calendar without wrestling with manual entry.

The workflow is simple: import a PDF, review the extracted events, then publish a clean schedule with reminders. The result is a fast, reliable path from syllabus to calendar without noisy setup or manual data entry.

## Core Capabilities

- Import PDF syllabi and parse important dates
- Review and edit events before they hit your calendar
- Create a clean academic timeline with reminders
- Secure cloud storage with Supabase

## Product Principles

- Clarity first, configuration last
- Minimal friction from PDF to calendar
- Privacy-aware by default with server-side parsing

## Tech Stack

- SwiftUI-based native iOS experience
- Cloudflare Workers API for server-side parsing
- TypeScript services for structured extraction
- Supabase for authentication and cloud storage
- EventKit integration for Apple Calendar

## Tech Snapshot

- iOS app built with SwiftUI
- Serverless parsing backend on Cloudflare Workers
- Supabase (PostgreSQL) for auth and data persistence

## How Parsing Works

When you import a syllabus, the app runs a multi-step pipeline to turn messy PDFs into reliable calendar events:

1. **Text extraction** — The PDF is rasterized on-device and passed through Vision OCR to extract raw text. Headers, footers, and duplicates are filtered out.

2. **Pre-processing** — A regex pass on the server identifies grading breakdown sections (e.g., "Assignments 30%, Final Exam 40%") and tags lines that look like events (`[EVENT:ASSIGNMENT]`, `[EVENT:MIDTERM]`, etc.). Boilerplate sections (academic integrity, accessibility policies) are stripped to keep the AI focused.

3. **AI extraction** — A single OpenAI call with structured JSON output parses dates, titles, and weights. The AI must quote the exact source text for each date it extracts—if it can't cite the syllabus, the event is flagged for review.

4. **Validation** — Events are checked against the grading scheme: if the AI missed a deliverable the regex found, a placeholder is injected so the user sees everything. Dates outside the term window are clamped, and low-confidence events (< 70%) are marked for review.

5. **User approval** — Before anything reaches your calendar, you review and edit the extracted events. Low-confidence items are highlighted so you can fix dates the AI wasn't sure about.

**Cost and safety controls**: A Durable Object on Cloudflare enforces per-user daily caps and a global daily budget on OpenAI calls. This prevents runaway costs and abuse without blocking legitimate use.

## Status

MVP in active development.
