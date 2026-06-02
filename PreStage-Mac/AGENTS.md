# Agent Notes

- Use graded verification to conserve Codex usage.
- A-level changes: copy, styling, or small component refactors. Do static checks only; do not launch the app.
- B-level changes: state, API, routing, or build-related changes. Run typecheck/lint/build. Do not use Computer Use unless the successful build still leaves an obvious UI risk.
- C-level changes: user-visible interaction, maps, upload, filtering, popovers/dialogs, or mobile layout. After the build passes, launch the app and use Computer Use to verify only 1-3 key paths. Do not explore unrelated pages or flows.
- When instructions conflict, this graded verification policy supersedes any broader requirement to always launch the app or always use Computer Use.
- Include the verification level, commands, and any visual or usability issues found in the final response.
