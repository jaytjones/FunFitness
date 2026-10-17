//
//  RouteMath.swift
//  FunFitness
//
//  Pure, UI-free math for live walk/run tracking (3.1 B1a): GPS fix filtering, distance and
//  moving-time accumulation across pauses, pace, route downsampling, and the compact polyline
//  encoding stored in `RouteSummary`. No Core Location types here so all of it is unit-tested on
//  the simulator; `WorkoutTracker` converts `CLLocation`s into `RoutePoint`s and feeds them in.
//

import Foundation

/// What the person is tracking. Raw values are persisted in `RouteSummary.workoutKindRaw`.
nonisolated enum TrackedWorkoutKind: String, Codable, CaseIterable, Sendable {
    case walk
    case run

    var displayName: String {
        switch self {
        case .walk: return "Walk"
        case .run:  return "Run"
        }
    }

    var emoji: String {
        switch self {
        case .walk: return "🚶"
        case .run:  return "🏃"
        }
    }

    /// Fastest believable speed between two fixes. Anything faster is a GPS jump, not movement.
    var maxPlausibleSpeed: Double {   // meters per second
        switch self {
        case .walk: return 4.5    // ~16 km/h — covers fast walking and short jogs
        case .run:  return 11.0   // ~40 km/h — above elite sprint pace
        }
    }
}

/// One GPS fix, reduced to what the math needs.
nonisolated struct RoutePoint: Equatable, Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    /// Radius of uncertainty in meters. Negative means the fix is invalid (Core Location's convention).
    let horizontalAccuracy: Double
}

// MARK: - Geometry

nonisolated enum RouteMath {

    /// Fixes less accurate than this are ignored; urban-canyon fixes are often 50–100 m off.
    static let maxHorizontalAccuracy: Double = 25   // meters
    /// Movement smaller than this between fixes is treated as GPS jitter while standing still.
    static let minSegmentDistance: Double = 2        // meters

    /// Great-circle distance in meters (haversine).
    static func distance(from a: RoutePoint, to b: RoutePoint) -> Double {
        distance(lat1: a.latitude, lon1: a.longitude, lat2: b.latitude, lon2: b.longitude)
    }

    static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Whether a fix is accurate enough to use at all.
    static func isAccurate(_ point: RoutePoint) -> Bool {
        point.horizontalAccuracy >= 0 && point.horizontalAccuracy <= maxHorizontalAccuracy
    }

    /// Pace in seconds per kilometer, or nil before there's enough distance to be meaningful.
    static func paceSecondsPerKm(distanceMeters: Double, movingSeconds: TimeInterval) -> Double? {
        guard distanceMeters >= 50, movingSeconds > 0 else { return nil }
        return movingSeconds / (distanceMeters / 1000)
    }

    // MARK: Downsampling

    /// Reduces a route to at most `maxPoints`, keeping its shape: Ramer–Douglas–Peucker at a
    /// `toleranceMeters` corridor, then an even stride if it's still too long. Endpoints are kept.
    static func downsample(_ points: [RoutePoint], maxPoints: Int = 500, toleranceMeters: Double = 5) -> [RoutePoint] {
        guard points.count > 2, maxPoints >= 2 else { return Array(points.prefix(max(maxPoints, 0))) }

        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        // Iterative RDP so very long routes can't overflow the stack.
        var stack: [(Int, Int)] = [(0, points.count - 1)]
        while let (start, end) = stack.popLast() {
            guard end > start + 1 else { continue }
            var maxDistance = 0.0
            var index = start
            for i in (start + 1)..<end {
                let d = perpendicularDistance(points[i], lineStart: points[start], lineEnd: points[end])
                if d > maxDistance { maxDistance = d; index = i }
            }
            if maxDistance > toleranceMeters {
                keep[index] = true
                stack.append((start, index))
                stack.append((index, end))
            }
        }
        var simplified = zip(points, keep).compactMap { $1 ? $0 : nil }

        if simplified.count > maxPoints {
            let last = simplified[simplified.count - 1]
            let step = Double(simplified.count - 1) / Double(maxPoints - 1)
            simplified = (0..<(maxPoints - 1)).map { simplified[Int((Double($0) * step).rounded(.down))] } + [last]
        }
        return simplified
    }

    /// Distance in meters from `p` to the segment start→end, on a local flat projection
    /// (accurate enough over the few hundred meters a route segment spans).
    private static func perpendicularDistance(_ p: RoutePoint, lineStart a: RoutePoint, lineEnd b: RoutePoint) -> Double {
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = 111_320.0 * cos(a.latitude * .pi / 180)
        let bx = (b.longitude - a.longitude) * metersPerDegLon
        let by = (b.latitude - a.latitude) * metersPerDegLat
        let px = (p.longitude - a.longitude) * metersPerDegLon
        let py = (p.latitude - a.latitude) * metersPerDegLat
        let lengthSquared = bx * bx + by * by
        guard lengthSquared > 0 else { return (px * px + py * py).squareRoot() }
        let t = max(0, min(1, (px * bx + py * by) / lengthSquared))
        let dx = px - t * bx
        let dy = py - t * by
        return (dx * dx + dy * dy).squareRoot()
    }
}

