# V29 — Stable destination keyboard fix

## Main fix
Destination fields no longer use SwiftUI `TextField` + `FocusState`.
They now use a UIKit-backed `UITextField` (`StableTextField`) so model/location/autocomplete redraws do not make the field lose first responder and collapse the keyboard.

## Additional stability changes
- Replaced `LazyVStack` with normal `VStack` for the maximum six destination rows, preventing lazy row recycling while typing.
- Home ignores keyboard safe-area relayout to keep the route card hierarchy stable.
- Destination rows are still identified by UUID.
- Autocomplete stays enabled.
- Keyboard is intentionally dismissed only when the user presses Return, selects a suggestion, starts the route, or leaves the field normally.
