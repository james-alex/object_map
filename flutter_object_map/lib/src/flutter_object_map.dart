import 'package:flutter/widgets.dart';
import 'package:object_map/object_map.dart' as s;
import 'package:object_map/object_map.dart'
    show MergeableObject, JoinableObject, JoinMethod;

/// A 2-dimensional map of objects linked by a [Key] and [Type] with
/// methods to add, remove, retrieve objects from, and update the map.
class ObjectMap<T> extends s.ObjectMap<Key, T>
    with _GetObjectsByAncestorType<T> {}

/// A mixin provided to every class extending [ObjectMap] in this package
/// with methods that navigate a widgets' ancestor chains to identify
/// objects in the map with [Type]s corresponding to the widgets' ancestors.
mixin _GetObjectsByAncestorType<T> on s.ObjectMap<Key, T> {
  /// {@template flutter_object_map.ObjectMap.objects}
  ///
  /// Returns any [objects] in the map associated with the given [key] and
  /// a [Type] matching any ancestors of the provided [context].
  ///
  /// Objects are be returned in the order they are found, iterating over the
  /// ancestor chain, starting with the parent of the [context]'s widget.
  ///
  /// {@endtemplate}
  /// {@template flutter_object_map.ObjectMap.depth}
  ///
  /// Providing a [depth] limits the number of ancestors that will be visited
  /// when matching objects. __Note:__ If utilizing ancestor [Type]s to define
  /// objects, it's recommended to provide a [depth] to save resources, but
  /// keep in mind when setting the [depth] that many widgets wrap their
  /// children in multiple widgets, and the value provided to [depth] should
  /// account for that.
  ///
  /// {@endtemplate}
  /// {@template flutter_object_map.ObjectMap.limit}
  ///
  /// [limit] limits the number of objects that will be returned; If `null`
  /// there will be no limit on returned objects.
  ///
  /// {@endtemplate}
  ///
  /// If [includeDynamic] is `true`, and an object without an explicit [Type]
  /// exists (a [dynamic] typed object,) it will included at the end of the
  /// list.
  ///
  /// Returns `null` if no matching objects are found.
  List<T>? getObjectsByAncestorType(
    BuildContext context, {
    Key? key,
    int? depth,
    int? limit,
    bool includeDynamic = true,
    bool includeGeneric = false,
  }) {
    assert(depth == null || depth > 0);
    assert(limit == null || limit > 0);

    final foundObjects = <T>[];

    // Adds any objects associated with a `null` key to [foundObjects].
    void getGenericObjects() {
      final genericObjects = getObjectsByAncestorType(context,
          depth: depth, limit: limit, includeDynamic: includeDynamic);
      if (genericObjects != null) foundObjects.addAll(genericObjects);
    }

    // If there aren't any objects associated with key...
    if (!objects.containsKey(key)) {
      if (includeGeneric) {
        getGenericObjects();
        return foundObjects.isNotEmpty ? foundObjects : null;
      }
      return null;
    }

    final types = objects[key]!.keys.toList();

    // If the only type found was [dynamic], return the assocaited object.
    if (types.length == 1 && includeDynamic && types.first == dynamic) {
      foundObjects.add(objects[key]![dynamic] as T);

      if (includeGeneric && (limit == null || limit > 1)) {
        if (limit != null) limit--;
        getGenericObjects();
      }

      return foundObjects.isNotEmpty ? foundObjects : null;
    }

    // If there are any objects associated with any other types...
    if (types.isNotEmpty) {
      types.remove(dynamic);

      // Visit each ancestor, up to [depth] times removed.
      var currentDepth = 1;
      context.visitAncestorElements((element) {
        final object = matchAncestorElementByType(element, types,
            key: key, depth: currentDepth);

        // If an object with a matching type exists, add it to the list.
        if (object != null) {
          foundObjects.add(object);
          types.remove(element.widget.runtimeType);
        }

        if (types.isEmpty ||
            (depth != null && currentDepth == depth) ||
            (limit != null && foundObjects.length == limit)) {
          return false;
        }

        currentDepth++;

        return true;
      });

      // If [includeDynamic] is `true`, an object assocaited with a
      // [dynamic] type exists, and the [limit] hasn't been reached,
      // add it to the end of the list.
      if (includeDynamic &&
          (limit == null || foundObjects.length < limit) &&
          exists<dynamic>(key: key)) {
        foundObjects.add(objects[key]![dynamic] as T);
      }
    }

    // If [includeGeneric] is `true` and the [limit] hasn't been reached,
    // add any objects associated with a `null` key to the end of the list.
    if (includeGeneric && (limit == null || foundObjects.length < limit)) {
      if (limit != null) limit -= foundObjects.length;
      getGenericObjects();
    }

    return foundObjects.isNotEmpty ? foundObjects : null;
  }

  /// Checks if [element] matches any of the provided [types].
  ///
  /// If a [Type] was matched, the object in the map associated with the
  /// given [key] and matched [Type] will be returned, otherwise returns `null`.
  ///
  /// [depth] represents the position of the [element] in the ancestor chain;
  /// It is not utilized in the default implementation, but is provided for
  /// use by implementing classes.
  @protected
  T? matchAncestorElementByType(
    Element element,
    List<Type> types, {
    Key? key,
    int? depth,
  }) {
    assert(types.isNotEmpty && !types.contains(dynamic));

    if (exists(key: key)) {
      return null;
    }

    T? object;

    for (var type in types) {
      if (type == element.widget.runtimeType) {
        object = objects[key]![type];
        break;
      }
    }

    return object;
  }

  /// Iterates over [context]'s ancestor chain and returns the first object
  /// in the map found associated with [key] and a [Type] that matches an
  /// ancestors' exact [Type].
  ///
  /// {@macro flutter_object_map.ObjectMap.depth}
  ///
  /// If [includeDynamic] is `true` and no other matching objects were found,
  /// if an object without an explicit [Type] exists, a [dynamic] typed object,
  /// will be returned, otherwise `null` will be returnd.
  T? getObjectByAncestorType(
    BuildContext context, {
    Key? key,
    int? depth,
    bool includeDynamic = true,
    bool includeGeneric = false,
  }) {
    assert(depth == null || depth > 0);

    final object = getObjectsByAncestorType(
      context,
      key: key,
      depth: depth,
      limit: 1,
      includeDynamic: includeDynamic,
      includeGeneric: includeGeneric,
    );

    return object?.first;
  }
}

