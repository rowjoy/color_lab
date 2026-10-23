# Approximate Color Formula design

Continue Phase2 with the next module from the supplied Color Lab build specification, sections2 and6.5. The user's “Next” requests implementation in the established module-by-module workflow. This is a new small subsystem, documented before implementation; the original request to follow the document and start without unnecessary questions preserves continuous execution.

## Experience and scope

Lab gains Open color formula, keeping its HSL study and Mixer intact. Any common color detail gains Find color formula so captured, saved, mixed and illustrated-room colors can be targets. The guarded full-screen `/formula` route shows the current target, a Choose target action using the existing manual-HEX/saved-library picker, and a clear asynchronous search state. Default target is Lilac#B2A4D4; the selected target is retained during this app session, not persisted as a project.

Results show target versus closest displayed blend, one to three positive base contributions with percentages totaling100%, the weighted bar, and CIE76 delta-E against the displayed result (lower is closer). Every result is explicitly approximate; bases are digital sRGB references, not measured pigments or a real paint recipe. A details/save action applies to the resulting color using existing Lab-source history and deduplication. Target and result swatches can open existing details. Existing copy/share/Room actions are reused, not reimplemented.

Opening formula from details closes that sheet first, sets the exact selected shade and opens the route. If already on `/formula`, it updates the current target without stacking another formula screen. Choosing/canceling a target never resets the separate Mixer or HSL draft. Search failures show friendly Retry and still allow choosing another target; outdated searches cannot replace a newer target's result.

No pigment chemistry, custom base palettes in UI, recipe/project persistence, full harmony wheel, games, medical tests or room-photo editing in this module. No new dependency, platform permission or storage schema.

## Search contract

Use twelve fixed named digital bases: Red#FF0000, Orange#FF8000, Yellow#FFFF00, Green#008000, Blue#0000FF, Violet#8000FF, White#FFFFFF, Black#000000, Yellow ochre#C99700, Burnt sienna#A0522D, Raw umber#826644 and Payne's gray#536878. Show their reference HEX values in the UI. These are illustrative display references, never brand/material pigment measurements.

Exhaustively enumerate every pair and triple of distinct bases with positive weights in5% increments summing100%. Include single-base100% endpoints, equivalent to zero-weight members of those pairs/triples. Default search has38,886 candidates:12 singles +66×19 pairs +220×171 triples. Use the existing LAB weighted blending contract; round/gamut-clamp through the existing display conversion. Rank each displayed RGB result by CIE76 between its D65 LAB and the target's LAB, so the shown error describes the shown swatch, including display rounding/gamut effects. Choose the strict minimum; equal errors keep the earlier candidate (singles before pairs before triples, stable palette/index/ascending weight order). A zero-error result may return early because no candidate can improve it.

Pure Dart owns validated immutable base/part/formula models and the deterministic exhaustive search. Formula parts are1–3 unique base IDs, each5–100% in5% steps, totaling100%. Result and error derive from those parts rather than accepting inconsistent metadata. Custom palettes exist only as a pure-function test/programming seam, not a new product feature.

An injected Flutter service runs the production search using compute in a worker isolate on Android/iOS. Riverpod keeps a session target and a target-keyed auto-disposed result FutureProvider. Separate keys prevent old completion/error from becoming a newer target's recipe; auto-disposal avoids accumulating results for every target. The UI does not run the exhaustive search during build. No unbounded global cache or persistent worker infrastructure.

Alternatives considered: continuous optimization would violate5% exhaustive pairs/triples; ideal unrounded LAB scoring could report an error inconsistent with the actual swatch. Exhaustive displayed-result scoring is selected for truthful output and exact search coverage, with worker execution protecting UI responsiveness.

## Verification

Test-first coverage includes endpoints, known LAB fixtures, a triple-only optimum, exact5% positive totals, full-grid optimality on a small palette, deterministic ties, immutable input snapshots and invalid palettes/recipes. Service tests cross an actual isolate; provider tests hold and reorder completions, inject errors/retry and verify session target lifetime. UI tests cover Lab/common-detail entry, correct initial target, actual picker cancel/change, async loading/failure/retry without stale output, result save/details/Room, first-run guards, retained existing drafts,360px/2x text/reduced motion and both themes. Review, full suite/analyzer/format, real-font previews, debug APK and a cumulative validated ZIP precede handoff. Physical-device/iOS execution is not implied by an APK build.
