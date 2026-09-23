# Design System and UX Rules

> **Visual identity specification:** The full visual identity ("Diagram") is specified in `design/docs/`.
> See `design/README.md` for reading order. The prototype in `design/reference/index.html` is the visual
> source of truth — if this document and the design package disagree, the design package wins.
> This file retains the UX *principles* that predate the visual identity and remain valid.

## Design thesis

**Dogmatic minimalism.** Review is the product. The board is the primary interface.

## Main navigation

Avoid a conventional multi-tab application.

Preferred structure:

```text
Review
  + lightweight study selector
  + lightweight opening selector (when implemented)
  + minimal import/settings access
```

Selectors constrain Review; they are not destinations that compete with Review.

## First launch

If zero studies exist, show only the minimum necessary import experience.

Goal:

`launch -> import -> review`

## Review screen

Prioritize:

1. board
2. tiny amount of context
3. move interaction
4. subtle feedback

Do not surround the board with a dense control panel.

## Correct feedback

Immediate and quiet. Avoid celebratory overlays.

## Incorrect feedback

Immediate and informative. Avoid modal interruption. The user should quickly understand the intended repertoire move and continue.

## Automatic continuation

Known moves can animate/play naturally. Do not make automatic traversal feel like a separate mode.

## No mandatory completion screen

Do not add a session-complete page. Users simply stop reviewing.

When nothing is due, show a minimal idle state.

## Visual direction

Desired:

- restrained palette
- strong typography hierarchy
- generous whitespace
- minimal borders/shadows
- subtle motion
- high-quality chess pieces
- touch-friendly controls
- premium feel through spacing and consistency

Avoid:

- neon/esports styling
- heavy gradients
- excessive cards
- large green/red success banners
- XP/badges/leaderboards
- dashboard clutter

## Responsive behaviour

Mobile-first. The board should dominate the viewport.

Web may use additional whitespace/context but should preserve the same Review-first mental model.

Do not make desktop into a dashboard merely because more screen space exists.

## Accessibility

Maintain sufficient contrast, touch target sizes, keyboard support on web, and non-colour-only feedback where feasible.

## Motion

Animation should communicate chess state, not decorate it. Never allow animation to block the next user action unnecessarily.
