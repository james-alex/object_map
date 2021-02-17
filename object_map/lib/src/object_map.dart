/// A 2-dimensional map of objects linked by a key and [Type] with
/// methods to add, remove, retrieve objects from, and update the map.
class ObjectMap<K, T> {
  /// The private 2-dimensional map containing the stored objects.
  final Map<K, Map<Type, T>> objects = <K, Map<Type, T>>{};

  /// Returns `true` if the map contains the given [key].
  bool containsKey({K key}) => objects.containsKey(key);

  /// Returns `true` if the map contains an object associated
  /// with the given [key] and type ([R]).
  bool exists<R>({K key}) =>
      containsKey(key: key) && objects[key].containsKey(R);

  /// Returns the object in the map associated with the
  /// given [key] and type ([R]).
  T get<R>({K key}) => exists<R>(key: key) ? objects[key][R] : null;

  /// Adds [object] to the map linked to the given [key] and type ([R]).
  T add<R>(T object, {K key}) {
    final mapEntry = {R: object};

    // Add/update the object in the map.
    if (objects.containsKey(key)) {
      objects[key].addAll(mapEntry);
    } else {
      objects.addAll({key: mapEntry});
    }

    // Call any change callbacks with the new/updated object.
    _callChangeCallbacks<R>(object, key: key);

    return object;
  }

  /// Removes and returns the object associated with
  /// the given [key] and type ([R]).
  T remove<R>({K key}) {
    T removedObject;

    if (objects.containsKey(key)) {
      if (objects[key].containsKey(R)) {
        // Remove the object from the map, if it exists.
        removedObject = objects[key].remove(R);
        if (objects[key].isEmpty) objects.remove(key);

        // Provide any change callbacks with a `null` value.
        _callChangeCallbacks<R>(null, key: key);
      }
    }

    return removedObject;
  }

  /// The map containing every active change callback.
  final Map<K, Map<Type, Map<ObjectChanged<T>, ObjectChanged<T>>>>
      _changeCallbacks =
      <K, Map<Type, Map<ObjectChanged<T>, ObjectChanged<T>>>>{};

  /// Returns true if there are any change callbacks associated with
  /// the given [key] and type ([R]).
  bool hasChangeCallback<R>({K key}) =>
      _changeCallbacks.containsKey(key) && _changeCallbacks[key].containsKey(R);

  /// Registers a new change callback associated with the
  /// given [key] and type ([R]).
  void addChangeCallback<R>(ObjectChanged<T> callback, {K key}) {
    assert(callback != null);

    if (_changeCallbacks.containsKey(key)) {
      if (_changeCallbacks[key].containsKey(R)) {
        _changeCallbacks[key][R].addAll({callback: callback});
      } else {
        _changeCallbacks[key].addAll({
          R: {callback: callback},
        });
      }
    } else {
      _changeCallbacks.addAll({
        key: {
          R: {callback: callback},
        }
      });
    }
  }

  /// Removes the last added change callback associated with the
  /// given [key] and type ([R]).
  void removeChangeCallback<R>(ObjectChanged<T> callback, {K key}) {
    assert(callback != null);

    if (_changeCallbacks.containsKey(key)) {
      if (_changeCallbacks[key].containsKey(R)) {
        _changeCallbacks[key][R].remove(callback);
        if (_changeCallbacks[key][R].isEmpty) {
          _changeCallbacks[key].remove(R);
          if (_changeCallbacks[key].isEmpty) {
            _changeCallbacks.remove(key);
          }
        }
      }
    }
  }

  /// The map containing every active global change callback.
  final Map<K, List<ObjectChanged<T>>> _globalChangeCallbacks =
      <K, List<ObjectChanged<T>>>{};

  /// Registers a new global change callback with the given [key].
  ///
  /// Global callbacks are called when any object associated with the
  /// [key] is modified, regardless of the objects' associated [Type].
  void addGlobalChangeCallback(ObjectChanged<T> callback, {K key}) {
    assert(callback != null);

    if (_globalChangeCallbacks.containsKey(key)) {
      _globalChangeCallbacks[key].add(callback);
    } else {
      _globalChangeCallbacks.addAll({
        key: [callback],
      });
    }
  }

  /// Removes the last added global change callback associated
  /// with the given [key].
  void removeGlobalChangeCallback(ObjectChanged<T> callback, {K key}) {
    assert(callback != null);

    if (_globalChangeCallbacks.containsKey(key)) {
      _globalChangeCallbacks[key].remove(callback);
      if (_globalChangeCallbacks[key].isEmpty) {
        _globalChangeCallbacks.remove(key);
      }
    }
  }

