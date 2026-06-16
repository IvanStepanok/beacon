# Beacon — Incentive Design (non-monetary)

_The challenge must-have (`requirements/solution-requirements.md` #3): "App includes
innovative **non-monetary** features to incentivize engagement, **without encouraging
repeat submissions or bad actors**." How Beacon motivates reporters, why every reward is
gaming-resistant by construction, and why Beacon deliberately pays nothing._

## The reward loop: recognition for VERIFIED contribution only

Beacon's incentive currency is points, badges, and an anonymous alias, visible only to
the reporter in their Profile. The defining property: nothing is awarded for submitting;
everything is awarded for being right.

- Points are server-derived, never stored or client-writable. A reporter earns a fixed
  award (`PointsPerVerifiedReport = 10`) per report an analyst has verified, computed
  at read time from `count(verification = 'verified')` in
  `backend/internal/store/crisis.go` (`GetOrCreateProfile`). There is no mutable points
  counter anywhere a client could increment.
- The self-award endpoint is retired. `POST /api/v1/profile/points` used to let a
  client add arbitrary points to its own profile, a trivial gaming vector. It now returns
  a stable 410 Gone and performs no work
  (`backend/internal/handler/profile.go`, `AwardPoints`).
- Badges are derived the same way (`deriveBadges`): each badge keys off verified work
  or genuine distinct activity (e.g. "Verified eyes" at 5 verified reports), never off raw
  submission counts. Spam earns nothing.
- Anonymous alias: the profile reserves an alias slot tied to the pseudonymous
  device id, with no account, name, phone, or email (`X-Device-Id` pseudonymity, see
  `docs/DATA-DICTIONARY.md` §6); setting the alias in-app is roadmap. Recognition without
  identity exposure.

## Anti-gaming safeguards (Requirement #3)

The reward loop sits behind the same abuse controls that protect data quality
(details in [`docs/DATA-QUALITY.md`](./DATA-QUALITY.md)):

| Safeguard | Mechanism |
|---|---|
| **Per-device rate limits** | DB-backed, per submitter: 5 reports/minute burst, 20/10 minutes sustained → 429 (`backend/internal/service/report_service.go`) |
| **Per-IP rate limit** | `httprate.LimitByIP` on every request (`backend/internal/api/router.go`) |
| **Near-duplicate guard** | Any report without a tapped footprint from the same submitter within 25 m / 10 min of a previous one → 409 referencing the existing report (only a real footprint re-report is exempt; it versions instead) |
| **Footprint-bound building identity** | Re-reports of the same building collapse into one version chain (latest-wins), so 50 photos of one ruin ≠ 50 buildings' worth of points |
| **Verification gate** | The only point-earning event is an analyst decision, itself photo-gated and audited (`report_verification_audit`) |
| **Tiered trust by device id** | The pseudonymous device id lets the server track a submitter's verified-vs-flagged history without any account, the tiered-trust model UNDP endorsed in the challenge Q&A webinars |

The mobile client surfaces these server rejections as a terminal "Rejected" sync state
in My Reports. No silent retries, so a blocked submission can never be farmed by waiting.

## Why no monetary rewards

1. **The challenge requires it.** Must-have #3 explicitly asks for *non-monetary*
   engagement features; payment would also be unworkable at crowdsourcing scale and
   would invert the data-quality incentive (pay-per-report manufactures reports).
2. **Payment is the wrong motivator in a crisis, and the evidence says so.** Ukraine's
   Diia damage-reporting experience showed affected people report at scale with zero
   payment when reporting visibly connects to response. The motivator Beacon is built
   around is "my report leads to action": reporters watch their own report move
   `pending → verified` in My Reports, see it appear on the shared map, and points/badges
   exist only as a trace of that confirmed usefulness.
3. **Aid must never be gated on data.** The governance pack's recruitment-messaging rule
   ([`docs/RAPID-DEPLOYMENT-48H.md`](./RAPID-DEPLOYMENT-48H.md) §3) forbids tying reporting
   to assistance; introducing money would blur exactly that line.

**Honest limits:** the close-the-loop push notification ("your report was verified /
acted on") is not wired yet (see `docs/STATUS.md` roadmap); today the loop closes when the
reporter opens the app. Points/badges have no leaderboard by design: public ranking of
reporters in a crisis zone would create both perverse incentives and a protection risk.