/// A 2-dimensional map of [MergeableObject]s linked by a [Key] and [Type]
/// with methods to add, remove, retrieve objects from, and update the map.
///
/// The objects stored in the map must extend or implement [MergeableObject],
/// which requires they have the method [merge] defined.
class MergeableObjectMap<T extends MergeableObject<T>>
    extends s.MergeableObjectMap<Key, T>
    with _GetObjectsByAncestorType<T>
    implements ObjectMap<T> {
  /// {@macro flutter_object_map.ObjectMap.objects}
  ///
  /// If [join] is `null`, the first object found will be returned, otherwise
  /// the objects will be [merge]d, with the values of the first objects found
  /// taking precedence over the values of the objects found after them.
  ///
  /// {@macro flutter_object_map.ObjectMap.depth}
  ///
  /// {@macro flutter_object_map.ObjectMap.limit}
  ///
  /// If [includeDynamic] is `true`, and an object without an explicit [Type]
  /// exists (a [dynamic] typed object,) it will be [merge]d into the returned
  /// object, or will be the only object returned if no other objects are
  /// found.
  ///
  /// Returns `null` if no matching objects are found.
  @override
  T? getObjectByAncestorType(
    BuildContext context, {
    Key? key,
    int? depth,
    int? limit,
    JoinMethod? join,
    bool includeDynamic = true,
    bool includeGeneric = false,
  }) {
    assert(depth == null || depth > 0);
    assert(limit == null || limit > 0);

    if (join == null) {
      return super.getObjectByAncestorType(
        context,
        key: key,
        depth: depth,
        includeDynamic: includeDynamic,
        includeGeneric: includeGeneric,
      );
    }

    final objects = getObjectsByAncestorType(
      context,
      key: key,
      depth: depth,
      limit: limit,
      includeDynamic: includeDynamic,
      includeGeneric: includeGeneric,
    );

    if (objects == null) {
      return null;
    }

    var mergedObject = objects.removeAt(0);

    for (var object in objects) {
      mergedObject = mergedObject.merge(object);
    }

    return mergedObject;
  }
}

/// A 2-dimensional map of [JoinableObject]s linked by a [Key] and [Type]
/// with methods to add, remove, retrieve objects from, and update the map.
///
/// The objects stored in the map must extend or implement [JoinableObject],
/// which requries they have the methods [merge] and [combine] defined.
class JoinableObjectMap<T extends JoinableObject<T>>
    extends s.JoinableObjectMap<Key, T>
    with _GetObjectsByAncestorType<T>
    implements MergeableObjectMap<T> {
  /// {@macro flutter_object_map.ObjectMap.objects}
  ///
  /// If [join] is `null`, the first object found will be returned, otherwise
  /// the objects will be [merge]d or [combine]d, with the values of the first
  /// objects found taking precedence over the values of the objects found
  /// after them.
  ///
  /// {@macro flutter_object_map.ObjectMap.depth}
  ///
  /// {@macro flutter_object_map.ObjectMap.limit}
  ///
  /// If [includeDynamic] is `true`, and an object without an explicit [Type]
  /// exists (a [dynamic] typed object,) it will be [merge]d or [combine]d
  /// into the returned object, or will be the only object returned if no
  /// other objects are found.
  ///
  /// Returns `null` if no matching objects are found.
  @override
  T? getObjectByAncestorType(
    BuildContext context, {
    Key? key,
    int? depth,
    int? limit,
    JoinMethod? join,
    bool includeDynamic = true,
    bool includeGeneric = false,
  }) {
    assert(depth == null || depth > 0);
    assert(limit == null || limit > 0);

    if (join == null) {
      return getObjectByAncestorType(
        context,
        key: key,
        depth: depth,
        includeDynamic: includeDynamic,
        includeGeneric: includeGeneric,
      );
    }

    final objects = getObjectsByAncestorType(
      context,
      key: key,
      depth: depth,
      limit: limit,
      includeDynamic: includeDynamic,
      includeGeneric: includeGeneric,
    );

    if (objects == null) {
      return null;
    }

    var joinedObject = objects.removeAt(0);

    for (var object in objects) {
      joinedObject = join == JoinMethod.merge
          ? joinedObject.merge(object)
          : joinedObject.combine(object);
    }

    return joinedObject;
  }
}
