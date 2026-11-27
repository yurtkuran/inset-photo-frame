# CLAUDE.md

## Project Purpose and Scope

- This is a native iPhone and iPad application dedicated exclusively to adding inset frames to photographs.
- Read `docs/REQUIREMENTS.md` in its entirety before planning or implementing changes. Treat it as the authoritative product requirements document.
- Do one thing exceptionally well. Do not introduce unrelated photo-editing features or expand the scope without explicit user approval.
- Prioritize simplicity, ease of use, rendering accuracy, performance, and image quality.

## Development Guidelines

- Follow the implementation approach defined in `docs/REQUIREMENTS.md`.
- Use Swift, SwiftUI, and native Apple frameworks wherever practical. Avoid unnecessary dependencies and architectural complexity.
- Share resolution-independent frame geometry between preview and export. Calculate frame width and offset relative to the photograph's shortest dimension.
- Preserve original photographs, resolution, and aspect ratio. Keep processing on-device.
- Review existing code and repository conventions before making changes. Keep changes focused and avoid unrelated refactoring.
- Ask for approval before making significant architectural decisions or changing product requirements. Make routine implementation decisions independently.
- Never discard or overwrite unrelated user changes.

## Build and Testing

- Build the application and run relevant tests after implementation changes.
- Test frame geometry, parameter validation, and preview/export consistency, including different image dimensions and orientations.
- Verify iPhone and iPad layouts where simulator availability permits.
- Report build results, test results, known limitations, and any verification that could not be completed. Never claim that unexecuted tests passed.

## Git Workflow and Commit Conventions

- Work only on non-protected branches. Never commit directly to `master`, or `develop`.
- Branch flow: `feature/*` from `develop` → PR → `develop` → production release PR → `master` → CI/CD → production.
- GitHub branch protection is unavailable on the current plan; local hooks in `.githooks/` block direct commits and pushes to `develop` and `master`. Never bypass them with `--no-verify`.
- Verify the current branch before committing. If on a protected branch, ask the user how to proceed.
- Never commit changes without explicit user authorization.
- When changes are ready, provide a proposed commit title and description for review.
- Commit titles must begin with a type enclosed in square brackets, followed by a concise, imperative description.
- Keep commit titles concise and descriptive, preferably under 72 characters. Prioritize clarity over strict length limits.
- Supported commit types:
  - `[feature]` — New functionality.
  - `[update]` — Enhancements to existing functionality.
  - `[bugfix]` — Bug fixes.
  - `[quality]` — Refactoring, cleanup, or test improvements.
  - `[security]` — Security-related changes.
  - `[docs]` — Documentation changes.
  - `[chore]` — Maintenance, dependencies, or tooling.
- Commit descriptions must be concise bullet points (not prose paragraphs) that summarize the changes and explain their purpose, emphasizing why rather than merely what. Pull request descriptions use the same bullet style.
- Do not include unrelated changes in a commit.
- Never push changes to a remote repository without explicit authorization.
- Pull requests:
  - After the user approves a commit, push the feature branch and create the pull request into `develop` with `gh pr create`; that approval covers pushing the feature branch.
  - The user reviews and merges all pull requests. Never merge, approve, or close a pull request.
  - Create production release pull requests (`develop` → `master`) only when the user asks.

## Communication

- Keep explanations concise and technically precise.
- Summarize completed changes, verification results, and outstanding issues before requesting commit approval.
- Keep `docs/REQUIREMENTS.md` and implementation aligned; do not silently revise requirements to accommodate implementation choices.
