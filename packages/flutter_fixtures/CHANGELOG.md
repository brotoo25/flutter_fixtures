# Changelog

## 0.1.4 Bump dependency constraints

* Update meta-package dependencies: flutter_fixtures_core ^0.1.2, flutter_fixtures_dio ^0.1.2.

## 0.1.3 Bump dependency constraints

* Update meta-package dependencies: flutter_fixtures_core ^0.1.1, flutter_fixtures_ui ^0.1.2.

## 0.1.2 Bump dependency constraints

* Update meta-package dependencies: flutter_fixtures_dio ^0.1.1, flutter_fixtures_ui ^0.1.1.

## 0.1.1 Align with dio/ui 0.1.1

* Bump meta-package version; no code changes.
* Depends on flutter_fixtures_dio and flutter_fixtures_ui compatible with 0.1.1.

## 0.1.0 - First Minor Release

* Updated all packages to version 0.1.0
* Renamed `Fixture` mixin to `FixtureSelector` for better clarity
* Improved documentation across all packages
* Added comprehensive CONTRIBUTING.md guide
* Added MIT License
* Updated GitHub repository references to brotoo25/flutter_fixtures

## 0.0.1 - Initial Release

* Initial release of Flutter Fixtures
* Restructured as a workspace with multiple packages:
  * flutter_fixtures_core: Core interfaces and domain models
  * flutter_fixtures_dio: Dio implementation
  * flutter_fixtures_ui: UI components
  * flutter_fixtures: Meta-package that depends on all the above
* Support for Dio HTTP client
* Three fixture selection modes: Random, Default, and Pick
* Dialog-based UI for user selection
* Example app demonstrating basic and advanced usage
