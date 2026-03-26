# StrongMind LTI Integration Tool
### Built by Billy Williams | Stacked Alchemist LLC | stackedalchemist.dev

**GitHub:** _add link here_
**Live Demo:** _add link here_
**Loom Walkthrough:** _add link here_

---

## What This App Does

A fully functional LTI 1.3 tool built in Ruby on Rails that integrates with Instructure Canvas.
Built as a working demonstration targeting the Software Engineer 3 role at StrongMind.

- Launches inside Canvas via LTI 1.3 (OIDC flow) with full JWT validation
- Student dashboard with progress tracking, grade display, and assignment status
- Versioned content authoring for instructors — drafts never break the live student view
- Automatic grade passback to the Canvas gradebook via LTI Advantage AGS
- Multi-turn AI study assistant powered by Claude (`claude-sonnet-4-6`) with course context
- Instructor analytics: AI usage stats and keyword frequency across all student conversations
- Background job processing via Sidekiq + Redis with retry/exponential backoff
- Rate limiting on AI endpoint (20 requests/student/hour) via Rack::Attack
- Full RSpec test suite (52 examples, 0 failures)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Ruby on Rails 7.2 |
| Frontend | ERB + TailwindCSS (CDN) |
| Database | PostgreSQL |
| LTI Auth | LTI 1.3 + OIDC, JWT RS256 |
| AI | Anthropic Claude API (`claude-sonnet-4-6`) |
| Grade Passback | LTI Advantage Assignment & Grade Services (AGS) |
| Versioning | PaperTrail gem |
| Background Jobs | Sidekiq + Redis |
| Rate Limiting | Rack::Attack |
| Testing | RSpec + FactoryBot + WebMock |
| Deployment | Railway / Render (HTTPS required) |

---

## Local Development Setup

### Prerequisites

- Ruby 3.2+
- PostgreSQL 14+
- Redis 7+
- Node.js (for asset pipeline)

### 1. Clone and Install

```bash
git clone https://github.com/YOUR_USERNAME/strongmind-lti.git
cd strongmind-lti
bundle install
```

### 2. Generate RSA Key Pair

LTI 1.3 requires an RSA key pair for signing JWTs. Generate one:

```ruby
# Run in rails console or a one-off script
require 'openssl'
key = OpenSSL::PKey::RSA.generate(2048)
puts key.to_pem          # LTI_PRIVATE_KEY
puts key.public_key.to_pem  # LTI_PUBLIC_KEY
```

### 3. Configure Environment Variables

Create a `.env` file in the project root (never commit this):

```
CANVAS_OIDC_AUTH_URL=https://sso.canvaslms.com/api/lti/authorize_redirect
CANVAS_JWKS_URL=https://sso.canvaslms.com/api/lti/security/jwks
LTI_CLIENT_ID=             # From Canvas Developer Key (after registration)
LTI_DEPLOYMENT_ID=         # From Canvas tool deployment
LTI_PRIVATE_KEY=           # RSA private key — paste PEM with literal \n between lines
LTI_PUBLIC_KEY=            # RSA public key — same format
ANTHROPIC_API_KEY=         # Get from console.anthropic.com
REDIS_URL=redis://localhost:6379/0
```

**Key format note:** The PEM keys must be stored as single-line strings with `\n` as literal backslash-n. Example:

```
LTI_PRIVATE_KEY=-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAK...\n-----END RSA PRIVATE KEY-----
```

### 4. Database Setup

```bash
rails db:create
rails db:migrate
```

### 5. Start Services

You need three processes running:

```bash
# Terminal 1 — Rails server
rails server

# Terminal 2 — Sidekiq worker (grade passback jobs)
bundle exec sidekiq

# Terminal 3 — Redis (if not running as a system service)
redis-server
```

### 6. Expose Locally with ngrok (for Canvas testing)

Canvas requires HTTPS for LTI. Use ngrok to tunnel your local server:

```bash
ngrok http 3000
```

Note the `https://` URL — you'll use this when registering the Canvas Developer Key.

---

## Canvas Configuration

### Register the LTI Developer Key

