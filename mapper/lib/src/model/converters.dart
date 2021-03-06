import 'dart:convert' show base64Decode, base64Encode;
import 'dart:convert' show JsonDecoder;
import 'dart:typed_data' show Uint8List;

import 'package:intl/intl.dart';

import 'annotations.dart';
import 'index.dart';

typedef SerializeObjectFunction = dynamic Function(Object object);
typedef DeserializeObjectFunction = dynamic Function(Object object, Type type);

/// Abstract class for custom converters implementations
abstract class ICustomConverter<T> {
  dynamic toJSON(T object, [JsonProperty jsonProperty]);
  T fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]);
}

/// Abstract class for custom iterable converters implementations
abstract class ICustomIterableConverter {
  void setIterableInstance(Iterable instance, TypeInfo typeInfo);
}

/// Abstract class for custom map converters implementations
abstract class ICustomMapConverter {
  void setMapInstance(Map instance, TypeInfo typeInfo);
}

/// Abstract class for custom Enum converters implementations
abstract class ICustomEnumConverter {
  void setEnumValues(Iterable enumValues);
}

/// Abstract class for custom recursive converters implementations
abstract class IRecursiveConverter {
  void setSerializeObjectFunction(SerializeObjectFunction serializeObject);
  void setDeserializeObjectFunction(
      DeserializeObjectFunction deserializeObject);
}

/// Base class for custom type converter having access to parameters provided
/// by the [JsonProperty] meta
class BaseCustomConverter {
  const BaseCustomConverter() : super();
  dynamic getConverterParameter(String name, [JsonProperty jsonProperty]) {
    return jsonProperty != null && jsonProperty.converterParams != null
        ? jsonProperty.converterParams[name]
        : null;
  }
}

const dateConverter = DateConverter();

/// Default converter for [DateTime] type
class DateConverter extends BaseCustomConverter implements ICustomConverter {
  const DateConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    final format = getDateFormat(jsonProperty);

    if (jsonValue is String) {
      return format != null
          ? format.parse(jsonValue)
          : DateTime.parse(jsonValue);
    }

    return jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    final format = getDateFormat(jsonProperty);
    return format != null && object != null && !(object is String)
        ? format.format(object)
        : (object is List)
            ? object.map((item) => item.toString()).toList()
            : object != null ? object.toString() : null;
  }

  DateFormat getDateFormat([JsonProperty jsonProperty]) {
    String format = getConverterParameter('format', jsonProperty);
    return format != null ? DateFormat(format) : null;
  }
}

const numberConverter = NumberConverter();

/// Default converter for [num] type
class NumberConverter extends BaseCustomConverter implements ICustomConverter {
  const NumberConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    final format = getNumberFormat(jsonProperty);
    return format != null && (jsonValue is String)
        ? getNumberFormat(jsonProperty).parse(jsonValue)
        : (jsonValue is String)
            ? num.tryParse(jsonValue) ?? jsonValue
            : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    final format = getNumberFormat(jsonProperty);
    return object != null && format != null
        ? getNumberFormat(jsonProperty).format(object)
        : (object is String) ? num.tryParse(object) : object;
  }

  NumberFormat getNumberFormat([JsonProperty jsonProperty]) {
    String format = getConverterParameter('format', jsonProperty);
    return format != null ? NumberFormat(format) : null;
  }
}

final annotatedEnumConverter = AnnotatedEnumConverter();

/// Annotated Enum instance converter
class AnnotatedEnumConverter implements ICustomConverter, ICustomEnumConverter {
  AnnotatedEnumConverter() : super();

  Iterable _enumValues = [];

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    final enumValues =
        (jsonProperty != null ? jsonProperty.enumValues : _enumValues);
    dynamic convert(value) =>
        enumValues.firstWhere((eValue) => eValue.toString() == value.toString(),
            orElse: () => null);
    return convert(
        jsonValue is String ? jsonValue.replaceAll('"', '') : jsonValue);
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) =>
      (object is! String) ? object.toString() : object;

  @override
  void setEnumValues(Iterable enumValues) {
    _enumValues = enumValues;
  }
}

const enumConverter = EnumConverter();

/// Default converter for [enum] type
class EnumConverter implements ICustomConverter {
  const EnumConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    dynamic convert(value) => jsonProperty.enumValues.firstWhere(
        (eValue) => eValue.toString() == value.toString(),
        orElse: () => null);
    return jsonValue is Iterable
        ? jsonValue.map(convert).toList()
        : convert(jsonValue);
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    dynamic convert(value) => value.toString();
    return (object is Iterable)
        ? object.map(convert).toList()
        : convert(object);
  }
}

const enumConverterShort = EnumConverterShort();

/// Short converter for [enum] type
class EnumConverterShort implements ICustomConverter {
  const EnumConverterShort() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    dynamic convert(value) => jsonProperty.enumValues.firstWhere(
        (eValue) =>
            eValue.toString().split('.').last ==
            value.toString().split('.').last,
        orElse: () => null);
    return jsonValue is Iterable
        ? jsonValue.map(convert).toList()
        : convert(jsonValue);
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    dynamic convert(value) => value.toString().split('.').last;
    return (object is Iterable)
        ? object.map(convert).toList()
        : convert(object);
  }
}

