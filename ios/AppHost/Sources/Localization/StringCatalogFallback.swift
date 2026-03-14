import Foundation

enum StringCatalogFallback {
    private static let lock = NSLock()
    private static var cache: [String: [String: [String: String]]] = [:]

    static func localizedValue(for key: String, table: String, bundle: Bundle, locale: Locale) -> String? {
        guard let catalog = loadCatalog(named: table, bundle: bundle) else { return nil }
        guard let localizations = catalog[key] else { return nil }

        for candidate in localeCandidates(for: locale) {
            if let value = localizations[candidate] {
                return value
            }
        }

        return nil
    }

    private static func loadCatalog(named table: String, bundle: Bundle) -> [String: [String: String]]? {
        let cacheKey = "\(bundle.bundlePath)::\(table)"

        lock.lock()
        if let cached = cache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let url = bundle.url(forResource: table, withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = object["strings"] as? [String: Any] else {
            return nil
        }

        var parsed: [String: [String: String]] = [:]
        for (key, entryValue) in strings {
            guard let entry = entryValue as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else {
                continue
            }

            var values: [String: String] = [:]
            for (localeID, localizationValue) in localizations {
                guard let localization = localizationValue as? [String: Any],
                      let stringUnit = localization["stringUnit"] as? [String: Any],
                      let value = stringUnit["value"] as? String else {
                    continue
                }
                values[localeID] = value
            }
            parsed[key] = values
        }

        lock.lock()
        cache[cacheKey] = parsed
        lock.unlock()
        return parsed
    }

    private static func localeCandidates(for locale: Locale) -> [String] {
        let normalized = locale.identifier.replacingOccurrences(of: "_", with: "-")
        var candidates: [String] = [normalized]

        if normalized.hasPrefix("zh") {
            if normalized.contains("Hans") || normalized.uppercased().contains("CN") || normalized.uppercased().contains("SG") {
                candidates.append("zh-Hans")
            } else if normalized.contains("Hant") || normalized.uppercased().contains("TW") || normalized.uppercased().contains("HK") || normalized.uppercased().contains("MO") {
                candidates.append("zh-Hant")
            }
        }

        if let languageCode = locale.language.languageCode?.identifier {
            candidates.append(languageCode)
        }

        candidates.append("en")

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }
}
