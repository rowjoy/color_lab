# Trending living-room palettes

## Intent

Add the five numbered living-room colour combinations from the supplied page as
built-in app choices, while preserving the three existing living-room looks.
This gives the user eight selectable living-room presets without changing how a
new room opens.

## Goals

- Append the five source combinations in their PDF order.
- Use generic combination names and colour previews only. Do not display or
  store the paint brand, manufacturer shade names, or shade codes.
- Remove the manufacturer-specific shade-family names and codes currently used
  by the three existing looks' provenance, without changing their colours.
- Preserve all existing room palettes, saved designs, and the grayscale initial
  editor state.
- Make the new presets available automatically as app-bundled defaults; no
  first-run database seeding or migration is required.

## Non-goals and anti-goals

- Do not replace or reorder the existing three looks.
- Do not auto-apply a colour when the living-room editor opens.
- Do not modify bedroom, study, dining, kitchen, or bathroom palettes.
- Do not claim the sampled display colours are official paint specifications.
- Do not leave or add paint-brand names, proprietary shade names, or
  manufacturer codes in the app catalog, guidance, provenance, or interface.
- Do not overwrite any design the user has already saved in Hive.

## Constraints

- `IllustratedRoomPalette` requires four colours: wall, ceiling, floor, and
  furniture. Each source combination supplies only two visible colour swatches.
- The two PDF swatches will therefore be used as wall and furniture/accent
  colours. The existing living-room neutral ceiling (`#F8F4EB`) and floor
  (`#C5AD8A`) companions will complete each preview.
- Source swatches are screen-sampled from the supplied raster PDF and are
  approximate previews, subject to the app's existing physical-swatch warning.

## Source palettes

| Built-in ID | Display name | Wall colour | Furniture/accent colour |
| --- | --- | --- | --- |
| `soft-pink-earthy-neutrals` | Soft Pink with Earthy Neutrals | `#E5C8BE` | `#E1CCB7` |
| `coral-peach-layers` | Coral and Peach Layers | `#E49473` | `#F1BAA2` |
| `white-gentle-grey` | White with Gentle Grey | `#C8C8C6` | `#E8E6E2` |
| `pink-lavender-pairing` | Pink and Lavender Pairing | `#DFCAC9` | `#D4C9CF` |
| `peach-coral-glow` | Peach and Coral Glow | `#F1B89B` | `#EDA28E` |

The palette guidance will briefly describe the mood shown by the source page.
Provenance will say only that the approximate display colours were sampled from
the supplied living-room inspiration page.

## Approaches considered

1. Replace the existing three looks with the five source combinations. This is
   compact but removes current app choices.
2. **Selected:** keep the existing three and append all five page-inspired
   combinations. This preserves compatibility and provides the requested colour
   choices, at the cost of a longer list.
3. Replace the list and auto-apply the first source combination on entry. This
   changes the clean grayscale baseline, save eligibility, and exit behaviour,
   which the user did not select.

## Implementation and verification

- Extend only the living-room catalog data and palette metadata switches.
- Update copy that currently says there are exactly three complete looks so it
  remains correct with eight.
- Add domain assertions for order, exact sampled colours, generic metadata, the
  absence of brand/shade-code text, and the unchanged existing/default palettes.
- Add or update a widget test proving a newly appended look can be selected.
- Run Dart formatting, static analysis, targeted Room Studio tests, then the
  full Flutter test suite if practical.