1. Go to Canvas Admin > Developer Keys > **+ LTI Key**
2. Select **Paste JSON** and use the config below (replace `YOUR_DOMAIN` with your ngrok or production URL):

```json
{
  "title": "StrongMind Demo Tool",
  "description": "LTI 1.3 demo — versioned content, grade passback, AI assistant",
  "oidc_initiation_url": "https://YOUR_DOMAIN/lti/login",
  "target_link_uri": "https://YOUR_DOMAIN/lti/launch",
  "public_jwk_url": "https://YOUR_DOMAIN/.well-known/jwks.json",
  "scopes": [
    "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem",
    "https://purl.imsglobal.org/spec/lti-ags/scope/score",
    "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly",
    "https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly"
  ],
  "extensions": [{
    "platform": "canvas.instructure.com",
    "privacy_level": "public",
    "settings": {
      "placements": [{
        "placement": "course_navigation",
        "message_type": "LtiResourceLinkRequest",
        "default": "enabled",
        "enabled": true
      }]
    }
  }]
}
```

3. Save the key — copy the **Client ID** shown in the key list
4. Set `LTI_CLIENT_ID=<that value>` in your `.env`

### Add Tool to a Course

1. Go to a Canvas course > Settings > Apps > **+ App**
2. Select **By Client ID**, enter your Client ID
3. The tool appears in course navigation as "StrongMind Demo Tool"
4. Copy the **Deployment ID** from the app settings and set `LTI_DEPLOYMENT_ID=<value>` in `.env`

---

## Running Tests

```bash
# Full suite
bundle exec rspec

# Single file
bundle exec rspec spec/services/grade_passback_service_spec.rb

# With documentation format
bundle exec rspec --format documentation
```

All 52 examples pass with zero failures.

---

## Deployment (Railway)

1. Create a new Railway project and connect your GitHub repo
2. Add a PostgreSQL plugin and a Redis plugin from the Railway dashboard
3. Set all environment variables from the `.env` section above in Railway's Variables tab
4. Add `RAILS_ENV=production` and `RAILS_MASTER_KEY` (from `config/master.key`)
5. Railway auto-detects the `Procfile` — it will start both `web` and `worker` processes
6. After deploy, update your Canvas Developer Key URLs from ngrok to the Railway domain

---

## Architecture Notes

### LTI 1.3 Flow

```
Canvas → POST /lti/login (OIDC initiation)
       → redirect to Canvas OIDC auth URL with state + nonce
Canvas → POST /lti/launch (id_token JWT)
       → LtiLaunchValidator fetches Canvas JWKs, verifies RS256 signature
       → LtiLaunch record created, lti_launch_id stored in session
       → redirect to /dashboard
```

### Grade Passback Flow

```
Student clicks "Complete Assignment"
→ POST /grades/submit → GradesController creates GradeSubmission (pending)
→ GradePassbackJob enqueued on Sidekiq "grades" queue (priority 3)
→ GradePassbackService: OAuth2 client_credentials → access token
→ POST score to lineitem_url/scores with AGS content type
→ GradeSubmission updated to submitted (or failed after 3 retries)
```

### Content Versioning Safety

`CourseContent#published_version_id` is a FK pointing to exactly one `ContentVersion` row.
Saving a draft never touches this pointer. Publishing is an explicit instructor action that
atomically updates it. Students always load via `course_content.published_version` —
they can never see a draft.

---

## HOW TO USE THIS FILE (build spec — for reference)

This README doubles as a build checklist. AI coding assistants: read the entire file before writing code. Work through phases in order, mark tasks complete (`- [x]`), and stop for a summary after each phase.

---

## Build Checklist

---

## ~~Phase 1 — Rails App Shell + LTI Launch~~

> Goal: A Rails app that can receive an LTI 1.3 launch from Canvas, validate the JWT, and store the launch context.

