//
//  Colours.swift
//  mlx-swift-examples
//
//  Created by Jonathan Kimmitt on 07/08/2025.
//
import SwiftUI

extension Color {
    static var systemBackground: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var secondarySystemBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static var systemGray6: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #elseif os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #endif
    }

    static var separator: Color {
        #if os(iOS)
        return Color(.separator)
        #elseif os(macOS)
        return Color(nsColor: .separatorColor)
        #endif
    }
}