// MARK: - Accumulator

/// Running totals for one tracked workout. Feed it every fix; it drops inaccurate fixes and GPS
/// jumps, ignores movement while paused, and never joins the last point before a pause to the
/// first point after it (so walking to the car while paused doesn't count).
nonisolated struct RouteAccumulator: Sendable {
    let kind: TrackedWorkoutKind
    private(set) var startedAt: Date?
    private(set) var distanceMeters: Double = 0
    /// Every accepted fix, in order, across all segments (for the Health route and the map).
    private(set) var points: [RoutePoint] = []
    private(set) var isPaused = false
    /// Completed pauses, for the Health workout's pause/resume events.
    private(set) var pauseIntervals: [DateInterval] = []

    private var pausedAt: Date?
    private var movingSecondsBeforeSegment: TimeInterval = 0
    private var segmentStartedAt: Date?
    private var lastPointInSegment: RoutePoint?

    init(kind: TrackedWorkoutKind) {
        self.kind = kind
    }

    mutating func start(at date: Date) {
        guard startedAt == nil else { return }
        startedAt = date
        segmentStartedAt = date
    }

    mutating func pause(at date: Date) {
        guard !isPaused, let segmentStart = segmentStartedAt else { return }
        movingSecondsBeforeSegment += max(0, date.timeIntervalSince(segmentStart))
        segmentStartedAt = nil
        lastPointInSegment = nil
        pausedAt = date
        isPaused = true
    }

    mutating func resume(at date: Date) {
        guard isPaused else { return }
        if let pausedAt { pauseIntervals.append(DateInterval(start: pausedAt, end: max(pausedAt, date))) }
        pausedAt = nil
        segmentStartedAt = date
        isPaused = false
    }

    /// Ends the workout: closes any open pause so `movingSeconds` and `pauseIntervals` are final.
    mutating func finish(at date: Date) {
        if isPaused { resume(at: date) }
        pause(at: date)
        // The closing pause above is bookkeeping, not a real pause; drop it.
        pausedAt = nil
    }

    /// Time spent not paused, as of `date`.
    func movingSeconds(at date: Date) -> TimeInterval {
        guard let segmentStart = segmentStartedAt else { return movingSecondsBeforeSegment }
        return movingSecondsBeforeSegment + max(0, date.timeIntervalSince(segmentStart))
    }

    /// Adds a fix if it's usable. Returns whether it was accepted.
    @discardableResult
    mutating func add(_ point: RoutePoint) -> Bool {
        guard startedAt != nil, !isPaused, RouteMath.isAccurate(point) else { return false }
        guard let previous = lastPointInSegment else {
            lastPointInSegment = point
            points.append(point)
            return true
        }
        let meters = RouteMath.distance(from: previous, to: point)
        let seconds = point.timestamp.timeIntervalSince(previous.timestamp)
        guard seconds > 0 else { return false }
        // Standing still: GPS wanders a few meters; don't count it or record it.
        guard meters >= RouteMath.minSegmentDistance else { return false }
        // A jump faster than the activity allows is a bad fix.
        guard meters / seconds <= kind.maxPlausibleSpeed else { return false }
        distanceMeters += meters
        lastPointInSegment = point
        points.append(point)
        return true
    }
}

// MARK: - Polyline encoding

/// Compact binary encoding for a display route: a version byte, then little-endian Float64
/// latitude/longitude pairs. 500 points ≈ 8 KB, stored as an external CloudKit asset.
nonisolated enum RoutePolyline {
    static let version: UInt8 = 1

    static func encode(_ points: [RoutePoint]) -> Data {
        var data = Data([version])
        data.reserveCapacity(1 + points.count * 16)
        for point in points {
            withUnsafeBytes(of: point.latitude.bitPattern.littleEndian) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: point.longitude.bitPattern.littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }

    /// Decodes to (latitude, longitude) pairs. Returns [] for unknown versions or malformed data.
    static func decode(_ data: Data) -> [(latitude: Double, longitude: Double)] {
        guard data.first == version, (data.count - 1) % 16 == 0 else { return [] }
        let bytes = [UInt8](data.dropFirst())
        var result: [(latitude: Double, longitude: Double)] = []
        result.reserveCapacity(bytes.count / 16)
        var offset = 0
        while offset < bytes.count {
            let lat = readDouble(bytes, at: offset)
            let lon = readDouble(bytes, at: offset + 8)
            result.append((lat, lon))
            offset += 16
        }
        return result
    }

    private static func readDouble(_ bytes: [UInt8], at offset: Int) -> Double {
        var bits: UInt64 = 0
        for i in 0..<8 { bits |= UInt64(bytes[offset + i]) << (8 * UInt64(i)) }
        return Double(bitPattern: bits)
    }
}