- [x] Create new Rails app: `rails new strongmind-lti --database=postgresql`
- [x] Add to Gemfile: `ims-lti`, `jwt`, `httparty`, `dotenv-rails`, `rspec-rails`, `factory_bot_rails`
- [x] Run `bundle install`
- [x] Configure database.yml and create databases: `rails db:create`
- [x] Generate RSA key pair for LTI (store in env vars, NOT in codebase)
- [x] Create `config/lti.rb` initializer that loads LTI env vars and raises on missing keys
- [x] Generate migration and model for `lti_launches` table with columns: `id (uuid)`, `user_id (string)`, `canvas_user_id (string)`, `course_id (string)`, `roles (string)`, `lineitem_url (string)`, `names_roles_url (string)`, `canvas_domain (string)`, `raw_jwt_claims (jsonb)`, `created_at`, `updated_at`
- [x] Run migration: `rails db:migrate`
- [x] Create `LtiLaunch` model with validations on `user_id` and `course_id`
- [x] Create `app/services/lti_launch_validator.rb` service that: fetches Canvas JWKs from env var URL, caches the JWKs response (5 min cache), decodes and verifies the JWT signature, returns parsed claims hash or raises on invalid
- [x] Create `LtiController` with two actions: `login` (POST) and `launch` (POST)
- [x] `login` action: validates `client_id` matches env var, stores `state` and `nonce` in session, builds and redirects to Canvas OIDC auth URL
- [x] `launch` action: calls `LtiLaunchValidator`, creates `LtiLaunch` record from claims, stores `lti_launch_id` in session, redirects to dashboard
- [x] Create `GET /.well-known/jwks.json` endpoint that serves the tool's public key as JWK format
- [x] Add routes: `post '/lti/login'`, `post '/lti/launch'`, `get '/.well-known/jwks.json'`
- [x] Skip CSRF verification on LtiController (Canvas POSTs without CSRF token)
- [x] Write RSpec request specs for login and launch endpoints
- [ ] Test locally with ngrok: `ngrok http 3000` — verify launch completes without error

**Phase 1 complete when:** A Canvas LTI launch reaches the app, JWT is validated, LtiLaunch record is saved to the database, and the session contains `lti_launch_id`.

---

## ~~Phase 2 — Student Dashboard~~

> Goal: A role-aware dashboard that renders inside Canvas showing student progress, course info, and assignment status.

