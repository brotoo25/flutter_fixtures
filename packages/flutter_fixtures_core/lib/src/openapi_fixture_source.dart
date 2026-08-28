import 'dart:convert';

import 'fixture_asset_loader.dart';
import 'fixture_collection.dart';
import 'fixture_document.dart';
import 'http_fixture_source.dart';

/// Builds fixture collections from an OpenAPI 3.x JSON document.
///
/// [resolve] matches the request's method and path against the spec's `paths`
/// (handling `{param}` templates and `servers` base paths) and returns a
/// [FixtureCollection]: the operation's documentation names the collection,
/// and each response — status code, description, and payload examples (or a
/// schema-generated sample) — becomes a selectable document. Callers should
/// prefer hand-written fixtures; this source is the generated fallback.
///
/// A spec that cannot be loaded or holds malformed JSON fails loudly: the
/// spec was explicitly configured, so a broken spec reports as broken
/// instead of as "no fixture found".
class OpenApiFixtureSource implements HttpFixtureSource {
  /// The asset path of the OpenAPI JSON document.
  final String specPath;

  /// The seam used to read the spec file.
  final FixtureAssetLoader assetLoader;

  Map<String, dynamic>? _cachedSpec;

  OpenApiFixtureSource({
    required this.specPath,
    this.assetLoader = const BundleAssetLoader(),
  });

  @override
  Future<FixtureCollection?> resolve(HttpFixtureRequest request) async {
    final method = request.method;
    final spec = await _loadSpec();
    final paths = spec['paths'];
    if (paths is! Map) {
      return null;
    }
    for (final requestPath in _candidatePaths(spec, request.path)) {
      // Concrete paths win over templated ones (e.g. /users/me over
      // /users/{id}), regardless of their order in the spec.
      for (final exactOnly in [true, false]) {
        for (final entry in paths.entries) {
          final template = entry.key.toString();
          if (entry.value is! Map ||
              template.contains('{') == exactOnly ||
              !_templateMatches(template, requestPath)) {
            continue;
          }
          final pathItem =
              _deref(spec, (entry.value as Map).cast<String, dynamic>());
          final operation = pathItem[method.toLowerCase()];
          if (operation is Map) {
            return _buildCollection(
              spec,
              operation.cast<String, dynamic>(),
              method,
              template,
            );
          }
        }
      }
    }
    return null;
  }

  @override
  Future<Object?> data(FixtureDocument document) async {
    // Spec-derived documents always carry their payload inline.
    return document.data;
  }

