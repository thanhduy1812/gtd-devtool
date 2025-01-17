
/**
    {
        "api":1,
        "name":"Dart Model to JSON",
        "description":"Converts a Dart model class into a JSON structure",
        "author":"DuyNT",
        "icon":"table",
        "tags":"dart,json,model,reverse"
    }
**/

function main(input) {
    const dartModel = input.text;

    const jsonStructure = convertModelToJson(dartModel);

    input.text = JSON.stringify(jsonStructure, null, 2);
}

function convertModelToJson(dartModel) {
    const lines = dartModel.split("\n");

    const fieldLines = lines.filter((line) => line.trim().startsWith("final"));
    const json = {};

    fieldLines.forEach((line) => {
        const match = /final\s+(\w+)\s+(\w+);/.exec(line.trim());
        if (match) {
            const [_, type, fieldName] = match;
            json[fieldName] = getDefaultValue(type);
        }
    });

    return json;
}

function getDefaultValue(type) {
    switch (type) {
        case "String":
            return "example";
        case "int":
            return 0;
        case "double":
            return 0.0;
        case "bool":
            return false;
        case "List<dynamic>":
            return [];
        case "Map<String, dynamic>":
            return {};
        default:
            return null;
    }
}