  /// Calls any registered change callbacks associated with the
  /// given [key] and type ([R]), as well as any global change
  /// callbacks assocaited with the [key].
  void _callChangeCallbacks<R>(T object, {K key}) {
    // Call any associated explicitly typed callbacks.
    if (hasChangeCallback<R>(key: key)) {
      for (var callback in _changeCallbacks[key][R].values) {
        callback(object);
      }
    }

    // Call any registered global callbacks.
    if (_globalChangeCallbacks.containsKey(key)) {
      for (var callback in _globalChangeCallbacks[key]) {
        callback(object);
      }
    }
  }
}

/// A 2-dimensional map of [MergeableObject]s linked by a key and [Type]
/// with methods to add, remove, retrieve objects from, and update the map.
///
/// The objects stored in the map must extend or implement [MergeableObject],
/// which requires they have the method [merge] defined.
class MergeableObjectMap<K, T extends MergeableObject<T>>
    extends ObjectMap<K, T> {
  /// Returns the object in the map associated with the given [key]
  /// and type ([R]).
  ///
  /// If [joinDynamic] is provided and the given type ([R]) isn't [dynamic],
  /// the object in the map with the associated [key] and a [dynamic] type
  /// will be [merge]d with the returned object, if a [dynamic] typed object
  /// exists.
  @override
  T get<R>({K key, JoinMethod joinDynamic}) {
    var object = super.get<R>(key: key);

    if (R != dynamic && joinDynamic != null && exists<dynamic>(key: key)) {
      object = object.merge(super.get<dynamic>(key: key));
    }

    return object;
  }

  /// Adds [object] to the map linked to the given [key] and type ([R]).
  ///
  /// If [join] is provided, the [object] will be [merge]d with the object
  /// in the map that's already associated with the given [key] and type
  /// ([R]), if one exists. If `null`, the new [object] will overwrite the
  /// existing object.
  @override
  T add<R>(T object, {K key, JoinMethod join}) {
    assert(object != null);

    if (join != null) {
      return merge<R>(object, key: key);
    }

    return super.add<R>(object, key: key);
  }

  /// Merges [object] into the existing object with the associated [key]
  /// and type ([R]) by replacing it with a new object returned the
  /// [object]'s [merge] method.
  ///
  /// If no object exists with the associated [key] and type ([R]),
  /// the [object] will be [add]ed to the map.
  T merge<R>(T object, {K key}) {
    assert(object != null);

    if (exists<R>(key: key)) {
      // Merge the existing object into the new [object].
      final mergedObject = object.merge(objects[key][R]);
      objects[key][R] = mergedObject;

      // Provide any associated change callbacks with the merged object.
      _callChangeCallbacks<R>(mergedObject, key: key);

      return mergedObject;
    }

    return add<R>(object, key: key);
  }

  /// Registers a new change callback associated with the
  /// given [key] and type ([R]).
  ///
  /// If [joinDynamic] isn't `null` and [R] isn't [dynamic], the object
  /// provided to [callback] will be [merge]d with the object associated
  /// with the given [key] and a [dynamic] type ([R]).
  @override
  void addChangeCallback<R>(
    ObjectChanged<T> callback, {
    K key,
    JoinMethod joinDynamic,
  }) {
    assert(callback != null);

    if (joinDynamic != null) {
      callback = (object) {
        if (exists<dynamic>(key: key)) {
          final dynamicObject =
              get<dynamic>(key: key, joinDynamic: joinDynamic);
          callback(object.merge(dynamicObject));
        }
      };
    }

    super.addChangeCallback<R>(callback, key: key);
  }

  /// Retrieves the map of objects associated with [key].
  Map<Type, T> operator [](K key) => objects[key];
}

/// The base class for objects that can be stored in a [MergeableObjectMap].
abstract class MergeableObject<T> {
  const MergeableObject({this.inherit = true});

  /// Merges [other] into `this` by returning a new object containing
  /// `this` object's values where any `null` values inherit [other]'s
  /// values.
  T merge(T other);

  /// If `false`, objects will not be merged into `this` object, but
  /// `this` object may still be merged into other objects.
  final bool inherit;
}

