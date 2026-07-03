# Real Weather

An iOS app that shows the "real" weather by averaging forecasts from
several independent weather models instead of trusting a single provider.

## How it works

Using your device's location, the app queries [Open-Meteo](https://open-meteo.com)
for forecasts from five models — GFS (NOAA), ECMWF, ICON (DWD), UKMO, and
MET Norway — then averages their temperatures and takes the most common
weather condition across them.

## Features

- Current conditions, averaged across all models
- 6-day forecast
- Expandable hour-by-hour breakdown for today and the next two days

## Requirements

- Xcode 26+
- iOS 26.5+ deployment target
