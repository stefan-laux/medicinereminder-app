import Foundation

// LogSource.swift
public enum LogSource: String, Codable, Sendable {
    case manual, siri, notification, liveActivity, widget, auto
}
