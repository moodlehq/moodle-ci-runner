# Moodle Integration Review Checklist (Condensed)

This is a condensed version of the Moodle integration review guidelines for use in automated code review.

## Integration Principles

1. **Safety**: If something does not look safe or stable, it should not land. Be conservative.
2. **Security**: All security issues must be integrated/backported to all security-supported versions.
3. **Community**: Changes must be useful for the community. Consider impact on: HQ (10%), Partners (10%), Core devs (10%), Admins (20%), Teachers (20%), Students (30%).
4. **Typology**: Bug fixes go to all supported branches. Improvements and new features go to `main` only.
5. **Priority**: Issues ordered by priority (mix of various factors). Lower priority may be delayed.
6. **Tests**: Unit and acceptance tests backported as much as possible without breaking safety/security.

## Integration Review Checklist

### Final Code Review
- Coding guidelines compliance (syntax, whitespace).
- Moodleisms: using built-in API functions where appropriate (`$DB`, `$OUTPUT`, `$PAGE`, etc.).
- Cross-DB compatibility (SQL works on PostgreSQL, MySQL/MariaDB, Oracle, MSSQL).
- Security: proper input validation, capability checks, sesskey verification.

### Purpose Verification
- The patch fixes the issue reported (does it actually solve the problem?).
- The change is appropriate and proportional to the issue.

### Target Branch Verification
- Branches match the backporting rules:
  - Improvements/new features: `main` only.
  - Bug fixes: `main` + all current stable branches affected.
  - Security fixes: `main` + all stable + security-only branches.

### Backwards Compatibility
- Backwards compatibility maintained as a starting point.
- Any BC breaks are:
  - Well discussed with evidence of justification.
  - Documented and communicated to the community.
- Backwards compatibility with the Moodle mobile app maintained (especially pre-rendered content like Quiz, Lesson).

### Component & People
- Components are correct.
- Right people involved (component maintainers aware/participated).
- For fundamental changes: forum discussion started, community given time to comment.

### Testing
- Manual testing instructions guide tester to verify fix.
- Unit tests preferred where applicable.
- Automated test coverage for bug fixes and new features.

### Performance & Scalability
- Code maintains optimum performance (simple optimisations applied).
- For `main` only: consider future scalability.

### Git & Authorship
- Git authorship correct vs. committer.
- Credits mentioned where due.
- Email addresses correct.
- Commits are clean and logical.

### Documentation & Labels
- PHPDoc / readability adequate.
- Appropriate tracker labels:
  - `docs_required` / `dev_docs_required` / `release_notes`
  - `ui_change` / `api_change`
  - `unit_test_required` / `acceptance_test_required` / `qa_test_required`
  - `affects_mobileapp` / `affects_workplace` / `affects_moodlecloud`

### Version Numbers
- Fixed Version set correctly after integration.
- `Must fix for X.Y` version removed once integrated.

