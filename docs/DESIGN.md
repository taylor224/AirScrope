# Interface guidelines

AirScope uses native macOS controls and a restrained visual system for working
with wireless measurements.

- Top-level pages: Overview, Nearby Networks, Signal History, Raw Data, Workspaces.
- Prioritize network names, measurements, and explicit user actions.
- Use system fonts, clear headings, generous section spacing, and compact data rows.
- Use blue for actions and selection. Keep plots and other surfaces neutral.
- Support light, dark, and system appearance, including readable chart annotations.
- Keep technical implementation labels and promotional copy out of the interface.
- Explain measurement terminology next to the controls where it is used.
- Edit scan settings in a stable sheet independent of live measurement updates.
- Label synthetic data and saved snapshots accurately. Never present sample data as a live scan.
- Keep raw protocol values intact; localize interface labels and explanations.

Theme tokens are defined in `Sources/WiFiAnalyzer/Theme.swift`.
