# SysteMIC — Church Backoffice Documentation

**Version:** 1.0.0  
**Last updated:** July 2026  
**Application:** SysteMIC (`mic_backoffice`)

> **Guides:** [User guide (EN)](USER_GUIDE.md) · [Guide utilisateur (FR)](USER_GUIDE.fr.md)  
> **Full docs:** [English](DOCUMENTATION.md) · [Français](DOCUMENTATION.fr.md)

---

## Table of contents

1. [Introduction](#1-introduction)
2. [Getting started](#2-getting-started)
3. [Roles and permissions](#3-roles-and-permissions)
4. [Navigation (mobile vs desktop)](#4-navigation-mobile-vs-desktop)
5. [Dashboard](#5-dashboard)
6. [Members](#6-members)
7. [Departments](#7-departments)
8. [Church attendance](#8-church-attendance)
9. [Sunday school attendance](#9-sunday-school-attendance)
10. [Visitors](#10-visitors)
11. [Events](#11-events)
12. [Trainings (classes) and sessions](#12-trainings-classes-and-sessions)
13. [Teachings and listeners](#13-teachings-and-listeners)
14. [Tasks, projects, and tags](#14-tasks-projects-and-tags)
15. [Task penalties](#15-task-penalties)
16. [Service schedule (Media Team)](#16-service-schedule-media-team)
17. [Finance and giving](#17-finance-and-giving)
18. [Chat and announcements](#18-chat-and-announcements)
19. [Notifications and push](#19-notifications-and-push)
20. [Reports](#20-reports)
21. [Settings and administration](#21-settings-and-administration)
22. [File viewer](#22-file-viewer)
23. [Business rules reference](#23-business-rules-reference)
24. [Technical appendix](#24-technical-appendix)

---

## 1. Introduction

### What is SysteMIC?

SysteMIC is a church backoffice application built for church leadership and administration. It centralizes day-to-day operations: member records, attendance, visitors, departments, tasks, finance, events, trainings, teachings, and reporting.

The app is available on **mobile** (phone/tablet) and **desktop/web** (browser or desktop window). Both share the same data and backend.

### Who uses it?

| User type | Typical use |
|-----------|-------------|
| **Admin / Pastor** | Full configuration, user accounts, leader permissions, data export |
| **Department leader** | Members, attendance, tasks, department reports, Media Team schedule |
| **Finance leader** | Giving records and finance reports |
| **Member (with login)** | View-only or limited access depending on admin configuration |

### Languages

The interface supports **English**, **French**, and **Spanish**. Change language in **Settings**.

### Technology (summary)

- **Frontend:** Flutter (Dart)
- **Backend:** Supabase (PostgreSQL database, authentication, storage, edge functions)
- **Push notifications (mobile):** Firebase Cloud Messaging (FCM)

---

## 2. Getting started

### 2.1 Signing in

1. Open the app.
2. Enter your **email** and **password**.
3. Tap **Sign in**.

If this is your first login with a default password (`Password123`), you will be redirected to **Change password** before you can use the app.

### 2.2 Forgot password

1. On the login screen, tap **Forgot password**.
2. Enter your email.
3. Follow the reset link sent by email.
4. Set a new password on the reset screen.

### 2.3 First-time setup (admin)

An administrator should:

1. Create member records (or import data).
2. Create login accounts for leaders who need access (**Settings → Member accounts**).
3. Configure **Leader access** per user (which modules they can view/create/edit/delete).
4. Create departments and assign leaders.
5. Optionally configure birthday notifications and task penalty settings.

### 2.4 Splash screen behavior

On launch, the app:

- Restores your session if still valid.
- Redirects to login if the session expired.
- Runs background checks (e.g. task penalty calculation).
- Registers the device for push notifications on mobile.

---

## 3. Roles and permissions

### 3.1 User roles

| Role | Description |
|------|-------------|
| `admin` | Full access to all features and settings |
| `pastor` | Treated as admin for permission checks |
| `leader` | Access controlled by **Leader access** settings |
| `member` | Login linked to a member profile; usually view-only unless granted more |

> **Note:** The email `mic@mic.com` is always treated as admin (super admin).

### 3.2 Department roles

Within a department, each member has a department role:

| Role | Meaning |
|------|---------|
| `leader` | Head of department |
| `subleader` | Deputy |
| `member` | Regular department member |

Department leaders and subleaders are treated as “leaders” for certain permission checks even if their global user role is `member`.

### 3.3 Leader access (granular permissions)

**Path:** Settings → Leader access management (admin only)

For each leader or member with a login, the admin can set permissions **per feature**:

| Permission | Meaning |
|------------|---------|
| View | Can open and read the module |
| Create | Can add new records |
| Edit | Can modify existing records |
| Delete | Can remove or soft-delete records |

**Features that can be controlled:**

| Feature key | Module |
|-------------|--------|
| `members` | Members |
| `departments` | Departments |
| `trainings` | Trainings / classes |
| `events` | Events |
| `tasks` | Tasks |
| `reports` | Reports hub |
| `church_attendance` | Church attendance |
| `sunday_school_attendance` | Sunday school |
| `visitors` | Visitors |
| `giving` | Finance / giving |
| `chat` | Announcements |
| `teachings` | Teachings |

### 3.4 Special access rules

- **Finance tab (mobile bottom navigation):** Visible only if you are admin **or** a leader in the department named **Finance**.
- **Creating announcements:** Admin, pastor, or leader (not controlled by granular leader access).
- **Member accounts & leader access pages:** Admin/pastor only.

---

## 4. Navigation (mobile vs desktop)

### 4.1 Mobile layout

- **Bottom navigation** (on main screens): Home, Members, [Finance if authorized], Chat, Settings.
- **Dashboard quick actions** link to: Members, Departments, Trainings, Reports, Church Attendance, Sunday School, Visitors, Teachings.
- Other modules (Tasks, Events, Departments detail, etc.) are reached from dashboard, lists, or in-screen navigation.
- Standard **back** button in the app bar.

### 4.2 Desktop layout

- Activated when screen width is **≥ 500px**.
- **Fixed left sidebar** (240px) with all main modules.
- **Content area** with header and stack-based navigation (list → detail without full page reload).
- Separate desktop login/signup/forgot-password pages.

**Desktop sidebar modules:**

Home · Members · Departments · Finance · Chat · Settings · Notifications · Birthdays · Events · Tasks · Trainings · Reports · Church Attendance · Sunday School · Visitors · Teachings · Sessions

### 4.3 Notifications entry

- **Mobile:** Bell icon on dashboard app bar → Notifications list.
- **Desktop:** Notifications item in sidebar.

---

## 5. Dashboard

**Path:** Home / Dashboard

### Purpose

Gives leaders a quick overview of church activity and shortcuts to key modules.

### What you see

#### Summary statistics

| Stat | Description |
|------|-------------|
| Upcoming sessions | Training sessions in the next 35 days |
| Upcoming events | Active future events |
| Open tasks | Tasks with status `pending` or `in_progress` |
| Birthdays | Members with birthdays this month |
| Members | Total active members (mobile) |

#### Church attendance chart (desktop)

- Line chart showing **daily presence** over recent services.
- Compares per-service attendance with **weekly total** attendance.

#### Lists and tables (desktop)

- Upcoming events
- Recent teachings
- Upcoming birthdays
- Newcomers (members flagged as new comers)

#### Mobile sections

- Welcome banner with today’s date
- Quick action grid (8 shortcuts)
- Preview cards: birthdays, teachings, newcomers, events

### Actions

- Pull to refresh (mobile) to reload all dashboard data.
- Tap any stat or list item to open the related module.

---

## 6. Members

**Path:** Members (`/members`)

### Purpose

Central registry of everyone connected to the church: contact details, spiritual profile, departments, newcomer status, and optional login account.

### 6.1 Members list

- Search and filter members.
- Filter by newcomer status, role, active/inactive.
- Open a member profile or add a new member.

### 6.2 Add / edit member

#### Required fields

- First name, last name
- Birthday (required on create)

#### Profile fields

| Field | Description |
|-------|-------------|
| Email, phone | Contact; phone uses country code picker (default Cameroon) |
| Address, city, state, zip, country, quarter | Location |
| Gender | `male`, `female`, `other` |
| Marital status | `single`, `married`, `divorced`, `widowed` |
| Role | `member`, `worker`, `leader`, `admin`, `sympathiser` |
| Profession | Student levels, job seeking, worker — drives study/diploma fields |
| Level of study, sector, domain, key skills, diplomas | Conditional on profession |
| Photo | Uploaded to cloud storage |
| Active | Whether member is currently active |
| New comer | Flag for integration tracking |
| Newcomer join date | When they started as newcomer |
| Newcomer intention | See below |
| Birthday notifications opt-out | Exclude from birthday notification campaigns |

#### Newcomer intention

| Value | Meaning |
|-------|---------|
| `wants_to_stay` | Intends to join the church |
| `does_not_know_yet` | Undecided |
| `just_passing` | **Cannot be saved as member** — use Visitors instead |

### 6.3 Member profile

Tabs typically include:

- **Profile** — full details, edit, delete (if permitted)
- **Attendance** — church and training attendance history
- **Classes** — trainings the member is enrolled in

Actions:

- Edit member
- Open individual member report
- Contact via WhatsApp (if phone present)

### 6.4 Upcoming birthdays

**Path:** `/members/birthdays`

- Lists members with birthdays in the coming period.
- Useful for pastoral follow-up and celebration planning.

### 6.5 Member accounts (admin)

**Path:** Settings → Member accounts

- Create a **login account** for a member who has an email.
- Default password: `Password123` (must be changed on first login).
- New accounts start with **view-only** access on all features until admin adjusts leader access.

### 6.6 Newcomer graduation (automatic)

When a member is flagged as **new comer**, the system tracks church attendance. After **9 or more attendances within 90 days**, the newcomer flag can be cleared automatically (database function `check_and_update_new_comer_status`).

---

## 7. Departments

**Path:** Departments (`/departments`)

### Purpose

Organize the church into teams (Media Team, Finance, Worship, etc.) with members, documents, tasks, written reports, and optional service schedules.

### 7.1 Department list

- View all departments.
- Add department (if permitted).
- Open department detail.

### 7.2 Create / edit department

| Field | Description |
|-------|-------------|
| Name | Department name |
| Description | Optional text |
| Active | Whether department is in use |
| Task penalty amount | Optional daily penalty override for department tasks (francs) |
| Documents | Up to 4 reference files (PDF, images, etc.) with custom names |

### 7.3 Department detail

#### Overview tab

- Department description
- **Documents** — open in file viewer
- **Members** — add/remove, assign department role (`leader`, `subleader`, `member`)
- Statistics and quick actions

#### Tasks tab

- Opens the **task workspace** filtered to this department.
- Generate **monthly or yearly task PDF reports** for the department.

#### Reports tab

- List of **written department reports** (narrative).
- Add, edit, delete reports.
- Export individual or summary PDF.

### 7.4 Media Team — service schedule

If the department is the **Media Team**, a **Service schedule** button opens the media production roster (see [Section 16](#16-service-schedule-media-team)).

---

## 8. Church attendance

**Path:** Church attendance list (`/attendance/church/list`) → Mark attendance (`/attendance/church`)

### Purpose

Record who attended each church gathering. The system supports **any date** and **multiple named services per day** (e.g. “Morning Service” and “Evening Service” on the same Sunday).

### 8.1 Concepts

| Concept | Description |
|---------|-------------|
| **Church service** | A gathering on a specific **date** with a required **name** |
| **Attendance record** | One row per member per service |

> **Legacy note:** Older data was migrated from Sunday/Wednesday types to named services (“Sunday Service”, “Wednesday Service”).

### 8.2 Services list

- Browse all church services (newest first).
- Each row shows: **service name**, **full date**, **attendance count**.
- Filter by date range and service name.
- Actions: open attendance, delete service, generate PDF report.

### 8.3 Create a new service

1. Open **Mark attendance** (or add from list).
2. Pick a **date** (any day of the week).
3. Enter a **service name** (required, unique for that date).
   - Examples: “Sunday Morning”, “Wednesday Prayer”, “Special Revival”.
4. Save — the service row is created in `church_services`, then you can mark attendance.

### 8.4 Mark attendance

For each **active member**:

| Attendance type | Meaning |
|-----------------|---------|
| `onsite` | Physically present |
| `online` | Joined remotely (stream, etc.) |
| `absent` | Did not attend |

Additional options:

- **Specific observation** — free-text note per member (e.g. absence reason).
- **Bulk mark** — set many members to the same status at once.
- **Filter** — show all, onsite, online, absent, or **children** (age 0–12).
- **Search** — find members by name.

### 8.5 Visitors on attendance page

- Log visitors for the same service date.
- Visitors can be linked to the specific `church_service_id`.
- Visitor attendance types: `onsite`, `online` (visitors do not use `absent` in the same way as members).

### 8.6 WhatsApp contact

From the attendance screen, leaders can open WhatsApp to contact a member (uses stored phone number).

### 8.7 Delete a service

Soft-deletes:

- The church service record
- All attendance rows for that service
- Linked visitors for that service

### 8.8 Reports

From the list or attendance page:

- **Full attendance report** (PDF) — date range, optional service filter.
- **Absent people report** (PDF) — members marked absent for a specific service.

### 8.9 Data model (reference)

**`church_services`**

| Column | Description |
|--------|-------------|
| `id` | UUID |
| `service_date` | Date of gathering |
| `name` | Required; unique per date |
| `created_by` | User who created it |

**`church_attendance`**

| Column | Description |
|--------|-------------|
| `member_id` | Member |
| `church_service_id` | Which service |
| `service_date` | Denormalized date |
| `attendance_type` | `onsite`, `online`, `absent` |
| `specific_observation` | Optional note |

---

## 9. Sunday school attendance

**Path:** Sunday school list (`/attendance/sunday-school/list`) → Session (`/attendance/sunday-school`)

### Purpose

Attendance for **children only** (ages 0–12 per system age category).

### Workflow

1. Open the **sessions list** — grouped by `attendance_date`.
2. Select a date (or create a new session date).
3. See eligible child members.
4. Mark each child as present.
5. Export PDF report for a date range.

### Data

**`sunday_school_attendance`:** `member_id`, `attendance_date`, `created_by`

> Sunday school is **separate** from church attendance and does not use `church_services`.

---

## 10. Visitors

**Path:** Visitors (`/visitors`)

### Purpose

Track people who visit the church but are not yet (or never will be) full members — especially those “just passing through.”

### 10.1 Add / edit visitor

| Field | Description |
|-------|-------------|
| First name, last name | Required |
| Email, phone, address | Optional |
| Visit date | Date of visit |
| Church service | Optional link to a specific service on that date |
| Attendance type | `onsite` or `online` |
| Notes | Free text |

If **church service** is left empty, the visit applies to the date generally (any service that day).

### 10.2 Convert visitor to member

From the visitors list:

1. Select a visitor.
2. Choose **Convert to member**.
3. Complete member fields (birthday, role, newcomer flags).
4. Visitor record is soft-deleted; new member is created.

> Visitors with intention `just_passing` should remain visitors, not members.

### 10.3 Reports

- **Visitor report PDF** — filter by date range from the list page.

---

## 11. Events

**Path:** Events (`/events`)

### Purpose

Publish church events, manage registrations, and track who signed up.

### 11.1 Event fields

| Field | Description |
|-------|-------------|
| Title, description | Event details |
| Event date | When it happens |
| Location | Optional |
| Active | Whether event is visible |
| Repeated | Whether event has multiple sessions |

### 11.2 Event detail

#### Overview tab

- Event information
- Edit / delete (if permitted)

#### Registrations tab

- List of registered members and guests.
- **Register member** — pick from member list.
- **Register guest** — name, email, phone without member record.
- **Bulk register** — many members at once.
- **Unregister** — remove a registration.

### 11.3 Repeated events

For repeated events, the system can **generate sessions** (similar to training sessions). Each session can have its own attendance tracking.

---

## 12. Trainings (classes) and sessions

**Path:** Trainings (`/trainings`)

### Purpose

Structured training programs (discipleship classes, leadership courses, etc.) with enrolled members and per-session attendance.

### 12.1 Training (class) fields

| Field | Description |
|-------|-------------|
| Name | Training title |
| Description | Optional |
| Department | Optional link to a department |
| Active | Whether training is ongoing |

### 12.2 Workflow

1. **Create training** and optionally link to a department.
2. **Enroll members** on the training detail page.
3. **Generate sessions** — creates scheduled session dates (typically weekly).
4. Open a **session** → **Take attendance** for each enrolled member.
5. View **training report** from Reports hub.

### 12.3 Sessions (desktop)

**Path:** Desktop → Sessions

Cross-training view of all upcoming sessions across classes.

### 12.4 Offline attendance (limited)

Training session attendance can be queued offline via `OfflineQueueService` and synced when connectivity returns.

---

## 13. Teachings and listeners

**Path:** Teachings (`/teachings`)

### Purpose

Record sermons/teachings delivered at church and track which workers/leaders have “listened” (reviewed or acknowledged the teaching).

### 13.1 Teaching fields

| Field | Description |
|-------|-------------|
| Title | Teaching title |
| Teaching date | Date preached |
| Speaker | Who delivered it |
| Description | Optional notes |

### 13.2 Listeners

On the teaching **detail** page:

- **Listeners** are members with role `worker`, `leader`, or `admin`.
- Add or remove listeners manually.
- **Sync from attendance** — automatically add listeners who attended church on the teaching date (any church service that day, onsite or online).

### 13.3 Auto-created Media Team tasks

When a new teaching is saved, the system automatically creates **6 tasks** for the **Media Team** department:

| Task type | Description |
|-----------|-------------|
| Mid 1, Mid 2 | Medium-length video edits |
| Short 1, Short 2, Short 3 | Short clips |
| Full | Full recording edit |

- Due date = teaching date + offset (default **10 days**, configurable in penalty settings).
- Tasks appear in the department task workspace.

---

## 14. Tasks, projects, and tags

**Path:** Tasks (`/tasks`)

### Purpose

Department and individual task management with multiple views, projects, colored tags, reminders, and analytics.

### 14.1 Task fields

| Field | Values / notes |
|-------|----------------|
| Title | Required |
| Description | Optional |
| Department | Task owned by department |
| Assigned member | Or assign to individual |
| Project | Optional grouping |
| Due date | YYYY-MM-DD |
| Priority | `urgent`, `high`, `medium`, `low` |
| Status | `pending`, `in_progress`, `completed`, `cancelled` |
| Tags | Multiple colored tags |
| Penalty amount per day | Optional override (francs) |
| Archived | Excluded from penalty calculations |

### 14.2 Workspace views

| View | Description |
|------|-------------|
| **Projects** | Tasks grouped by project; inline add row; drag between projects |
| **All / Table** | Sortable, resizable columns; inline edit title, status, assignee, due date, tags, description |
| **Board** | Kanban columns by status |
| **Timeline** | Gantt-style chart with zoom |
| **Avg. lateness** | Analytics: how late tasks are completed |
| **Workload** | Analytics: tasks per member |
| **Penalties** | Members with penalty balances; record payments |

### 14.3 Projects

**Path:** Tasks → Manage projects (`/tasks/projects`)

- Create projects with title and optional department.
- Assign tasks to projects.
- Track project progression.

### 14.4 Tags

**Path:** Tasks → Manage tags (`/tasks/tags`)

- Tags are **department-scoped** (or global).
- Each tag has a **name** and **color** (palette picker).
- Assign tags when creating/editing tasks or inline in the table.

### 14.5 Assignments

- A task can have **multiple assignees** (`task_assignments`).
- Each assignment has status: `pending`, `completed`, `cancelled`.
- Assigning someone sends a **task_assigned** notification (and push on mobile).

### 14.6 Reminders

- **Per-task reminder** — notify all assignees from task detail.
- **Remind all pending** — bulk reminder from task list.
- Creates `task_reminder` notifications.

### 14.7 Department task reports

From **Department detail → Tasks**, export:

- Monthly task completion PDF
- Yearly task completion PDF

---

## 15. Task penalties

### Purpose

Encourage timely completion of tasks (especially Media Team teaching deliverables) through a financial penalty balance system.

### 15.1 How penalties accrue

- For each **non-completed** task assignment past its **due date**, a daily penalty is added.
- Penalty starts the **day after** the due date.
- Amount priority:
  1. Task-level `penalty_amount_per_day`
  2. Department `task_penalty_amount`
  3. Global default (**100 frs/day**)

### 15.2 Blocking threshold

- Default: **3,500 frs** total balance.
- If a member’s penalty balance ≥ threshold, they are **blocked from new task assignments** until balance is reduced.

### 15.3 Recording payments

**Path:** Tasks → Penalties view

1. Select a member with a balance.
2. Record a **payment** (amount, date, notes).
3. Balance decreases accordingly.

### 15.4 Settings (global)

Stored in `task_penalty_settings` (id = `global`):

| Setting | Default |
|---------|---------|
| Default daily penalty | 100 frs |
| Blocking threshold | 3,500 frs |
| Teaching task due offset | 10 days after teaching date |

Penalties are recalculated on app startup (splash screen).

---

## 16. Service schedule (Media Team)

**Path:** `/service-schedule` (from Media Team department)

### Purpose

Assign Media Team members to production roles for each service date.

### 16.1 Schedule

- One schedule per **department per service date**.
- Optional notes for the day.

### 16.2 Roles

| Role key | Label |
|----------|-------|
| `projection` | Projection |
| `call_recording` | Call / Recording |
| `principal_cameraman` | Principal cameraman |
| `secondary_cameraman` | Secondary cameraman |
| `photographer` | Photographer |

Up to **3 members** can be assigned per role.

### 16.3 Workflow

1. Pick a service date.
2. Assign members to each role.
3. Mark assignments **done** when completed.
4. Assignees receive **service_schedule_assigned** notification.

---

## 17. Finance and giving

**Path:** Finance / Giving (`/giving`)

### Purpose

Record tithes, offerings, expenses, and special gifts. Restricted to **Finance department leaders** and **admins**.

### 17.1 Giving record fields

| Field | Description |
|-------|-------------|
| Giver name | Required (member or external) |
| Amount | Positive number |
| Type | `receiving` or `expense` |
| Tag | `tithe`, `offering`, `construction`, `special_op`, `gift`, `other` |
| Member | Optional link if giver is a member |
| Notes | Optional |

### 17.2 Workflow

1. Open Finance list.
2. **Add giving** — fill form and save.
3. Filter and search transactions.
4. Edit or view existing records.
5. **Generate PDF report** for a date range.

### 17.3 Access

- Mobile: Finance appears in bottom nav only for authorized users.
- Desktop: Finance in sidebar for authorized users.
- Also requires `giving` feature permission in leader access (for non-admin leaders).

---

## 18. Chat and announcements

**Path:** Chat (`/chat`)

### Purpose

Broadcast **announcements** to the church — global, department-specific, or targeted to specific members.

> Despite the name “Chat,” this is an **announcement feed**, not real-time messaging.

### 18.1 Viewing announcements

- Newest announcements first.
- Shows title, message, date, scope (global / department / targeted).

### 18.2 Creating announcements (admin / pastor / leader)

| Field | Description |
|-------|-------------|
| Title | Short headline |
| Message | Full text |
| Global | Send to everyone |
| Department | Limit to one department |
| Target members | Optional specific member IDs |

Recipients receive an in-app **announcement** notification (and push on mobile if enabled).

---

## 19. Notifications and push

**Path:** Notifications (`/notifications`)

### 19.1 In-app inbox

- Lists all notifications for the logged-in user.
- Unread count shown on dashboard/sidebar.
- Tap to mark as read.
- Deep links may open related task, event, etc.

### 19.2 Notification types

| Type | When sent |
|------|-----------|
| `task_assigned` | Someone is assigned a task |
| `task_reminder` | Leader sends a reminder |
| `birthday` | Birthday notification campaign |
| `announcement` | New announcement published |
| `event` | Event-related |
| `service_schedule_assigned` | Media Team schedule assignment |

### 19.3 Push notifications (mobile)

- Uses Firebase Cloud Messaging.
- Device token stored on login.
- Delivered via Supabase edge function `send-push-notification`.
- Tapping a push opens the notifications screen (or related content).

### 19.4 Birthday notifications

**Path:** Settings → Birthday notifications

| Audience setting | Who receives |
|------------------|--------------|
| All | All active members not opted out |
| Leaders only | Department leaders and subleaders |
| Opt out | Disabled church-wide |

Members can opt out individually via **birthday_notifications_opt_out** on their profile.

---

## 20. Reports

**Path:** Reports (`/reports`)

### 20.1 Reports hub

Central entry for analytics and exports.

### 20.2 Available reports

| Report | Path | Periods | PDF |
|--------|------|---------|-----|
| Members (aggregate) | `/reports/members` | Weekly, monthly, yearly, custom | — |
| Individual member | `/reports/member/:id` | Custom | — |
| Trainings (aggregate) | `/reports/trainings` | Weekly, monthly, yearly, custom | — |
| Individual training | `/reports/training/:id` | Per class | — |
| New comers | `/reports/new-comers` | Weekly, monthly, yearly, custom | Yes |
| Church attendance | From attendance list | Date range | Yes |
| Sunday school | From Sunday school list | Date range | Yes |
| Visitors | From visitors list | Date range | Yes |
| Finance | From finance page | Date range | Yes |
| Department tasks | From department detail | Monthly, yearly | Yes |
| Department written reports | From department reports | Per report | Yes |

### 20.3 New comer report contents

- Newcomer list with intention and status
- Attendance breakdown (onsite / online / absent) per newcomer
- Summary statistics for the period

### 20.4 Church attendance report contents

- Services in date range with counts
- Member attendance matrix (who attended which services)
- Presence charts grouped by service name
- Diligence / monthly summaries

---

## 21. Settings and administration

**Path:** Settings (`/settings`)

### 21.1 Preferences

| Setting | Options |
|---------|---------|
| Language | English, French, Spanish |
| Theme | Light, dark, system |
| Notifications | Enable/disable local notification preference |

### 21.2 Birthday notifications

Configure church-wide birthday notification audience (see [Section 19.4](#194-birthday-notifications)).

### 21.3 Data management

| Action | Description |
|--------|-------------|
| Export all data | Full JSON backup (share/save) |
| Import data | Restore from JSON (skips duplicate emails) |
| Export members CSV | Spreadsheet of member roster |
| Sync users & members | Admin: align auth users with member records |
| All users PDF | Admin: export user list report |

### 21.4 Admin settings (admin/pastor only)

- **Leader access management** — per-user feature permissions
- **Member accounts** — create logins for members

### 21.5 Account

- View logged-in email
- Change password
- Log out
- App version display

### 21.6 Admin panel

**Path:** `/admin` (admin)

- Create admin or pastor users (email, password, role).

---

## 22. File viewer

**Path:** `/file-viewer` (opened from department documents and elsewhere)

### Purpose

View uploaded files (especially PDFs and images) inside the app.

### Behavior

- **PDF:** Rendered with pdfrx or WebView depending on platform.
- **Images:** Displayed inline.
- **Desktop:** Opens as overlay in the shell with back navigation.
- Files are stored in Supabase Storage; URLs are passed to the viewer.

---

## 23. Business rules reference

| Rule | Detail |
|------|--------|
| Newcomer graduation | 9+ church attendances in 90 days → `is_new_comer` cleared |
| Just passing | Cannot create as member; use Visitors |
| Church services | Date + name required; multiple per day; name unique per date |
| Attendance types (church) | `onsite`, `online`, `absent` |
| Attendance types (visitor) | `onsite`, `online` |
| Children filter | Age 0–12 (`MemberUtils` child category) |
| Sunday school | Children only; separate table from church attendance |
| Task penalties | Daily accrual after due date; 3,500 frs block threshold |
| Teaching tasks | 6 auto tasks per new teaching for Media Team |
| Default password | `Password123` for new/synced accounts |
| Soft delete | Most tables use `deleted_at` instead of hard delete |
| Phone default country | Cameroon (`CM`, +237) |
| Super admin | `mic@mic.com` always has admin access |
| Finance access | Admin or Finance department leader |
| Announcement create | Admin, pastor, or leader (any) |

---

## 24. Technical appendix

### 24.1 Main database tables

| Table | Module |
|-------|--------|
| `users` | Authentication & roles |
| `members` | Member registry |
| `leader_access` | Granular permissions |
| `departments`, `department_members` | Departments |
| `church_services`, `church_attendance` | Church attendance |
| `sunday_school_attendance` | Sunday school |
| `visitors` | Visitors |
| `events`, `event_registrations`, `event_sessions` | Events |
| `classes`, `sessions`, `class_members`, `attendance` | Trainings |
| `teachings`, `teaching_listeners` | Teachings |
| `tasks`, `task_assignments`, `task_tags`, `tags`, `projects` | Tasks |
| `task_penalty_settings`, `task_penalty_payments` | Penalties |
| `service_schedules`, `service_schedule_assignments` | Media schedule |
| `giving` | Finance |
| `announcements` | Chat |
| `notifications`, `device_tokens` | Notifications |
| `new_comers` | Newcomer history |

### 24.2 Key services (`lib/services/`)

| Service | Responsibility |
|---------|----------------|
| `church_service_service.dart` | CRUD for church services |
| `church_attendance_service.dart` | Attendance marking and queries |
| `member_service.dart` | Members CRUD |
| `department_service.dart` | Departments |
| `task_service.dart` | Tasks, assignments, reminders |
| `task_penalty_service.dart` | Penalty calculation and payments |
| `visitor_service.dart` | Visitors |
| `finance_service.dart` | Giving records |
| `teaching_service.dart` | Teachings and listeners |
| `service_schedule_service.dart` | Media Team schedule |
| `leader_access_service.dart` | Permission checks |
| `notification_service.dart` | In-app notifications |
| `report_service.dart` | Report aggregation |
| `*_pdf_service.dart` | PDF generation |

### 24.3 Routes reference

See `lib/core/routes/route_names.dart` for the complete list of named routes.

### 24.4 Offline support

- `OfflineQueueService` queues limited operations (training attendance, task updates) when offline.
- Full offline mode is **not** implemented; church attendance requires connectivity.

### 24.5 Migrations

Database schema is managed via SQL scripts in the project root and `supabase/migrations/`. Notable migration:

- `MIGRATE_CHURCH_SERVICES.sql` — introduces `church_services` and removes `service_type` from attendance/visitors.

### 24.6 Push notification setup

See `supabase/functions/send-push-notification/README.md` for Firebase service account configuration and edge function deployment.

---

## Document history

| Date | Change |
|------|--------|
| July 2026 | Initial full documentation; church services model (date + name, multiple per day) |

---

*For technical support or feature requests, contact your church system administrator.*
