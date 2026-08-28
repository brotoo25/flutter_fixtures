/// Generates sample payloads from OpenAPI schema nodes.
///
/// The internal seam under `OpenApiFixtureSource` (not exported from the
/// package): all schema-shaped knowledge — example-like keywords,
/// composition (`allOf`, `oneOf`/`anyOf`), typed placeholders, and
/// document-local `$ref` resolution — lives here, testable with bare
/// schema nodes instead of full specs.
class OpenApiSchemaSampler {
  OpenApiSchemaSampler(this.spec);

  /// The OpenAPI document `$ref`s are resolved against.
  final Map<String, dynamic> spec;

  /// Generates sample data from a schema: explicit example-like values win,
  /// then composition keywords, then a type-based placeholder. A `$ref`
  /// cycle yields `null`.
  Object? sample(Object? schemaNode) => _sample(schemaNode, const {});

  Object? _sample(Object? schemaNode, Set<String> seenRefs) {
    if (schemaNode is! Map) {
      return null;
    }
    var schema = schemaNode.cast<String, dynamic>();
    final ref = schema[r'$ref'];
    if (ref is String) {
      if (seenRefs.contains(ref)) {
        return null;
      }
      seenRefs = {...seenRefs, ref};
      final resolved = resolvePointer(ref);
      if (resolved is! Map) {
        return null;
      }
      schema = resolved.cast<String, dynamic>();
    }

    if (schema.containsKey('example')) {
      return schema['example'];
    }
    final examples = schema['examples'];
    if (examples is List && examples.isNotEmpty) {
      return examples.first;
    }
    if (schema.containsKey('const')) {
      return schema['const'];
    }
    if (schema.containsKey('default')) {
      return schema['default'];
    }
    final enumValues = schema['enum'];
    if (enumValues is List && enumValues.isNotEmpty) {
      return enumValues.first;
    }

    final allOf = schema['allOf'];
    if (allOf is List && allOf.isNotEmpty) {
      final merged = <String, dynamic>{};
      Object? nonObject;
      for (final sub in allOf) {
        final sample = _sample(sub, seenRefs);
        if (sample is Map) {
          merged.addAll(sample.cast<String, dynamic>());
        } else {
          nonObject ??= sample;
        }
      }
      return merged.isNotEmpty ? merged : nonObject;
    }
    for (final keyword in const ['oneOf', 'anyOf']) {
      final variants = schema[keyword];
      if (variants is List) {
        for (final sub in variants) {
          final sample = _sample(sub, seenRefs);
          if (sample != null) {
            return sample;
          }
        }
      }
    }

    switch (_primaryType(schema)) {
      case 'object':
        return _objectSample(schema, seenRefs);
      case 'array':
        final item = _sample(schema['items'], seenRefs);
        return item == null ? [] : [item];
      case 'string':
        return _stringSample(schema['format'] as String?);
      case 'integer':
        return 0;
      case 'number':
        return 0;
      case 'boolean':
        return true;
      default:
        return null;
    }
  }

  Map<String, dynamic> _objectSample(
    Map<String, dynamic> schema,
    Set<String> seenRefs,
  ) {
    final result = <String, dynamic>{};
    final properties = schema['properties'];
    if (properties is Map) {
      for (final entry in properties.entries) {
        result[entry.key.toString()] = _sample(entry.value, seenRefs);
      }
    }
    return result;
  }

  String _stringSample(String? format) {
    switch (format) {
      case 'date-time':
        return '2024-01-01T12:00:00Z';
      case 'date':
        return '2024-01-01';
      case 'time':
        return '12:00:00';
      case 'email':
        return 'user@example.com';
      case 'uuid':
        return '00000000-0000-4000-8000-000000000000';
      case 'uri':
      case 'url':
        return 'https://example.com';
      case 'hostname':
        return 'example.com';
      case 'ipv4':
        return '192.168.0.1';
      default:
        return 'string';
    }
  }

  String? _primaryType(Map<String, dynamic> schema) {
    final type = schema['type'];
    if (type is String) {
      return type;
    }
    // OpenAPI 3.1 allows a type array, e.g. ["string", "null"].
    if (type is List) {
      for (final t in type) {
        if (t is String && t != 'null') {
          return t;
        }
      }
    }
    if (schema['properties'] is Map) {
      return 'object';
    }
    if (schema['items'] is Map) {
      return 'array';
    }
    return null;
  }

  /// Resolves a document-local JSON Pointer (`#/...`) against [spec].
  Object? resolvePointer(String ref) {
    if (!ref.startsWith('#/')) {
      return null;
    }
    Object? node = spec;
    for (final rawKey in ref.substring(2).split('/')) {
      final key = rawKey.replaceAll('~1', '/').replaceAll('~0', '~');
      if (node is Map) {
        node = node[key];
      } else if (node is List) {
        final index = int.tryParse(key);
        node = (index != null && index >= 0 && index < node.length)
            ? node[index]
            : null;
      } else {
        return null;
      }
    }
    return node;
  }
}
