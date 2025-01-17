/**
    {
        "api":1,
        "name":"Dart JSON to Model",
        "description":"Converts JSON into a Dart model class",
        "author":"DuyNT",
        "icon":"table",
        "tags":"json,dart,model,convert"
    }
**/

function main(input) {
  const json = input.text;

  // Generate Dart model using quicktype-core
  const dartModel = convertJsonToDart(json, "RootModel");

  input.text = dartModel;
}

function convertJsonToDart(json, className) {
  // If input is a JSON string, parse it into a JavaScript object
  if (typeof json === "string") {
    try {
      json = JSON.parse(json); // Parse the string into an object
    } catch (e) {
      throw new Error("Invalid JSON string.");
    }
  }

  // Check if the parsed or input json is a valid JavaScript object
  if (typeof json !== "object" || json === null) {
    throw new Error("Input must be a valid JSON object.");
  }

  const fields = Object.keys(json)
    .map((key) => {
      // Skip invalid or numeric keys
      if (!key || !isNaN(key)) return;

      // Treat the key as a valid Dart variable name
      const safeKey = sanitizeKey(key);
      const type = getDartType(json[key], key);
      return `  ${type} ${safeKey};`;
    })
    .filter(Boolean) // Filter out undefined fields
    .join("\n");

  const constructorFields = Object.keys(json)
    .map((key) => {
      // Skip invalid or numeric keys
      if (!key || !isNaN(key)) return;

      const safeKey = sanitizeKey(key);
      return `    this.${safeKey},`;
    })
    .filter(Boolean)
    .join("\n");

  const factoryFields = Object.keys(json)
    .map((key) => {
      // Skip invalid or numeric keys
      if (!key || !isNaN(key)) return;

      const safeKey = sanitizeKey(key);
      const type = getDartType(json[key], key);
      const objectType = getObjectType(json[key], key);
      if (type.startsWith("List<")) {
        return `      ${safeKey}: json['${key}'] == null ? [] : List<${objectType}>.from(json['${key}']!.map((x) => ${objectType}.fromJson(x))),`;
      } else if (type.endsWith(">")) {
        return `      ${safeKey}: json['${key}'] != null ? ${type}.fromJson(json['${key}']) : null,`;
      }
      return `      ${safeKey}: json['${key}'],`;
    })
    .filter(Boolean)
    .join("\n");

  const toJsonFields = Object.keys(json)
    .map((key) => {
      // Skip invalid or numeric keys
      if (!key || !isNaN(key)) return;

      const safeKey = sanitizeKey(key);
      const type = getDartType(json[key], key);
      const objectType = getObjectType(json[key], key);
      // Check if the value is an array
      if (Array.isArray(json[key])) {
        return `     '${key}': (${safeKey} == null) ? [] : List<dynamic>.from(${safeKey}!.map((x) => x.toJson())),`;
      }

      return `      '${key}': ${safeKey},`;
    })
    .filter(Boolean)
    .join("\n");

  let childClasses = "";
  Object.keys(json).forEach((key) => {
    const safeKey = sanitizeKey(key);
    const type = getDartType(json[key], key);
    const objectType = getObjectType(json[key], key);
    if (type.endsWith(">") || type.startsWith("List<")) {
      // const child1ClassName = type.replace(/^List<|>$/g, "");
      // const childClassName = extractClassName(type); // Updated function for extracting class name
      const childClassName = objectType;
      const childJson = Array.isArray(json[key]) ? json[key][0] : json[key];
      if (typeof childJson === "object" && childJson !== null) {
        childClasses += "\n\n" + convertJsonToDart(childJson, childClassName);
      }
    }
  });

  return `
import 'dart:convert';

class ${className} {
${fields}

  ${className}({
${constructorFields}
  });

  factory ${className}.fromJson(Map<String, dynamic> json) {
    return ${className}(
${factoryFields}
    );
  }

  Map<String, dynamic> toJson() {
    return {
${toJsonFields}
    };
  }
}${childClasses}
`.trim();
}

function sanitizeKey(key) {
  // Handle numeric keys or other invalid Dart names
  if (!isNaN(key)) {
    return `key_${key}`;
  }
  return key;
}

function formatClassKey(key) {
  // If the key ends with 's' or 'es', remove that suffix (for arrays)
  if (key.endsWith("s") || key.endsWith("es")) {
    return key.slice(0, -1); // Remove 's'
  }

  return key;
}

function getDartType(value, key) {
  if (typeof value === "string") {
    if (isIso8601Date(value)) {
      return "DateTime?"; // Nullable DateTime
    }
    return "String?"; // Nullable String
  }
  if (typeof value === "number") return value % 1 === 0 ? "int?" : "double?"; // Nullable int or double
  if (typeof value === "boolean") return "bool?"; // Nullable bool
  if (Array.isArray(value)) {
    const arrayType =
      value.length > 0
        ? formatClassKey(getDartType(value[0], key).replace(/\?$/, ""))
        : "dynamic";
    return `List<${arrayType}>?`; // Nullable List with non-nullable elements
  }
  if (typeof value === "object" && value !== null) {
    return capitalizeFirstLetter(key); // Return class name (e.g., "Friend")
  }
  return "dynamic"; // Non-optional dynamic type
}

function getObjectType(value, key) {
  if (typeof value === "string") {
    if (isIso8601Date(value)) {
      return "DateTime"; // Nullable DateTime
    }
    return "String"; // Nullable String
  }
  if (typeof value === "number") return value % 1 === 0 ? "int" : "double"; // Nullable int or double
  if (typeof value === "boolean") return "bool"; // Nullable bool
  if (Array.isArray(value)) {
    const arrayType =
      value.length > 0
        ? formatClassKey(getDartType(value[0], key).replace(/\?$/, ""))
        : "dynamic";
    return arrayType; // Nullable List with non-nullable elements
  }
  if (typeof value === "object" && value !== null) {
    return capitalizeFirstLetter(key); // Return class name (e.g., "Friend")
  }
  return "dynamic"; // Non-optional dynamic type
}

// Function to check if the string is an ISO 8601 formatted date string
function isIso8601Date(value) {
  const iso8601Pattern =
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|([+\-])\d{2}:\d{2})$/;
  return iso8601Pattern.test(value);
}

function capitalizeFirstLetter(string) {
  return string.charAt(0).toUpperCase() + string.slice(1);
}

function extractClassName(type) {
  // Match List<T> where T is alphabetic only (e.g., List<Friend>)
  const match = type.match(/^List<([a-zA-Z]+)>?$/);
  if (match) {
    return match[1]; // Return only the class name, e.g., 'Friend'
  }
  // Return the type as is for non-List types, e.g., String, int, etc.
  return type;
}
