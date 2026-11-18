import Foundation

// Resolves every key of a String Catalog from a real app bundle with the
// language that Foundation selected for this process. The caller forces that
// language with -AppleLanguages, exactly like macOS and iOS do at launch.
//
// Usage:
//   probe --catalog <Localizable.xcstrings> --locale <tag> \
//         --expect-bundle <path> [--missing-key <key>] \
//         [--info-plist-key <key>]

struct Catalog: Decodable {
    struct StringUnit: Decodable {
        let value: String
    }

    struct Localization: Decodable {
        let stringUnit: StringUnit?
    }

    struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    let sourceLanguage: String
    let strings: [String: Entry]
}

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: \(message)\n").utf8))
    exit(2)
}

var catalogPath: String?
var localeID: String?
var missingKey: String?
var infoPlistKey: String?
var expectedBundlePath: String?

var index = 1
while index < CommandLine.arguments.count {
    let argument = CommandLine.arguments[index]
    switch argument {
    case "--catalog":
        index += 1
        guard index < CommandLine.arguments.count else { die("--catalog needs a value") }
        catalogPath = CommandLine.arguments[index]
    case "--locale":
        index += 1
        guard index < CommandLine.arguments.count else { die("--locale needs a value") }
        localeID = CommandLine.arguments[index]
    case "--missing-key":
        index += 1
        guard index < CommandLine.arguments.count else { die("--missing-key needs a value") }
        missingKey = CommandLine.arguments[index]
    case "--info-plist-key":
        index += 1
        guard index < CommandLine.arguments.count else { die("--info-plist-key needs a value") }
        infoPlistKey = CommandLine.arguments[index]
    case "--expect-bundle":
        index += 1
        guard index < CommandLine.arguments.count else { die("--expect-bundle needs a value") }
        expectedBundlePath = CommandLine.arguments[index]
    default:
        // Foundation's -AppleLanguages / -AppleLocale arguments and their
        // values are intentionally ignored; the process already consumed them.
        break
    }
    index += 1
}

guard let catalogPath, let localeID else {
    die("--catalog and --locale are required")
}

guard let data = FileManager.default.contents(atPath: catalogPath) else {
    die("cannot read catalog at \(catalogPath)")
}

let catalog: Catalog
do {
    catalog = try JSONDecoder().decode(Catalog.self, from: data)
} catch {
    die("cannot decode catalog at \(catalogPath): \(error)")
}

let bundle = Bundle.main
let actualBundlePath = URL(fileURLWithPath: bundle.bundlePath)
    .resolvingSymlinksInPath().path
if let expectedBundlePath {
    let expected = URL(fileURLWithPath: expectedBundlePath)
        .resolvingSymlinksInPath().path
    guard actualBundlePath == expected else {
        die("probe runs in \(actualBundlePath), expected \(expected)")
    }
}

let developmentRegion = bundle.object(forInfoDictionaryKey: "CFBundleDevelopmentRegion") as? String
guard developmentRegion == catalog.sourceLanguage else {
    die("development region is \(developmentRegion ?? "nil"), catalog source is \(catalog.sourceLanguage)")
}

func baseLanguage(of identifier: String) -> String {
    let lowercased = identifier.lowercased()
    if lowercased.hasPrefix("zh") { return "zh" }
    return lowercased.split(separator: "-").first.map(String.init) ?? lowercased
}

let language = baseLanguage(of: localeID)
let hasTranslations = catalog.strings.values.contains {
    $0.localizations?[language]?.stringUnit != nil
}
let expectedLocalization = hasTranslations ? language : catalog.sourceLanguage
let preferred = bundle.preferredLocalizations

var failures = 0
var checked = 0

func check(key: String, expected: String, actual: String) {
    checked += 1
    if actual != expected {
        failures += 1
        if failures <= 20 {
            print("FAIL key=\(String(reflecting: key)) expected=\(String(reflecting: expected)) actual=\(String(reflecting: actual))")
        }
    }
}

if preferred.first != expectedLocalization {
    failures += 1
    print("FAIL preferred localization is \(preferred), expected \(expectedLocalization)")
}

if let infoPlistKey {
    guard let english = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String else {
        die("\(infoPlistKey) is not in the bundle's Info.plist")
    }
    let translated = catalog.strings[infoPlistKey]?.localizations?[language]?.stringUnit?.value
    let expected = (missingKey == infoPlistKey ? nil : translated) ?? english

    // Without an InfoPlist.strings entry for the selected language, the system
    // uses the base Info.plist value (English), not the key.
    var actual = bundle.localizedString(forKey: infoPlistKey, value: nil, table: "InfoPlist")
    if actual == infoPlistKey {
        actual = english
    }
    check(key: infoPlistKey, expected: expected, actual: actual)
} else {
    if let missingKey, catalog.strings[missingKey] == nil {
        die("missing key \(missingKey) is not in the catalog")
    }

    for key in catalog.strings.keys.sorted() {
        guard let entry = catalog.strings[key] else { continue }
        let english = entry.localizations?[catalog.sourceLanguage]?.stringUnit?.value ?? key
        let translated = entry.localizations?[language]?.stringUnit?.value
        let expected = (missingKey == key ? nil : translated) ?? english
        let actual = bundle.localizedString(forKey: key, value: nil, table: nil)
        check(key: key, expected: expected, actual: actual)
    }
}

let name = bundle.bundleURL.lastPathComponent
if failures == 0 {
    print("PASS \(name) locale=\(localeID) preferred=\(preferred.joined(separator: ",")) keys=\(checked)")
} else {
    print("FAILED \(name) locale=\(localeID) mismatches=\(failures) keys=\(checked)")
    exit(1)
}
