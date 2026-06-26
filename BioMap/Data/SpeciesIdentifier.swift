import Foundation
import FirebaseFunctions

enum SpeciesIdentifier {
    static func identify(imageData: Data, lat: Double?, lng: Double?) async -> [SpeciesCandidate] {
        var payload: [String: Any] = ["imageBase64": imageData.base64EncodedString()]
        if let lat { payload["lat"] = lat }
        if let lng { payload["lng"] = lng }
        do {
            let result = try await Functions.functions().httpsCallable("identifySpecies").call(payload)
            guard let map = result.data as? [String: Any],
                  let arr = map["candidates"] as? [[String: Any]] else { return [] }
            return arr.map { m in
                SpeciesCandidate(
                    taxonId: (m["taxon_id"] as? NSNumber)?.int64Value ?? 0,
                    name: m["name"] as? String ?? "",
                    scientificName: m["scientific_name"] as? String ?? "",
                    rank: m["rank"] as? String ?? "",
                    score: (m["score"] as? NSNumber)?.doubleValue ?? 0,
                    iconUrl: m["icon_url"] as? String ?? "",
                    iconicTaxon: m["iconic_taxon"] as? String ?? ""
                )
            }
        } catch {
            return []
        }
    }

    static func identifyBySound(audioData: Data, lat: Double?, lng: Double?) async -> [SpeciesCandidate] {
        var payload: [String: Any] = [
            "audioBase64": audioData.base64EncodedString(),
            "format": "m4a",
        ]
        if let lat { payload["lat"] = lat }
        if let lng { payload["lng"] = lng }
        do {
            let result = try await Functions.functions().httpsCallable("identifyBirdSound").call(payload)
            guard let map = result.data as? [String: Any],
                  let arr = map["candidates"] as? [[String: Any]] else { return [] }
            return arr.map { m in
                SpeciesCandidate(
                    taxonId: (m["taxon_id"] as? NSNumber)?.int64Value ?? 0,
                    name: m["name"] as? String ?? "",
                    scientificName: m["scientific_name"] as? String ?? "",
                    rank: m["rank"] as? String ?? "",
                    score: (m["score"] as? NSNumber)?.doubleValue ?? 0,
                    iconUrl: m["icon_url"] as? String ?? "",
                    iconicTaxon: m["iconic_taxon"] as? String ?? ""
                )
            }
        } catch {
            return []
        }
    }

    static func search(_ query: String) async -> [SpeciesCandidate] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        do {
            let result = try await Functions.functions().httpsCallable("searchSpecies").call(["q": q])
            guard let map = result.data as? [String: Any],
                  let arr = map["candidates"] as? [[String: Any]] else { return [] }
            return arr.map { m in
                SpeciesCandidate(
                    taxonId: (m["taxon_id"] as? NSNumber)?.int64Value ?? 0,
                    name: m["name"] as? String ?? "",
                    scientificName: m["scientific_name"] as? String ?? "",
                    rank: m["rank"] as? String ?? "",
                    score: (m["score"] as? NSNumber)?.doubleValue ?? 0,
                    iconUrl: m["icon_url"] as? String ?? "",
                    iconicTaxon: m["iconic_taxon"] as? String ?? ""
                )
            }
        } catch {
            return []
        }
    }
}
