## [0.1.2] - February 16, 2021

* Added functionality to treat `null` keys as generic.

* Store all callbacks in a [Map] with the callback itself as a key, as callbacks that handle join-able objects have their callbacks modified and can't be identified in a [List].

* Fixed a bug preventing keys from being registered by [MergeableObjectMap]'s
[add] method when objects didn't need to be merged.

* Added the [] operator to [ObjectMap].

## [0.1.1] - February 13, 2021

* Added the [callback] argument to the [removeChangeCallback] and
[removeGlobalChangeCallback] methods.

## [0.1.0] - February 13, 2021

* Initial release.
