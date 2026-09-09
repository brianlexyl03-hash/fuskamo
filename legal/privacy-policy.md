# Privacy Policy

**Last updated:** 2026-08-03

This policy explains what FUSKAMO ("the app", "we", "us") collects, why,
and what choices you have. It's written to match exactly what the app's
code actually does — every data category below corresponds to a real
table, form field, or SDK integration in this codebase, not a generic
template.

Legal entity and contact details below are filled in — review them
before launch and update if your registered business details change.

## 1. Who this policy covers

FUSKAMO is a football talent discovery platform. It's used by three
kinds of people: **players** (or a parent/guardian submitting on a
minor's behalf), **scouts/agents**, and **admins** who review
submissions. This policy applies to all three.

## 2. Data we collect

### Account data (if you sign in)
Email address and password (handled entirely by Supabase Auth — we never
see or store your raw password). Creating an account is optional; you can
browse the feed and submit a player without one, though signing in is
required to save players, track your submission status, or apply as a
scout.

### Player submissions
Name, position, age, country, club/academy, a free-text "strengths"
description, and an optional video clip. Optionally, a contact email
and/or phone number so a scout can reach you directly. If you're signed
in when you submit, the submission is linked to your account so you can
track its review status ("My Submissions").

**If the player is a minor:** submissions should be made by a parent or
guardian, or with their knowledge and consent — this is also a condition
of use in our [Terms](./terms.md). We don't currently verify age or
guardianship independently; treat this as an honor-system requirement
enforced at the point of submission.

### Scout applications
Name, organization, and optional contact email/phone, submitted for
admin review before you're listed publicly as a verified scout.

### Payment data (M-Pesa)
If you use the "boost submission" feature, we process your M-Pesa phone
number and the transaction amount through Safaricom's Daraja API to
complete the payment. We store the transaction record (phone number,
amount, status, M-Pesa receipt number) for reconciliation. **We never see
or store your M-Pesa PIN or full account details** — that exchange
happens directly between your phone and Safaricom.

### Device and notification data
If you enable push notifications, we store a device token (tied to your
account, if signed in) so we can deliver notifications to your device.
You can revoke this at any time by signing out or disabling notification
permissions in your phone's settings.

### AI-generated content
If you use "Preview AI scouting note," the player details you've entered
(name, position, age, country, club, strengths) are sent to our AI
provider to generate a short summary. This text is a draft preview only —
it isn't stored unless you go on to submit the player.

### What we don't collect
We don't run analytics or ad-tracking SDKs, don't sell data to third
parties, and don't collect precise device location.

## 3. Why we collect it and who else sees it

| Data | Purpose | Shared with |
|---|---|---|
| Account email | Sign-in, linking your submissions | Supabase (our database/auth provider) |
| Submission details | Public display once approved; admin review | Visible publicly once approved; reviewed by admins before that |
| Contact email/phone | Letting a scout reach you directly | Shown only to someone who taps "Contact" on your card |
| M-Pesa phone/transaction | Processing the boost payment | Safaricom (Daraja API) |
| Device token | Delivering push notifications | Firebase Cloud Messaging (Google) |
| AI preview inputs | Generating a draft scouting note | Our AI provider, for that single request |

## 4. How long we keep it

Approved and pending submissions are kept while your account is active.
Rejected submissions and their attached contact details are retained for
[X days/months — set a real retention window] to allow you to see the
rejection status before removal. Transaction records are retained as
required for financial reconciliation and any applicable tax/record-
keeping obligations.

## 5. Your rights

You can:
- **See what you've submitted** — the "My Submissions" and "Saved
  Players" sections of your Profile.
- **Request deletion** of your account and associated data by contacting
  us at `brianlexyl03@gmail.com`.
- **Withdraw a pending submission** by contacting us before it's
  reviewed.
- **Opt out of push notifications** at any time via your device settings
  or by signing out.

## 6. Security

Data in transit is encrypted (HTTPS/TLS). Database access is governed by
Row Level Security policies — for example, only you can see your own
pending/rejected submissions; everyone else only sees approved ones.
Admin actions (approving/rejecting, viewing transaction history) require
a separate admin credential that is never included in the public app —
see our internal `docs/admin-access.md` for how that's enforced.

## 7. Children's data

Some submissions are about minors, submitted by or with the consent of a
parent/guardian (see §2). We don't knowingly allow a minor to create
their own account or submit contact information about themselves without
adult involvement. If you believe a minor has used this app in a way
that concerns you, contact us at `brianlexyl03@gmail.com` and we'll investigate.

## 8. International use

FUSKAMO is built for a global player/scout audience with a focus on
Africa. Data is processed on infrastructure operated by our providers
(Supabase, Firebase, Safaricom) which may be located outside your
country. By using the app you consent to this transfer.

## 9. Changes to this policy

We'll update the "Last updated" date above when this policy changes.
Material changes (e.g., a new category of data collected) will be
called out in the app's changelog.

## 10. Contact

Questions about this policy, or a request under §5: `brianlexyl03@gmail.com`

---
**Legal entity:** `Lexil N.P.C.`
**Contact:** `brianlexyl03@gmail.com`

_This document was drafted to accurately reflect what this app's code
does as of the date above. It is not a substitute for review by a
qualified lawyer familiar with data protection law in the jurisdictions
where you operate (e.g., Kenya's Data Protection Act, and GDPR if you
have EU users) — have one review this before public launch._
