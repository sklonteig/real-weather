//
//  WeatherViewModel.swift
//  Real Weather
//
//  Created by SveinKlonteig on 03/07/2026.
//

import Combine
import Foundation

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var current: CurrentWeather?
    @Published var daily: [DailyForecast] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadWeather(latitude: Double, longitude: Double) async {
        isLoading = true
        errorMessage = nil

        do {
            let report = try await WeatherService.fetch(latitude: latitude, longitude: longitude)
            current = report.current
            daily = report.daily
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
