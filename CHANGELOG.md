# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project tries to adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

...

## [0.4.0] - 2024-09-05

### Changed

* Allow passing options to all `move_to*` methods. This allows for options being passed to the `::with_advisory_lock` method. For example calling `move_to!(2, advisory_lock: { timeout_seconds: 30 })` will call `with_advisory_lock(lock_name, timeout_seconds: 30)`, changing the `timeout_seconds` option for this single advisory lock. ([#17](https://github.com/richardboehme/lexorank/pull/17))

## [0.3.0] - 2024-08-28

### Changed

* Raise an error if `nil` is passed for the `:field` option. ([#16](https://github.com/richardboehme/lexorank/pull/16))
* Calling `rank!` with an invalid column name, by either specifying the `:field` or `:group_by` option, will not issue a warning anymore. This also means the gem does not require an active database connection when loading classes. ([#16](https://github.com/richardboehme/lexorank/pull/16))

## [0.2.0] - 2024-08-16

### Major Changes

This version introduces **advisory locks**. Advisory locking is **automatically enabled** if your model class responds to `#with_advisory_lock` (ex. `User.with_advisory_lock`).

From now on the lexorank gem requires ruby version 3.1 or higher. This decision is based on ruby's end of life dates (3.0 went eol in April 2024).

All internal API methods that lexorank was using until 0.1.3 were moved to another location. If you rely on those (and you should not), have a look at the `Lexorank::Ranking` class. An instance of this class can be accessed via the `lexorank_ranking` attribute on your model class.

### Added

- Add advisory locks if the model class responds to `with_advisory_lock`
- Add `#move_to_end` and `#move_to_end!` to move a record to the end of a collection
- The CI now runs against multiple database adapters (sqlite, mysql, postgresql)

### Changed

- Blocks passed to all `move_to` methods will now be executed after the rank was assigned. When using advisory locks, the block will be executed while the lock is still active.
- When calling `#move_to` with a position that is larger than the number of records in the collection it will now be moved to the end of the list
- Require ruby version 3.1 or higher
- Moved Changelog from [README.md](https://github.com/richardboehme/lexorank/blob/main/README.md) to [CHANGELOG.md](https://github.com/richardboehme/lexorank/blob/main/CHANGELOG.md)

## [0.1.3] - 2021-07-16

### Added

- Add support to move elements into another group ([#5](https://github.com/richardboehme/lexorank/pull/5), by [@bookis](https://github.com/bookis))
- Add the `no_rank?` method ([#5](https://github.com/richardboehme/lexorank/pull/5), by [@bookis](https://github.com/bookis))

### Fixed

- Removed in-memory operations while trying to find records around the model that should be moved

## [0.1.2] - 2021-03-08

### Fixed

- Fixed gemspec to be valid

### Changed

- Updated Changelog format

## [0.1.1] - 2021-03-08

### Changed

- Updated license year

## [0.1.0] - 2021-03-08

*Initial Release*
