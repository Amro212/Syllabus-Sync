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
   <img src="https://img.shields.io/badge/Core%20Data-1E3A8A" alt="Core Data" />
   <img src="https://img.shields.io/badge/CloudKit-0A84FF" alt="CloudKit" />
</p>

## Overview

Syllabus Sync is a focused iOS app that transforms course syllabi into structured schedules. It extracts key dates, presents them in a clear timeline, and lets students sync reminders to Apple Calendar without wrestling with manual entry.

The workflow is simple: import a PDF, review the extracted events, then publish a clean schedule with reminders. The result is a fast, reliable path from syllabus to calendar without noisy setup or manual data entry.

## Core Capabilities

- Import PDF syllabi and parse important dates
- Review and edit events before they hit your calendar
- Create a clean academic timeline with reminders
- Keep data synced across devices via iCloud

## Product Principles

- Clarity first, configuration last
- Minimal friction from PDF to calendar
- Privacy-aware by default with server-side parsing

## Tech Stack

- SwiftUI-based native iOS experience
- Cloudflare Workers API for server-side parsing
- TypeScript services for structured extraction
- Core Data + CloudKit for local persistence and sync
- EventKit integration for Apple Calendar

## Tech Snapshot

- iOS app built with SwiftUI
- Serverless parsing backend on Cloudflare Workers
- Core Data with CloudKit for device sync

## Status

MVP in active development.
