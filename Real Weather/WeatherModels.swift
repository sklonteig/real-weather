//
//  WeatherModels.swift
//  Real Weather
//
//  Created by SveinKlonteig on 03/07/2026.
//

import Foundation

struct WeatherModelSource {
    let queryName: String
    let displayName: String
}

/// The forecast models we average across to produce a "real" (consensus) weather reading.
enum WeatherModels {
    static let all: [WeatherModelSource] = [
        WeatherModelSource(queryName: "gfs_seamless", displayName: "GFS"),
        WeatherModelSource(queryName: "ecmwf_ifs025", displayName: "ECMWF"),
        WeatherModelSource(queryName: "icon_seamless", displayName: "ICON"),
        WeatherModelSource(queryName: "ukmo_seamless", displayName: "UKMO"),
        WeatherModelSource(queryName: "metno_seamless", displayName: "MET Norway"),
    ]

    static var queryValue: String {
        all.map(\.queryName).joined(separator: ",")
    }

    static var displayNamesJoined: String {
        all.map(\.displayName).joined(separator: ", ")
    }
}

struct CurrentWeather {
    let temperature: Double
    let weatherCode: Int
}

struct HourlyForecast: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let temperature: Double
    let weatherCode: Int
}

struct DailyForecast: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let highTemperature: Double
    let lowTemperature: Double
    let weatherCode: Int
    /// Hour-by-hour breakdown for this day; empty when not requested (e.g. days beyond the near-term window).
    let hourly: [HourlyForecast]
}

struct WeatherReport {
    let current: CurrentWeather
    let daily: [DailyForecast]
}