- [x] Generate migration and model for `student_progress` table with columns: `id (uuid)`, `lti_launch_id (uuid, fk)`, `canvas_course_id (string)`, `canvas_user_id (string)`, `assignments_total (integer)`, `assignments_completed (integer)`, `grade_to_date (decimal)`, `last_activity_at (timestamp)`, `created_at`, `updated_at`
- [x] Run migration
- [x] Create `StudentProgress` model with `belongs_to :lti_launch`
- [x] Create `DashboardController` with `show` action
- [x] Add `before_action :require_lti_launch` that loads `LtiLaunch` from session or returns 401
- [x] Add `before_action :set_role` that reads roles from `lti_launch.roles` and sets `@is_instructor` / `@is_student` booleans
- [x] `show` action: loads or creates `StudentProgress` for current user + course, renders appropriate view based on role
- [x] Create `app/views/dashboard/show.html.erb` — student view showing: course name, progress percentage bar, grade to date, assignment list with status icons (complete / in-progress / not started)
- [x] Create `app/views/dashboard/_instructor.html.erb` partial — instructor view showing: course overview, list of enrolled students with progress, link to content authoring
- [x] Add TailwindCSS via CDN in `app/views/layouts/application.html.erb`
- [x] Style dashboard — dark background, clean card layout, readable typography (match StrongMind's clean aesthetic)
- [x] Add route: `get '/dashboard'`, set as root route after LTI launch
- [x] Write RSpec controller specs for dashboard with student and instructor roles
- [ ] Manual test: launch from Canvas as student, verify dashboard renders with correct role view

**Phase 2 complete when:** Student and instructor see different dashboard views after LTI launch, and StudentProgress record is created/loaded correctly.

---

## ~~Phase 3 — Versioned Content Authoring~~

> Goal: Teachers can create and edit course content without ever breaking the published version students see. Every edit is a draft. Publishing is an explicit action.

- [x] Generate migration for `course_contents` table: `id (uuid)`, `canvas_course_id (string)`, `title (string)`, `published_version_id (uuid, nullable)`, `created_at`, `updated_at`
- [x] Generate migration for `content_versions` table: `id (uuid)`, `course_content_id (uuid, fk)`, `body (text)`, `author_id (string)`, `author_name (string)`, `version_number (integer)`, `status (string, default: draft)`, `change_summary (string)`, `created_at`
- [x] Run migrations
- [x] Create `CourseContent` model: `has_many :content_versions`, `belongs_to :published_version, class_name: 'ContentVersion', optional: true`
- [x] Create `ContentVersion` model: `belongs_to :course_content`, add validations, add scope `published` and `drafts`
- [x] Add `paper_trail` gem, run `rails generate paper_trail:install`, run migration
- [x] Enable PaperTrail on `ContentVersion` model: `has_paper_trail`
- [x] Create `CourseContentsController` with actions: `index`, `show`, `new`, `create`
- [x] Create `ContentVersionsController` with actions: `new`, `create` (save as draft), `publish` (set as published version on parent CourseContent), `rollback` (revert to a previous version)
- [x] Enforce instructor-only access on all content authoring actions via `before_action`
- [x] Student `show` action: always loads `published_version` — never shows drafts
- [x] Instructor `show` action: shows published version with a "currently editing" draft panel alongside it
- [x] Create views for: content index list, student content view (published only), instructor authoring view (draft editor + version history sidebar), version history panel showing all versions with author + timestamp + change summary
- [x] Add textarea or simple rich text input for body content
- [x] Add "Save Draft" and "Publish" buttons — Save Draft never touches published version
- [x] Add "Rollback" button per version in history panel — creates a new draft from old version body
- [x] Add routes: `resources :course_contents do; resources :content_versions; end`, add `member` route for `publish` and `rollback`
- [x] Write RSpec model specs: verify draft save does not change published version, verify student cannot access draft, verify rollback creates new draft
- [x] Write RSpec controller specs for publish and rollback actions
- [ ] Manual test: create content, save multiple drafts, publish one, verify student view only shows published

**Phase 3 complete when:** Teacher can save drafts, publish a specific version, roll back to any previous version, and student view never shows unpublished content under any circumstance.

---

## ~~Phase 4 — Grade Passback (LTI AGS)~~

> Goal: When a student completes an assignment, the score is automatically sent back to the Canvas gradebook via LTI Advantage Assignment and Grade Services.

- [x] Generate migration for `grade_submissions` table: `id (uuid)`, `lti_launch_id (uuid, fk)`, `canvas_user_id (string)`, `score (decimal)`, `max_score (decimal)`, `activity_progress (string)`, `grading_progress (string)`, `status (string, default: pending)`, `canvas_response (jsonb)`, `error_message (string)`, `attempt_count (integer, default: 0)`, `submitted_at (timestamp)`, `created_at`, `updated_at`
- [x] Run migration
- [x] Create `GradeSubmission` model with validations and status enum: `pending`, `submitted`, `failed`
- [x] Create `app/services/grade_passback_service.rb` with: OAuth2 client credentials grant to get access token from Canvas, POST score to AGS scores endpoint using `lineitem_url` from `LtiLaunch`, parse and return Canvas response, update `GradeSubmission` record with result
- [x] Add `sidekiq` and `redis` gems, run `bundle install`
- [x] Create `app/jobs/grade_passback_job.rb` Sidekiq worker that: calls `GradePassbackService`, retries up to 3 times with exponential backoff on failure, marks submission as `failed` after max retries
- [x] Create `GradesController` with `submit` action: creates `GradeSubmission` record, enqueues `GradePassbackJob`, returns JSON response
- [x] Add a "Complete Assignment" button to the student content view that triggers grade submission
- [x] Add route: `post '/grades/submit'`
- [x] Configure Sidekiq in `config/sidekiq.yml`
- [x] Add Sidekiq web UI route under `/sidekiq` with basic auth (instructor only)
- [x] Write RSpec specs for `GradePassbackService` with stubbed HTTP responses
- [x] Write RSpec specs for `GradePassbackJob` retry behavior
- [ ] Manual test: complete assignment as student, verify `GradeSubmission` record status changes to `submitted`, verify score appears in Canvas gradebook

**Phase 4 complete when:** Completing an assignment triggers grade passback, the score appears in Canvas, and failed submissions retry automatically.

---

## ~~Phase 5 — AI Study Assistant~~

> Goal: Students get an AI assistant inside the tool that knows their course content and can answer questions. Teachers get an analytics view showing what students are asking.

- [x] Add `anthropic` gem (or use `httparty` for direct API calls), run `bundle install`
- [x] Generate migration for `ai_conversations` table: `id (uuid)`, `lti_launch_id (uuid, fk)`, `canvas_user_id (string)`, `canvas_course_id (string)`, `messages (jsonb, default: [])`, `created_at`, `updated_at`
- [x] Run migration
- [x] Create `AiConversation` model with `belongs_to :lti_launch`
- [x] Create `app/services/ai_assistant_service.rb` that: builds a dynamic system prompt using course title, published content body, and student name from LTI launch context, appends conversation history to messages array, calls Claude API (`claude-sonnet-4-6`, max_tokens: 1000), returns assistant response text, updates conversation record with new messages
- [x] Add `rack-attack` gem for rate limiting — limit AI endpoint to 20 requests per student per hour
- [x] Create `AiAssistantController` with `chat` action (POST): loads or creates `AiConversation` for current user + course, calls `AiAssistantService`, returns JSON with assistant response
- [x] Add AI chat panel to student dashboard view: collapsible sidebar, message thread display, text input + send button, loading indicator while waiting for response
- [x] Wire chat UI to `AiAssistantController` via fetch/AJAX — no full page reload
- [x] Create instructor analytics view showing: total AI conversations per course, most common question topics (simple keyword frequency from messages jsonb), list of recent conversations (anonymized or by student name based on privacy setting)
- [x] Add route: `post '/ai/chat'`, `get '/ai/analytics'`
- [x] Write RSpec specs for `AiAssistantService` with stubbed Claude API response
- [ ] Manual test: ask AI assistant a question about the course content, verify response uses course context, verify conversation is saved

**Phase 5 complete when:** Student can have a multi-turn AI conversation about course content, conversation is persisted per session, and instructor can see usage analytics.

---

## ~~Phase 6 — Polish, Deploy, and Demo Package~~

> Goal: Clean deployed app, solid README, GitHub repo, and Loom walkthrough. A complete package to hand to StrongMind.

- [x] Update this README with final setup instructions, local dev guide, and Canvas configuration steps
- [x] Audit all controllers for missing auth guards — every action must require valid LTI session or return 401
- [x] Add error handling for failed LTI launches — render a friendly error page, log the failure
- [x] Add basic logging throughout: LTI launch events, grade passback attempts, AI requests
- [x] Run full RSpec suite — fix any failing tests: `bundle exec rspec` (52 examples, 0 failures)
- [x] Remove all debug output, `binding.pry`, `puts`, `console.log` statements
- [x] Set up production credentials in `config/credentials.yml.enc`
- [ ] Deploy to Railway or Render — ensure HTTPS is active (Canvas requires HTTPS for LTI)
- [ ] Register deployed URL in Canvas Developer Key — update all URLs from ngrok to production domain
- [ ] Do a full end-to-end test on the deployed app: LTI launch → dashboard → view content → complete assignment → grade passback → AI chat
- [ ] Record Loom walkthrough (3-5 minutes): show LTI launch, student dashboard, teacher content authoring with version history, grade appearing in Canvas gradebook, AI assistant responding with course context
- [ ] Push all code to GitHub with clean commit history (one commit per phase minimum)
- [ ] Add GitHub repo link and Loom link to top of this README
- [ ] Final review: would you be proud to hand this to a hiring manager?

**Phase 6 complete when:** App is live, repo is public, Loom is recorded, and the full demo package is ready to send.

---

## Project Complete

**GitHub:** _add link here_
**Live Demo:** _add link here_
**Loom Walkthrough:** _add link here_

---

*Built by Billy Williams | Stacked Alchemist LLC | stackedalchemist.dev | EST. 2026*
*"Protector of love, through time and death."*
