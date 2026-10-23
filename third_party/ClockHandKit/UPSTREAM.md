# ClockHandKit source pin

Source: https://github.com/giljihun/ClockHandKit
Commit: `6abf0d758b24af163d7bd12605f7d8b1d0f69572`
License: MIT (see LICENSE).

The source is kept byte-for-byte as reviewed, including the iOS 27 `honorIdealizedDate: false` payload fix. It is compiled only into the iOS widget extension and the dedicated cloud probes. No prebuilt third-party binary is included.

This uses the undocumented WidgetKit `_ClockHandRotationEffect` runtime type. This experimental dependency was explicitly approved by the user for real-time widget hands and the tourbillon. Runtime decoding and render cadence remain OS-dependent.
