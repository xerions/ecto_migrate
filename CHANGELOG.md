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