  Future<Map<String, dynamic>> _loadSpec() async {
    final cached = _cachedSpec;
    if (cached != null) {
      return cached;
    }
    final String content;
    try {
      content = await assetLoader.load(specPath);
    } catch (e) {
      throw StateError('OpenAPI spec "$specPath" could not be loaded: $e');
    }
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw FormatException('OpenAPI spec "$specPath" is not a JSON object.');
    }
    return _cachedSpec = decoded.cast<String, dynamic>();
  }

  /// The request paths to try: as given (query string dropped), plus with
  /// each `servers` base path stripped.
  List<String> _candidatePaths(Map<String, dynamic> spec, String rawPath) {
    var path = rawPath.split('?').first;
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) {
      // An absolute request URL — only its path can match the spec.
      path = parsed.path;
    }
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    final candidates = <String>[path];
    final servers = spec['servers'];
    if (servers is List) {
      for (final server in servers) {
        if (server is! Map) continue;
        final url = server['url'];
        if (url is! String) continue;
        var base = Uri.tryParse(url)?.path ?? '';
        if (base.endsWith('/')) {
          base = base.substring(0, base.length - 1);
        }
        if (base.isEmpty) continue;
        if (path.startsWith('$base/')) {
          candidates.add(path.substring(base.length));
        }
      }
    }
    return candidates;
  }

  bool _templateMatches(String template, String path) {
    List<String> segments(String p) =>
        p.split('/').where((s) => s.isNotEmpty).toList();

    final templateSegments = segments(template);
    final pathSegments = segments(path);
    if (templateSegments.length != pathSegments.length) {
      return false;
    }
    for (var i = 0; i < templateSegments.length; i++) {
      final t = templateSegments[i];
      final isParam = t.startsWith('{') && t.endsWith('}');
      if (!isParam && t != pathSegments[i]) {
        return false;
      }
    }
    return true;
  }

  FixtureCollection _buildCollection(
    Map<String, dynamic> spec,
    Map<String, dynamic> operation,
    String method,
    String template,
  ) {
    final summary = (operation['summary'] as String?)?.trim();
    final description = (summary != null && summary.isNotEmpty)
        ? summary
        : (operation['operationId'] as String?) ??
            '${method.toUpperCase()} $template';

    final drafts = <_DocumentDraft>[];
    final responses = operation['responses'];
    if (responses is Map) {
      for (final entry in responses.entries) {
        final code = _statusCodeFor(entry.key.toString());
        if (code == null || entry.value is! Map) continue;
        final response =
            _deref(spec, (entry.value as Map).cast<String, dynamic>());
        drafts.addAll(_documentsFor(spec, code, response));
      }
    }
    _uniquifyIdentifiers(drafts);
    final defaultIndex = _defaultIndex(drafts);
    return FixtureCollection(
      description: description,
      items: [
        for (var i = 0; i < drafts.length; i++)
          drafts[i].toDocument(defaultOption: i == defaultIndex),
      ],
    );
  }

  /// Numeric keys as-is, `2XX`-style ranges as their first code, and
  /// `default` (conventionally the catch-all error) as 500.
  int? _statusCodeFor(String key) {
    if (RegExp(r'^\d{3}$').hasMatch(key)) {
      return int.parse(key);
    }
    final range = RegExp(r'^([1-5])XX$', caseSensitive: false).firstMatch(key);
    if (range != null) {
      return int.parse(range.group(1)!) * 100;
    }
    if (key == 'default') {
      return 500;
    }
    return null;
  }

  /// One document per named example, or a single document from the inline
  /// example, the schema example, or a schema-generated sample.
  List<_DocumentDraft> _documentsFor(
    Map<String, dynamic> spec,
    int code,
    Map<String, dynamic> response,
  ) {
    final responseDescription = (response['description'] as String?)?.trim();
    final hasDescription =
        responseDescription != null && responseDescription.isNotEmpty;
    final documentDescription =
        hasDescription ? '$code $responseDescription' : '$code';
    final fallbackIdentifier =
        hasDescription ? responseDescription : 'Response $code';

    _DocumentDraft draft(String identifier, Object? data) => _DocumentDraft(
          code: code,
          identifier: identifier,
          description: documentDescription,
          data: data,
        );

    final mediaType = _jsonContent(spec, response['content']);
    if (mediaType == null) {
      // No body documented (e.g. 204) — still a selectable outcome.
      return [draft(fallbackIdentifier, null)];
    }

    final namedExamples = mediaType['examples'];
    if (namedExamples is Map && namedExamples.isNotEmpty) {
      final drafts = <_DocumentDraft>[];
      for (final entry in namedExamples.entries) {
        if (entry.value is! Map) continue;
        final example =
            _deref(spec, (entry.value as Map).cast<String, dynamic>());
        final summary = (example['summary'] as String?)?.trim();
        drafts.add(draft(
          (summary != null && summary.isNotEmpty)
              ? summary
              : entry.key.toString(),
          example['value'],
        ));
      }
      if (drafts.isNotEmpty) {
        return drafts;
      }
    }

    if (mediaType.containsKey('example')) {
      return [draft(fallbackIdentifier, mediaType['example'])];
    }

    final sample = _sampleFromSchema(spec, mediaType['schema'], const {});
    return [draft(fallbackIdentifier, sample)];
  }

  /// Picks the JSON media type from a response's `content` map, falling
  /// back to the first entry.
  Map<String, dynamic>? _jsonContent(
    Map<String, dynamic> spec,
    Object? content,
  ) {
    if (content is! Map || content.isEmpty) {
      return null;
    }
    MapEntry? chosen;
    for (final entry in content.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key.startsWith('application/json') || key.contains('+json')) {
        chosen = entry;
        break;
      }
    }
    chosen ??= content.entries.first;
    final value = chosen.value;
    if (value is! Map) {
      return null;
    }
    return _deref(spec, value.cast<String, dynamic>());
  }

  /// Generates sample data from a schema: explicit example-like values win,
  /// then composition keywords, then a type-based placeholder. [seenRefs]
  /// cuts `$ref` cycles (a cycle yields `null`).
  Object? _sampleFromSchema(
    Map<String, dynamic> spec,
    Object? schemaNode,
    Set<String> seenRefs,
  ) {
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
      final resolved = _resolvePointer(spec, ref);
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
        final sample = _sampleFromSchema(spec, sub, seenRefs);
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
          final sample = _sampleFromSchema(spec, sub, seenRefs);
          if (sample != null) {
            return sample;
          }
        }
      }
    }

    switch (_primaryType(schema)) {
      case 'object':
        return _objectSample(spec, schema, seenRefs);
      case 'array':
        final item = _sampleFromSchema(spec, schema['items'], seenRefs);
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
    Map<String, dynamic> spec,
    Map<String, dynamic> schema,
    Set<String> seenRefs,
  ) {
    final result = <String, dynamic>{};
    final properties = schema['properties'];
    if (properties is Map) {
      for (final entry in properties.entries) {
        result[entry.key.toString()] =
            _sampleFromSchema(spec, entry.value, seenRefs);
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

  /// Follows document-local `$ref`s on [node] until a concrete object is
  /// reached.
  Map<String, dynamic> _deref(
    Map<String, dynamic> spec,
    Map<String, dynamic> node,
  ) {
    var current = node;
    final seen = <String>{};
    while (true) {
      final ref = current[r'$ref'];
      if (ref is! String || !seen.add(ref)) {
        return current;
      }
      final resolved = _resolvePointer(spec, ref);
      if (resolved is! Map) {
        return current;
      }
      current = resolved.cast<String, dynamic>();
    }
  }

  Object? _resolvePointer(Map<String, dynamic> spec, String ref) {
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

  /// Suffixes repeated identifiers (`"Error (2)"`) so every document stays
  /// individually addressable.
  void _uniquifyIdentifiers(List<_DocumentDraft> drafts) {
    final counts = <String, int>{};
    for (final draft in drafts) {
      final identifier = draft.identifier;
      final count = counts[identifier] = (counts[identifier] ?? 0) + 1;
      if (count > 1) {
        draft.identifier = '$identifier ($count)';
      }
    }
  }

  /// The index of the default document: the first 2xx, or the first overall.
  int _defaultIndex(List<_DocumentDraft> drafts) {
    final index = drafts.indexWhere((d) => d.code >= 200 && d.code < 300);
    return index < 0 ? 0 : index;
  }
}

/// A document under construction, keeping the response's status [code] bound
/// to its content so default marking cannot drift to another document.
class _DocumentDraft {
  _DocumentDraft({
    required this.code,
    required this.identifier,
    required this.description,
    required this.data,
  });

  final int code;
  String identifier;
  final String description;
  final Object? data;

  FixtureDocument toDocument({required bool defaultOption}) => FixtureDocument(
        identifier: identifier,
        description: description,
        defaultOption: defaultOption,
        data: data,
      );
}
