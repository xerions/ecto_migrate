## v0.6.0

* Backwards incompatible changes
  * as ecto => 0.15.0 renames some fields in Ecto.Association.Has from `assoc` to `related`

## v0.5.0

* Backwards incompatible changes
  * as ecto => 0.14.0 generate __schema__(:type, field) instead of __schema__(:field, field)

## v0.4.1

* Enhancements
  * use ecto ~> 0.13.0

## v0.4.0

* Enhancements
  * allow defining more sources for the same model

* Backwards incompatible changes
  * use insert! update! as supported in ecto > 0.12.0, it is no more compatible with ecto < 0.12.0

## v0.3.2

* Enhancements
  * add more space for meta information
  * update meta information after migration run

## v0.3.1

* bump for using ecto 0.12.0-rc

## v0.3.0

* Backwards incompatible changes
  * use BIGINT type for primitive type integer

## v0.2.1

* Enhancements
  * Use try rescue for custom types, for the cases, where module may not be loaded(as in development)

## v0.2.0

* Backwards incompatible changes
  * types will be saved in native form, that changes from Ecto types doesn't try run migration

## v0.1.1

* Enhancements
  * Do not use `@derive [Access]` for structs

* Bug fixes
  * Allow setting of options for `belongs_to`-defined fields too

## v0.1.0

* Initial release
