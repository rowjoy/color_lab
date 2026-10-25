# Collapsible illustrated-room controls

## Intent

Make the illustrated-room editor comfortable on a portrait phone. The room
must be the main visual, while color tools remain obvious, reachable and easy
to dismiss. The current 68dp rail is always visible and the `Full room`
contain-fit option is easy to mistake for an immersive full-screen action.

## Approved approach

Use a collapsible overlay rail plus a separate Focus Preview mode.

- Below 720dp, the color rail starts hidden. A 48dp **Show color tools**
  control reveals it from the right without resizing the artwork.
- At 720dp and above, the rail starts visible. It can still be hidden and
  shown.
- The open rail has an explicit **Hide color tools** control. Hiding it also
  closes any open Looks/surface/Designs flyout.
- On a compact layout, tapping the scene or pressing system Back closes an
  open flyout/rail before attempting to leave the editor.
- A separate **Focus preview** action hides the back button, title, fit
  controls, rail and flyout. One safe-area **Exit focus preview** action stays
  available; system Back exits focus first. Exiting restores the rail state
  that existed before focus mode.
- Rename the existing fit choices to **Fill screen** and **See whole room**.
  They continue to mean `BoxFit.cover` and `BoxFit.contain`; focus mode does
  not silently change the user's fit choice.
- Rail visibility and focus state are editor-session UI state only. They are
  not saved with a room design and reset when a different room template is
  opened.

All controls remain overlays, so the SVG scene always owns the full viewport.
Animations use the existing reduced-motion-aware `AppMotion` duration.

## Accessibility and responsive behavior

- Show/hide and focus/exit controls have distinct semantic labels, selected
  state where relevant and at least 48dp touch targets.
- The rail remains scrollable at 2x text and on short landscape screens.
- Hidden controls are removed from hit testing and the semantics tree.
- Phone, 2x-text phone, short landscape and tablet layouts must not overflow.

## State and interaction order

1. Focus mode exits first.
2. An open flyout closes next.
3. A compact-layout rail opened by the user closes next.
4. Existing dirty-draft exit behavior then runs unchanged.

Gallery export, saved designs, color values, SVG rendering and dirty-draft
semantics are unchanged.

## Alternatives considered

- A bottom sheet improves thumb reach but covers the bottom of the room and
  requires a larger interaction rewrite.
- A permanently narrow/collapsed rail is simpler but still occupies the
  artwork and does not provide a distraction-free preview.

## Verification

Widget regressions will cover phone default-hidden/show/hide, tablet
default-visible/show/hide, scene-tap and Back ordering, focus enter/exit and
state restoration, fit labels/behavior, 2x text and short landscape. The
deterministic preview harness will capture phone rail hidden/open and Focus
Preview. No app/native build is part of this change.
