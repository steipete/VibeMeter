// VibeMeter/Core/Utilities/Tiktoken/Encoding.swift
// Lightweight version of Tiktoken Encoding enum to satisfy compiler and allow future expansion.
// When full Tiktoken library is vendored, this will be replaced.

import Foundation

public enum Encoding: String, CaseIterable, Codable, Sendable {
    case r50k_base = "r50k_base"
    case p50k_base = "p50k_base"
    case cl100k_base = "cl100k_base"
    case o200k_base = "o200k_base" // New encoding for Claude models
}

