//
//  WeatherService.swift
//  Real Weather
//
//  Created by SveinKlonteig on 03/07/2026.
//

import Foundation

enum WeatherServiceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Couldn't build the weather request."
        case .invalidResponse:
            return "The weather service returned an unexpected response."
        case .decodingFailed:
            return "Couldn't read the weather data."
        }
    }
}

/// Fetches forecasts from several weather models via Open-Meteo and averages
/// them into a single "real" reading, rather than trusting one provider.
enum WeatherService {
    static func fetch(latitude: Double, longitude: Double) async throws -> WeatherReport {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code"),
            URLQueryItem(name: "models", value: WeatherModels.queryValue),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "6"),
        ]
        guard let url = components?.url else {
            throw WeatherServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WeatherServiceError.invalidResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WeatherServiceError.decodingFailed
        }

        return try parse(json: json)
    }

    private static func parse(json: [String: Any]) throws -> WeatherReport {
        guard
            let hourly = json["hourly"] as? [String: Any],
            let hourlyTimes = hourly["time"] as? [String],
            let daily = json["daily"] as? [String: Any],
            let dailyTimes = daily["time"] as? [String]
        else {
            throw WeatherServiceError.decodingFailed
        }

        let timeZone = TimeZone(identifier: json["timezone"] as? String ?? "") ?? .current

        let localTimeFormatter = DateFormatter()
        localTimeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        localTimeFormatter.timeZone = timeZone

        let localDayFormatter = DateFormatter()
        localDayFormatter.dateFormat = "yyyy-MM-dd"
        localDayFormatter.timeZone = timeZone

        let nowIndex = closestIndex(to: Date(), in: hourlyTimes, using: localTimeFormatter)

        let modelNames = WeatherModels.all.map(\.queryName)

        let currentTemps = modelNames.compactMap {
            (hourly["temperature_2m_\($0)"] as? [Double])?[safe: nowIndex]
        }
        let currentCodes = modelNames
            .compactMap { (hourly["weather_code_\($0)"] as? [Double])?[safe: nowIndex] }
            .map(Int.init)

        guard !currentTemps.isEmpty, !currentCodes.isEmpty else {
            throw WeatherServiceError.decodingFailed
        }

        let current = CurrentWeather(temperature: average(currentTemps), weatherCode: mode(currentCodes))

        var hourlyByDay: [String: [HourlyForecast]] = [:]
        for (index, hourString) in hourlyTimes.enumerated() {
            guard let date = localTimeFormatter.date(from: hourString) else { continue }

            let temps = modelNames.compactMap { (hourly["temperature_2m_\($0)"] as? [Double])?[safe: index] }
            let codes = modelNames
                .compactMap { (hourly["weather_code_\($0)"] as? [Double])?[safe: index] }
                .map(Int.init)

            guard !temps.isEmpty, !codes.isEmpty else { continue }

            let dayKey = String(hourString.prefix(10))
            hourlyByDay[dayKey, default: []].append(HourlyForecast(
                date: date,
                temperature: average(temps),
                weatherCode: mode(codes)
            ))
        }

        var dailyForecasts: [DailyForecast] = []
        for (index, dayString) in dailyTimes.enumerated() {
            guard let date = localDayFormatter.date(from: dayString) else { continue }

            let highs = modelNames.compactMap { (daily["temperature_2m_max_\($0)"] as? [Double])?[safe: index] }
            let lows = modelNames.compactMap { (daily["temperature_2m_min_\($0)"] as? [Double])?[safe: index] }
            let codes = modelNames
                .compactMap { (daily["weather_code_\($0)"] as? [Double])?[safe: index] }
                .map(Int.init)

            guard !highs.isEmpty, !lows.isEmpty, !codes.isEmpty else { continue }

            dailyForecasts.append(DailyForecast(
                date: date,
                highTemperature: average(highs),
                lowTemperature: average(lows),
                weatherCode: mode(codes),
                hourly: index < hourlyDayWindow ? (hourlyByDay[dayString] ?? []) : []
            ))
        }

        return WeatherReport(current: current, daily: dailyForecasts)
    }

    /// Number of leading days (today + following) for which we expose an hour-by-hour breakdown.
    private static let hourlyDayWindow = 3

    private static func closestIndex(to date: Date, in localTimes: [String], using formatter: DateFormatter) -> Int {
        var bestIndex = 0
        var bestDiff = Double.greatestFiniteMagnitude
        for (index, timeString) in localTimes.enumerated() {
            guard let time = formatter.date(from: timeString) else { continue }
            let diff = abs(time.timeIntervalSince(date))
            if diff < bestDiff {
                bestDiff = diff
                bestIndex = index
            }
        }
        return bestIndex
    }

    private static func average(_ values: [Double]) -> Double {
        values.reduce(0, +) / Double(values.count)
    }

    private static func mode(_ values: [Int]) -> Int {
        let counts = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? values[0]
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
