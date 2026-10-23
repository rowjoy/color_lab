# SDD ledger — plan: docs/superpowers/plans/2026-10-21-color-history.md

Ruling: The user's “next” continues the document's next module, local database plus history; proceed through implementation without another approval gate.

Ruling: Use stable Hive with plain versioned maps and path_provider, an explicit allowed stack choice; no code generation is warranted for this small schema.

| Tasks | Boundary | Preflight |
| --- | --- | --- |
| 1 / 3 | Domain repository API and Hive factory | Explicit shared signatures; root consumes, storage agent owns implementation |
| 2 / 3 | Async state, query/filter, mutations | Explicit provider/method contracts; UI agent owns section, root owns save actions |
| 1 / 2 | Immutable SavedColor and ColorSource | Model import only; no shared file writes |
| 1 | Durable operation tests | Reopen real box files; no in-memory substitute for storage verification |
| 2 | UI tests | Inject repository; assert visible behavior and accessible actions |
| 3 | Existing app integration | Fresh test-local repositories avoid platform-plugin access |

Task 1: complete — versioned immutable model, serialized durable Hive repository, protected corruption/error paths; 22 scoped tests pass. Review identified failed-flush retry gap; five regressions reproduced it and now pass. Scoped re-review approved, no remaining required findings.

Task 2: complete — Saved/Studio views, actual saved colors, search/filter, favorite and confirmed deletion, empty/error/loading states and accessibility. All 13 scoped UI tests pass. Integrated review approved; chip icon polish and neutral readable dialog actions applied.

Task 3: complete — overridable repository factory and serialized controller, detail save/favorite/loading/error/retry actions with origin propagation. Eight controller and five action tests pass; existing app tests use test-local storage. Full suite: 96 passed. Android debug APK rebuilt successfully after the last production correction. Eight light/dark real-font previews render and have been visually inspected. Final integration review and scoped retry correction review approved with no required findings remaining.

Ruling: Retry a load on the already-open repository; invalidate the factory only if opening itself failed — avoids racing asynchronous close with reopening a healthy Hive box. Controller.retry() owns this policy.

Ruling: Haptic feedback is fire-and-forget and cannot change storage success — observed saved AsyncData with a still-busy button while awaiting the platform haptic call. A haptic failure regression also reproduced false save-error feedback; actions now finish with storage and ignore optional haptic failures.

Ruling: Explicit pending-flush tracking is required despite Hive's cache commit — reads/no-op edits/close must retry the barrier before reporting a successful durable state. Fault injection wraps real disk Hive only at flush.

Final review follow-up: An overridable directory boundary enabled a disposal guard test but also required Retry to invalidate a cached directory-resolution error. A real-factory regression failed with the old retry, then passed after the directory-error invalidation was added. Healthy storage is still reused after ordinary read failures.

Verification: full suite 96 tests passed, final Android build succeeded, formatting/check and static analysis are run before packaging. Earlier transient failures documented in subagent reports are superseded by the final integrated results.

Delivery: cumulative source archive `dist/color-lab-history-2026-10-21.zip`; existing Foundation archive preserved. README has exact added dependencies, changed-file tree, run/check commands, storage policies and module boundaries. Next module is camera/gallery picking and photo palette/detail completion. iOS device execution remains unverified.
