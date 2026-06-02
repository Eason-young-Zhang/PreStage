# UI And Interaction Spec / 界面与交互规格

Last updated: 2026-05-26

## Main Window Layout

The Windows UI should preserve the macOS app's working layout:

```text
Toolbar
  Copy | Copy Settings | Share/Export | More | Search

Left Sidebar
  Camera card status
  Source folder
  Source child folders
  Target folder
  Target child folders
  Filters

Main Browser
  Header: title, visible count, view mode, sort direction, sort field
  Content: grid/list/gallery

Right Inspector
  Preview metadata
  Rating
  Pick state
  Color labels
  Scopes
  EXIF details

Bottom Gallery Area
  Tool strip: histogram, waveform, guides, crop, rotate/flip
  Filmstrip
```

## Visual Style

- Work-focused and dense.
- Dark mode should be excellent.
- Neutral backgrounds: black, white, dark gray, middle gray, light gray, system.
- Avoid marketing-style cards and decorative hero layouts.
- Use clear icon buttons.
- Repeated file items can be card-like, but no nested decorative cards.

## View Modes

### Grid/Icon View

- Adaptive thumbnail grid.
- RAW+JPEG collapsed stack display.
- Rating/Pick/color visible.
- Space opens preview.
- Direction keys move selection.
- Cmd/Ctrl+A equivalent selects visible files.

### List View

- Rows with small thumbnail and metadata columns.
- Sort indicators.
- Same selection and shortcut behavior.

### Gallery View

- Main image preview.
- Right inspector.
- Bottom filmstrip.
- Filmstrip item frames must match actual thumbnail image aspect ratio.
- Crop masks/guides must match actual rendered image rect.

## Keyboard Shortcuts

Windows equivalents can use Ctrl instead of Cmd:

- Ctrl+A: select visible.
- Esc: clear selection or close transient UI.
- Space: preview.
- Ctrl+1/2/3: view modes.
- 0-5: rating.
- P: Pick.
- X: Reject.
- U: Unmarked.
- Arrow keys: navigate.
- Delete: reject or remove depending on context, but avoid destructive delete by default.

## Crop And Guide Behavior

- Guides: thirds, center, diagonals, golden ratio.
- Crop ratios: hidden, original, 1:1, 4:3, 3:2, 16:9, 5:4, 9:16, custom.
- Crop style: mask or frame.
- Mask must be built from independent rectangles with a small outward bleed.
- Lines should be thin and low distraction.

## Scopes

- Histogram and waveform should support floating and inspector placement.
- Floating panels should be draggable, resizable, and constrained inside preview bounds.
- Light mode readability must be explicitly tested.

## Copy Settings

The copy button should be visually close to copy settings. macOS moved copy settings out of the sidebar because distance made the workflow feel disconnected. Preserve this principle.

## Review Environment

Settings should include:

- App appearance: system, light, dark.
- Preview background: system, black, white, dark gray, middle gray, light gray.
- Review matte: none, small, medium, large.

Soft proofing is planned but should be implemented later with an explicit color-managed render path.
