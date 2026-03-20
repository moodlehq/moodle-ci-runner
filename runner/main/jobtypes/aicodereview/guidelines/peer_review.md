# Moodle Peer Review Checklist (Condensed)

This is a condensed version of the Moodle peer review guidelines for use in automated code review.

## Checklist Items

### Syntax & Coding Style
- Code is easy to understand; comments provided where not obvious.
- Variables named correctly (all lower case, no camelCase, no underscores).
- Functions named correctly (all lower case, no camelCase, underscores allowed).
- PHP DocBlocks updated and adhere to coding style guide.
- Deprecation policy followed for removed functions.
- Code doesn't use deprecated functions.
- `$_GET`, `$_POST`, `$_REQUEST`, `$_COOKIE`, `$_SESSION` are never used directly.

### Output & Rendering
- Output renderers used to generate output strings, including HTML tags.
- HTML output is valid HTML5.
- No inline styles in HTML output (everything in CSS).
- CSS added to appropriate CSS files (base, specific area, canvas).
- Existing Bootstrap/theme classes and layouts used where possible.
- No buffered output unless absolutely necessary.
- All visual output has RTL alternative.

### Component Library (Moodle 4.0+)
- New UI features documented in the Component library.
- Includes examples, descriptions, and respects all themes.

### Icons
- New icons follow size, design, and format guidelines.
- Don't unnecessarily duplicate existing icon concepts.
- Placed in appropriate `pix` folder.

### Language Strings
- New strings named correctly (all lower case, no camelCase).
- Help strings named and formatted correctly.
- Language strings used instead of hardcoded text.
- Strings not removed/renamed/changed in stable branches.
- AMOS commands specified when moving/copying strings.

### Accessibility
- Passes automated accessibility checks (axe DevTools, WAVE).
- Sufficient colour contrast.
- Valid HTML.
- Keyboard navigation works.
- Screen reader properly announces UI components.

### Database
- Minimal DB calls (no excessive use).
- SQL compatible with all supported DB engines.
- All `ORDER BY` fields in `SELECT` clause.

### Performance & Clustering
- Filesystem, database, cache accesses done efficiently.
- Expensive code not in critical paths (not on every page load).
- Minimal code running; watch for hidden loops.
- No node-specific code (e.g., `opcache_reset()`).
- Performance considerations documented in comments.

### Security
- User login checked where identity needed.
- `sesskey` checked before write actions.
- Capabilities checked where roles differ.
- User inputs properly escaped (correct `PARAM_*` types).
- Security process followed for security issues.

### Privacy
- No unnecessary personal data saved.
- GDPR compliance for stored personal data.
- Data can be described, exported, and deleted (Privacy API).

### Mobile App
- `affects_mobileapp` label when changes may affect the app.
- New module settings returned via existing Web Services.
- New required Web Services included in mobile service.
- Global settings included in `tool_mobile_get_config`.
- Testing instructions include Moodle App testing steps.

### Third-party Code
- GPL-compatible license.
- Upgrade instructions in `readme_moodle.txt`.
- Recorded in `thirdparty.xml` with licensing info.
- Scanned for exploitable URL-accessible entry points.
- Does not duplicate existing API or library functionality.
- Modifications recorded in `readme_moodle.txt`.

### Documentation
- PHPdoc comments are useful (not just repeating function names).
- Upgrade notes written for significant API changes.
- Deprecation comments follow the deprecation policy.
- Appropriate tracker labels added (`docs_required`, `dev_docs_required`, `ui_change`, `api_change`, etc.).
- Issue components correctly set.

### Git
- Commit matches coding style guide for git commits.
- Git history is clean and rebased to logical commits.
- Original author credited.
- Branches provided for correct Moodle branches.

### Testing
- Manual testing instructions are clear, concise, and sufficient.
- Testing considers what else might be affected (regressions).
- Bug fixes include automated test coverage.
- Tests are efficient and follow best practice.
- Tests placed in logical locations.

### Overall Completeness
- Code solves the described problem completely.
- Code makes sense in the broader codebase context.
- Developer searched for other affected areas.
- Component maintainers involved/aware.
- Version numbers updated correctly if changed.