/// A 2-dimensional map of [JoinableObject]s linked by a key and [Type]
/// with methods to add, remove, retrieve objects from, and update the map.
///
/// The objects stored in the map must extend or implement [JoinableObject],
/// which requries they have the methods [merge] and [combine] defined.
class JoinableObjectMap<K, T extends JoinableObject<T>>
    extends MergeableObjectMap<K, T> {
  /// Returns the object in the map associated with the given [key]
  /// and type ([R]).
  ///
  /// If [joinDynamic] is provided and the given type ([R]) isn't [dynamic],
  /// the object in the map with the assocated [key] and a [dynamic] type
  /// will be [merge]d or [combine]d with the returned object, if a [dynamic]
  /// typed object exists.
  @override
  T get<R>({K key, JoinMethod joinDynamic}) {
    var object = super.get<R>(key: key);

    if (R != dynamic && joinDynamic != null && exists<dynamic>(key: key)) {
      if (joinDynamic == JoinMethod.merge) {
        object = object.merge(super.get<dynamic>(key: key));
      } else {
        object = object.combine(super.get<dynamic>(key: key));
      }
    }

    return object;
  }

  /// Adds [object] to the map linked to the given [key] and type ([R]).
  ///
  /// If [join] is provided, the [object] will be [merge]d or [combine]d with
  /// the object in the map that's currently associated with the given [key] and
  /// type ([R]), if it exists. If `null`, the new [object] will overwrite
  /// the existing object.
  @override
  T add<R>(T object, {K key, JoinMethod join}) {
    assert(object != null);

    if (join == JoinMethod.merge) {
      return merge<R>(object, key: key);
    }

    if (join == JoinMethod.combine) {
      return combine<R>(object, key: key);
    }

    return super.add<R>(object, key: key);
  }

  /// Combines [object] into the existing object with the associated [key]
  /// and type ([R]) by replacing it with a new object returned by the
  /// [object]'s [combine] method.
  ///
  /// If no object exists with the associated [key] and type ([R]),
  /// the [object] will be [add]ed to the map.
  T combine<R>(T object, {K key}) {
    assert(object != null);

    if (exists<R>(key: key)) {
      // Combine the existing object with the new [object].
      final combinedObject = object.combine(objects[key][R]);
      objects[key][R] = combinedObject;

      // Provide any associateed change callbacks with the combined object.
      _callChangeCallbacks<R>(combinedObject, key: key);

      return combinedObject;
    }

    return add<R>(object, key: key);
  }

  /// Registers a new change callback associated with the
  /// given [key] and type ([R]).
  ///
  /// If [joinDynamic] isn't `null` and [R] isn't [dynamic], the object
  /// provided to [callback] will be [merge]d or [combine]d with the object
  /// associated with the given [key] and a [dynamic] type ([R]).
  @override
  void addChangeCallback<R>(
    ObjectChanged<T> callback, {
    K key,
    JoinMethod joinDynamic,
  }) {
    assert(callback != null);

    if (joinDynamic != null) {
      callback = (object) {
        if (exists<dynamic>(key: key)) {
          final dynamicObject =
              get<dynamic>(key: key, joinDynamic: joinDynamic);
          final joinedObject = joinDynamic == JoinMethod.merge
              ? object.merge(dynamicObject)
              : object.combine(dynamicObject);

          callback(joinedObject);
        }
      };
    }

    super.addChangeCallback<R>(callback, key: key);
  }
}

/// The base class for methods that can be stored in a [JoinableObjectMap].
///
/// [JoinableObject]s can also be stored in a [MergeableObjectMap].
abstract class JoinableObject<T> extends MergeableObject<T> {
  const JoinableObject({bool inherit = true}) : super(inherit: inherit);

  /// Combines [other] into `this` by returning a new object with values
  /// that contain both the values of `this` and other.
  T combine(T other);
}

/// The method used to join objects in a [JoinableObjectMap].
///
/// When provided to a [MergeableObjectMap], the [merge] method will
/// be used regardless of the value provided, as [MergableObject]s
/// don't have a [combine] method.
///
/// When a [JoinMethod] is provided as `null` the new object will replace the
/// original object outright, without copying/inheriting any of its values.
enum JoinMethod {
  /// Objects will be joined by the [combine] method, which maintains both
  /// the original and the new values by combining them into a new value.
  combine,

  /// Objects will be joined by the [merge] method, which inserts the
  /// existing object's values into the new object's `null` values.
  merge,
}

/// A callback called when an object in an [ObjectMap] has changed.
typedef ObjectChanged<T> = void Function(T object);
