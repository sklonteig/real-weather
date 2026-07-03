//
//  ContentView.swift
//  Real Weather
//
//  Created by SveinKlonteig on 03/07/2026.
//


import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var weatherViewModel = WeatherViewModel()
    @State private var expandedDayIDs: Set<DailyForecast.ID> = []

    private struct Coordinate: Equatable {
        let latitude: Double
        let longitude: Double
    }

    private var coordinate: Coordinate? {
        guard let lat = locationManager.latitude, let lon = locationManager.longitude else { return nil }
        return Coordinate(latitude: lat, longitude: lon)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Weather Average")
                    .font(.largeTitle)
                    .bold()

                if coordinate != nil {
                    if weatherViewModel.isLoading {
                        ProgressView("Averaging forecasts...")
                    } else if let error = weatherViewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    } else if let current = weatherViewModel.current {
                        currentWeatherView(current)
                        if !weatherViewModel.daily.isEmpty {
                            dailyForecastView(weatherViewModel.daily)
                        }
                    }
                } else if let error = locationManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                } else {
                    ProgressView("Getting your location...")
                }

                Button("Retry") {
                    locationManager.requestLocation()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .task(id: coordinate) {
            guard let coordinate else { return }
            await weatherViewModel.loadWeather(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    private func currentWeatherView(_ current: CurrentWeather) -> some View {
        VStack(spacing: 8) {
            Image(systemName: WeatherCode.symbolName(for: current.weatherCode))
                .font(.system(size: 56))
                .symbolRenderingMode(.multicolor)
            Text("\(current.temperature, specifier: "%.1f")°C")
                .font(.system(size: 44, weight: .semibold))
            Text(WeatherCode.description(for: current.weatherCode))
                .foregroundColor(.secondary)
            Text("Averaged across \(WeatherModels.displayNamesJoined)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func dailyForecastView(_ days: [DailyForecast]) -> some View {
        VStack(spacing: 12) {
            ForEach(days) { day in
                VStack(spacing: 12) {
                    dayRow(day)
                    if expandedDayIDs.contains(day.id) {
                        hourlyRow(day.hourly)
                    }
                }
                Divider()
            }
        }
    }

    private func dayRow(_ day: DailyForecast) -> some View {
        Button {
            guard !day.hourly.isEmpty else { return }
            if expandedDayIDs.contains(day.id) {
                expandedDayIDs.remove(day.id)
            } else {
                expandedDayIDs.insert(day.id)
            }
        } label: {
            HStack {
                Text(day.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .frame(width: 90, alignment: .leading)
                Image(systemName: WeatherCode.symbolName(for: day.weatherCode))
                    .symbolRenderingMode(.multicolor)
                Spacer()
                Text("\(day.lowTemperature, specifier: "%.0f")°")
                    .foregroundColor(.secondary)
                Text("\(day.highTemperature, specifier: "%.0f")°")
                    .fontWeight(.semibold)
                if !day.hourly.isEmpty {
                    Image(systemName: expandedDayIDs.contains(day.id) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(day.hourly.isEmpty)
    }

    private func hourlyRow(_ hours: [HourlyForecast]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(hours) { hour in
                    VStack(spacing: 4) {
                        Text(hour.date, format: .dateTime.hour())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: WeatherCode.symbolName(for: hour.weatherCode))
                            .symbolRenderingMode(.multicolor)
                        Text("\(hour.temperature, specifier: "%.0f")°")
                            .font(.subheadline)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    ContentView()
}
