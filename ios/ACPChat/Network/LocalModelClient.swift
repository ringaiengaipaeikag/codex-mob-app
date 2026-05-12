//
//  LocalModelClient.swift
//
//  On-device Apple Intelligence fallback using FoundationModels (iOS 26+).
//
//  Contract mirrors ACPClient.prompt: returns AsyncStream<SessionEvent>
//  that yields .textDelta deltas. No WebSocket, no bridge, no API cost.
//  Used when:
//    - user flipped "Private" mode on the session
//    - bridge is unreachable and session.mode != "dg"
//    - task is light (summary/reformat/translate) and offloading is configured
//
//  DG council work MUST NOT be routed here — the on-device ~3B model can't
//  orchestrate the multi-agent protocol or do serious disasm reasoning.
//
//  Guard with availability check; degrade gracefully on older devices
//  or when the user disabled Apple Intelligence.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class LocalModelClient {

    enum Availability: Sendable {
        case available
        case deviceNotEligible
        case intelligenceDisabled
        case modelNotReady
        case unsupported     // pre-iOS 26
    }

    var availability: Availability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:                              return .available
            case .unavailable(.deviceNotEligible):        return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled): return .intelligenceDisabled
            case .unavailable(.modelNotReady):            return .modelNotReady
            @unknown default:                             return .modelNotReady
            }
        }
        #endif
        return .unsupported
    }

    /// Start a local prompt. Returns the same AsyncStream<SessionEvent>
    /// contract the UI already handles for bridged sessions.
    func prompt(
        systemPrompt: String?,
        text: String
    ) -> AsyncStream<SessionEvent> {
        AsyncStream { cont in
            Task {
                #if canImport(FoundationModels)
                if #available(iOS 26.0, *) {
                    guard case .available = availability else {
                        cont.yield(.error("on-device model unavailable"))
                        cont.finish()
                        return
                    }
                    do {
                        let instructions = Instructions(systemPrompt ?? defaultSystemPrompt)
                        let session = LanguageModelSession(instructions: instructions)
                        let stream = session.streamResponse(to: text)
                        var last = ""
                        for try await partial in stream {
                            // FoundationModels yields cumulative partials;
                            // we emit deltas to match ACP semantics.
                            let full = partial.content
                            if full.count > last.count {
                                let delta = String(full.suffix(full.count - last.count))
                                cont.yield(.textDelta(delta))
                                last = full
                            }
                        }
                        cont.finish()
                        return
                    } catch {
                        cont.yield(.error(error.localizedDescription))
                        cont.finish()
                        return
                    }
                }
                #endif
                cont.yield(.error("FoundationModels requires iOS 26"))
                cont.finish()
            }
        }
    }

    // Conservative default: terse, code-friendly, matches the docs-style UI.
    private let defaultSystemPrompt = """
    You are a terse technical assistant running fully on device.
    Prefer code and concrete answers over prose. Do not invent facts you
    don't know. If a question clearly needs multi-agent reasoning or
    DroidGuard-specific knowledge, reply exactly with: NEEDS_BRIDGE.
    """
}