const enumConverterNumeric = EnumConverterNumeric();

/// Numeric index based converter for [enum] type
class EnumConverterNumeric implements ICustomConverter {
  const EnumConverterNumeric() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    return jsonValue is int ? jsonProperty.enumValues[jsonValue] : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    return jsonProperty.enumValues.indexOf(object);
  }
}

const symbolConverter = SymbolConverter();

/// Default converter for [Symbol] type
class SymbolConverter implements ICustomConverter {
  const SymbolConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    return jsonValue is String ? Symbol(jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    return object != null
        ? RegExp('"(.+)"').allMatches(object.toString()).first.group(1)
        : null;
  }
}

const uint8ListConverter = Uint8ListConverter();

/// [Uint8List] converter to base64 and back
class Uint8ListConverter implements ICustomConverter {
  const Uint8ListConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    return jsonValue is String ? base64Decode(jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    return object is Uint8List ? base64Encode(object) : object;
  }
}

const bigIntConverter = BigIntConverter();

/// [BigInt] converter
class BigIntConverter implements ICustomConverter {
  const BigIntConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    return jsonValue is String ? BigInt.parse(jsonValue) : jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    return object is BigInt ? object.toString() : object;
  }
}

final mapConverter = MapConverter();

/// [Map<K, V>] converter
class MapConverter
    implements ICustomConverter<Map>, IRecursiveConverter, ICustomMapConverter {
  MapConverter() : super();

  SerializeObjectFunction _serializeObject;
  DeserializeObjectFunction _deserializeObject;
  TypeInfo _typeInfo;
  Map _instance;
  final _jsonDecoder = JsonDecoder();

  dynamic from(item, Type type, JsonProperty jsonProperty) {
    var result;
    if (jsonProperty != null && jsonProperty.isEnumType(type)) {
      result = enumConverter.fromJSON(item, jsonProperty);
    } else {
      result = _deserializeObject(item, type);
    }
    return result;
  }

  dynamic to(item, JsonProperty jsonProperty) {
    var result;
    if (jsonProperty != null && jsonProperty.isEnumType(item.runtimeType)) {
      result = enumConverter.toJSON(item, jsonProperty);
    } else {
      result = _serializeObject(item);
    }
    return result;
  }

  @override
  Map fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    var result = jsonValue;
    if (jsonValue is String) {
      result = _jsonDecoder.convert(jsonValue);
    }
    if (_typeInfo != null && result is Map) {
      if (_instance != null && _instance is Map ||
          (_instance == null &&
              jsonProperty != null &&
              jsonProperty.enumValues != null) ||
          (_instance == null && jsonProperty == null)) {
        result = result.map((key, value) => MapEntry(
            from(key, _typeInfo.parameters.first, jsonProperty),
            from(value, _typeInfo.parameters.last, jsonProperty)));
      }
      if (_instance != null && _instance is Map) {
        result.forEach((key, value) => _instance[key] = value);
        result = _instance;
      }
    }
    return result;
  }

  @override
  dynamic toJSON(Map object, [JsonProperty jsonProperty]) =>
      object.map((key, value) =>
          MapEntry(to(key, jsonProperty).toString(), to(value, jsonProperty)));

  @override
  void setSerializeObjectFunction(SerializeObjectFunction serializeObject) {
    _serializeObject = serializeObject;
  }

  @override
  void setDeserializeObjectFunction(
      DeserializeObjectFunction deserializeObject) {
    _deserializeObject = deserializeObject;
  }

  @override
  void setMapInstance(Map instance, TypeInfo typeInfo) {
    _instance = instance;
    _typeInfo = typeInfo;
  }
}

final defaultIterableConverter = DefaultIterableConverter();

/// Default Iterable converter
class DefaultIterableConverter
    implements ICustomConverter, ICustomIterableConverter {
  DefaultIterableConverter() : super();

  Iterable _instance;

  @override
  dynamic fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    dynamic convert(item) =>
        jsonProperty != null && jsonProperty.enumValues != null
            ? enumConverter.fromJSON(item, jsonProperty)
            : item;
    if (_instance != null && jsonValue is Iterable && jsonValue != _instance) {
      if (_instance is List) {
        (_instance as List).clear();
        jsonValue.forEach((item) => (_instance as List).add(convert(item)));
      }
      if (_instance is Set) {
        (_instance as Set).clear();
        jsonValue.forEach((item) => (_instance as Set).add(convert(item)));
      }
      return _instance;
    }
    return jsonValue;
  }

  @override
  dynamic toJSON(dynamic object, [JsonProperty jsonProperty]) {
    return object;
  }

  @override
  void setIterableInstance(Iterable instance, TypeInfo typeInfo) {
    _instance = instance;
  }
}

const defaultConverter = DefaultConverter();

/// Default converter for all types
class DefaultConverter implements ICustomConverter {
  const DefaultConverter() : super();

  @override
  Object fromJSON(dynamic jsonValue, [JsonProperty jsonProperty]) {
    return jsonValue;
  }

  @override
  dynamic toJSON(Object object, [JsonProperty jsonProperty]) {
    return object;
  }
}
