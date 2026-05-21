package com.srm.collecte

import android.app.AppOpsManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import android.location.Criteria
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.Locale
import java.util.UUID
import kotlin.concurrent.thread

class MainActivity: FlutterActivity() {
    private val channelName = "com.srm.collecte/nmea_bridge"
    private val downloadNotificationChannelName = "com.srm.collecte/download_notification"
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val mockProviders = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)

    private lateinit var locationManager: LocationManager
    private var bluetoothSocket: BluetoothSocket? = null
    private var bluetoothThread: Thread? = null
    private var bridgeStatus: String = "idle"
    private var lastNmea: String? = null
    private var lastLocationPayload: Map<String, Any?>? = null
    private var currentBluetoothName: String? = null
    private var currentBluetoothAddress: String? = null
    private var lastGstAccuracy: Float? = null
    private var lastGstAccuracyAtMs: Long = 0L
    private val gstFreshnessWindowMs: Long = 5_000L
    private var lastGeographicFix: ParsedNmeaLocation? = null
    private var lastGeographicFixAtMs: Long = 0L
    private var lastProjectedFix: ParsedNmeaLocation? = null
    private var lastProjectedFixAtMs: Long = 0L
    private val fixMergeFreshnessWindowMs: Long = 5_000L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isMockLocationSelected" -> result.success(isMockLocationSelected())
                "openMockLocationSettings" -> {
                    openMockLocationSettings()
                    result.success(true)
                }
                "openBluetoothSettings" -> {
                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(true)
                }
                "startMockProvider" -> runCatching {
                    ensureMockProviders()
                    bridgeStatus = "mock_provider_ready"
                    true
                }.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("MOCK_PROVIDER_ERROR", it.message, null) }
                )
                "stopMockProvider" -> {
                    stopMockProviders()
                    result.success(true)
                }
                "pushLocation" -> runCatching {
                    val lat = call.argument<Double>("latitude")
                        ?: error("latitude manquante")
                    val lon = call.argument<Double>("longitude")
                        ?: error("longitude manquante")
                    val altitude = call.argument<Double>("altitude")
                    val accuracy = call.argument<Double>("accuracy")?.toFloat() ?: 1.0f
                    val speed = call.argument<Double>("speed")?.toFloat()
                    val bearing = call.argument<Double>("bearing")?.toFloat()
                    injectMockLocation(lat, lon, altitude, accuracy, speed, bearing, null)
                }.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("PUSH_LOCATION_ERROR", it.message, null) }
                )
                "pushNmea" -> runCatching {
                    val sentence = call.argument<String>("sentence")
                        ?: error("sentence NMEA manquante")
                    val parsed = parseNmea(sentence)
                        ?: error("Trame NMEA non supportee ou invalide")
                    injectMockLocation(
                        latitude = parsed.latitude ?: error("latitude GNSS manquante"),
                        longitude = parsed.longitude ?: error("longitude GNSS manquante"),
                        altitude = parsed.altitude,
                        accuracy = parsed.accuracy,
                        speed = parsed.speed,
                        bearing = parsed.bearing,
                        nmea = sentence,
                        fixQuality = parsed.fixQuality,
                        satellites = parsed.satellites,
                        hdop = parsed.hdop,
                        projectedX = parsed.projectedX,
                        projectedY = parsed.projectedY,
                        projectedZ = parsed.projectedZ,
                        coordinateSource = parsed.coordinateSource,
                    )
                }.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("PUSH_NMEA_ERROR", it.message, null) }
                )
                "listBondedBluetoothDevices" -> runCatching {
                    listBondedBluetoothDevices()
                }.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("BLUETOOTH_LIST_ERROR", it.message, null) }
                )
                "connectBluetooth" -> runCatching {
                    val address = call.argument<String>("address")
                        ?: error("adresse Bluetooth manquante")
                    connectBluetooth(address)
                    mapOf("status" to bridgeStatus)
                }.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("BLUETOOTH_CONNECT_ERROR", it.message, null) }
                )
                "disconnectBluetooth" -> {
                    disconnectBluetooth()
                    result.success(mapOf("status" to bridgeStatus))
                }
                "getStatus" -> result.success(statusPayload())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            downloadNotificationChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownloadNotification" -> {
                    sendDownloadNotificationIntent(
                        DownloadForegroundService.ACTION_START,
                        call.argument<String>("title"),
                        call.argument<String>("text"),
                        call.argument<Int>("progress"),
                        call.argument<Boolean>("indeterminate"),
                    )
                    result.success(true)
                }
                "updateDownloadNotification" -> {
                    sendDownloadNotificationIntent(
                        DownloadForegroundService.ACTION_UPDATE,
                        call.argument<String>("title"),
                        call.argument<String>("text"),
                        call.argument<Int>("progress"),
                        call.argument<Boolean>("indeterminate"),
                    )
                    result.success(true)
                }
                "finishDownloadNotification" -> {
                    sendDownloadNotificationIntent(
                        DownloadForegroundService.ACTION_FINISH,
                        call.argument<String>("title"),
                        call.argument<String>("text"),
                        call.argument<Int>("progress"),
                        call.argument<Boolean>("indeterminate"),
                    )
                    result.success(true)
                }
                "failDownloadNotification" -> {
                    sendDownloadNotificationIntent(
                        DownloadForegroundService.ACTION_FAIL,
                        call.argument<String>("title"),
                        call.argument<String>("text"),
                        call.argument<Int>("progress"),
                        call.argument<Boolean>("indeterminate"),
                    )
                    result.success(true)
                }
                "stopDownloadNotification" -> {
                    sendDownloadNotificationIntent(
                        DownloadForegroundService.ACTION_STOP,
                        null,
                        null,
                        null,
                        null,
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendDownloadNotificationIntent(
        actionName: String,
        title: String?,
        text: String?,
        progress: Int?,
        indeterminate: Boolean?,
    ) {
        val intent = Intent(this, DownloadForegroundService::class.java).apply {
            action = actionName
            if (title != null) putExtra("title", title)
            if (text != null) putExtra("text", text)
            if (progress != null) putExtra("progress", progress)
            if (indeterminate != null) putExtra("indeterminate", indeterminate)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            actionName == DownloadForegroundService.ACTION_START
        ) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun openMockLocationSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun isMockLocationSelected(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_MOCK_LOCATION,
                android.os.Process.myUid(),
                packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_MOCK_LOCATION,
                android.os.Process.myUid(),
                packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun ensureMockProviders() {
        if (!isMockLocationSelected()) {
            throw SecurityException(
                "SRM Collecte doit etre selectionnee comme application de position fictive Android."
            )
        }

        mockProviders.forEach { provider ->
            try {
                addTestProvider(provider)
            } catch (_: IllegalArgumentException) {
                // Provider deja en mode test.
            }
            @Suppress("DEPRECATION")
            locationManager.setTestProviderEnabled(provider, true)
        }
    }

    @Suppress("DEPRECATION")
    private fun addTestProvider(provider: String) {
        val requiresNetwork = provider == LocationManager.NETWORK_PROVIDER
        val requiresSatellite = provider == LocationManager.GPS_PROVIDER
        locationManager.addTestProvider(
            provider,
            requiresNetwork,
            requiresSatellite,
            false,
            false,
            true,
            true,
            true,
            Criteria.POWER_HIGH,
            Criteria.ACCURACY_FINE,
        )
    }

    private fun removeMockProviders() {
        mockProviders.forEach { provider ->
            try {
                locationManager.removeTestProvider(provider)
            } catch (_: Exception) {
                // Ignore cleanup errors; the provider may not be active.
            }
        }
    }

    private fun stopMockProviders() {
        removeMockProviders()
        bridgeStatus = "idle"
    }

    private fun injectMockLocation(
        latitude: Double,
        longitude: Double,
        altitude: Double?,
        accuracy: Float,
        speed: Float?,
        bearing: Float?,
        nmea: String?,
        fixQuality: Int? = null,
        satellites: Int? = null,
        hdop: Float? = null,
        projectedX: Double? = null,
        projectedY: Double? = null,
        projectedZ: Double? = null,
        coordinateSource: String? = null,
    ): Map<String, Any?> {
        ensureMockProviders()

        val safeAccuracy = accuracy.takeIf { it > 0f } ?: 1.0f
        val now = System.currentTimeMillis()
        val source = "nmea_bridge"
        val location = Location(LocationManager.GPS_PROVIDER).apply {
            this.latitude = latitude
            this.longitude = longitude
            this.accuracy = safeAccuracy
            this.time = now
            if (altitude != null) this.altitude = altitude
            if (speed != null) this.speed = speed
            if (bearing != null) this.bearing = bearing
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                verticalAccuracyMeters = safeAccuracy
                speedAccuracyMetersPerSecond = safeAccuracy
                bearingAccuracyDegrees = 1.0f
            }
        }

        mockProviders.forEach { provider ->
            locationManager.setTestProviderLocation(
                provider,
                copyLocationForProvider(location, provider),
            )
        }

        bridgeStatus = "mock_location_pushed"
        lastNmea = nmea ?: lastNmea
        lastLocationPayload = mapOf(
            "source" to source,
            "latitude" to latitude,
            "longitude" to longitude,
            "altitude" to altitude,
            "x" to projectedX,
            "y" to projectedY,
            "z" to projectedZ,
            "accuracy" to safeAccuracy.toDouble(),
            "speed" to speed?.toDouble(),
            "bearing" to bearing?.toDouble(),
            "time" to now,
            "nmeaReceivedAt" to now,
            "mockInjectedAt" to now,
            "nmea" to nmea,
            "fixQuality" to fixQuality,
            "satellites" to satellites,
            "hdop" to hdop?.toDouble(),
            "coordinateSource" to coordinateSource,
            "bluetoothName" to currentBluetoothName,
            "bluetoothAddress" to currentBluetoothAddress,
        )
        val deviceLabel = currentBluetoothName ?: currentBluetoothAddress ?: "unknown"
        Log.i(
            "SRM-NMEA",
            "fix source=$source device=$deviceLabel " +
                "lat=$latitude lon=$longitude x=$projectedX y=$projectedY z=$projectedZ " +
                "altitude=$altitude accuracy=$safeAccuracy " +
                "fixQuality=$fixQuality satellites=$satellites hdop=$hdop nmeaTimestamp=$now"
        )
        return lastLocationPayload!!
    }

    private fun copyLocationForProvider(source: Location, provider: String): Location {
        return Location(provider).apply {
            latitude = source.latitude
            longitude = source.longitude
            accuracy = source.accuracy
            time = source.time
            if (source.hasAltitude()) altitude = source.altitude
            if (source.hasSpeed()) speed = source.speed
            if (source.hasBearing()) bearing = source.bearing
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                elapsedRealtimeNanos = source.elapsedRealtimeNanos
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (source.hasVerticalAccuracy()) {
                    verticalAccuracyMeters = source.verticalAccuracyMeters
                }
                if (source.hasSpeedAccuracy()) {
                    speedAccuracyMetersPerSecond = source.speedAccuracyMetersPerSecond
                }
                if (source.hasBearingAccuracy()) {
                    bearingAccuracyDegrees = source.bearingAccuracyDegrees
                }
            }
        }
    }

    private fun listBondedBluetoothDevices(): List<Map<String, String?>> {
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: error("Bluetooth indisponible sur cet appareil")
        return adapter.bondedDevices.map { device ->
            mapOf(
                "name" to device.name,
                "address" to device.address,
            )
        }.sortedBy { it["name"] ?: it["address"] ?: "" }
    }

    private fun connectBluetooth(address: String) {
        disconnectBluetooth()
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: error("Bluetooth indisponible sur cet appareil")
        val device = adapter.getRemoteDevice(address)
        currentBluetoothName = device.name
        currentBluetoothAddress = address
        bridgeStatus = "bluetooth_connecting"

        bluetoothThread = thread(start = true, name = "srm-nmea-bridge") {
            try {
                adapter.cancelDiscovery()
                val socket = device.createRfcommSocketToServiceRecord(sppUuid)
                bluetoothSocket = socket
                socket.connect()
                bridgeStatus = "bluetooth_connected"

                val reader = BufferedReader(InputStreamReader(socket.inputStream))
                while (!Thread.currentThread().isInterrupted) {
                    val line = reader.readLine() ?: break
                    val trimmed = line.trim()
                    if (trimmed.startsWith("$")) {
                        lastNmea = trimmed
                        parseNmea(trimmed)?.let { parsed ->
                            val latitude = parsed.latitude ?: return@let
                            val longitude = parsed.longitude ?: return@let
                            injectMockLocation(
                                latitude = latitude,
                                longitude = longitude,
                                altitude = parsed.altitude,
                                accuracy = parsed.accuracy,
                                speed = parsed.speed,
                                bearing = parsed.bearing,
                                nmea = trimmed,
                                fixQuality = parsed.fixQuality,
                                satellites = parsed.satellites,
                                hdop = parsed.hdop,
                                projectedX = parsed.projectedX,
                                projectedY = parsed.projectedY,
                                projectedZ = parsed.projectedZ,
                                coordinateSource = parsed.coordinateSource,
                            )
                            bridgeStatus = "nmea_streaming"
                        }
                    }
                }
            } catch (e: Exception) {
                bridgeStatus = "bluetooth_error: ${e.message}"
            } finally {
                try {
                    bluetoothSocket?.close()
                } catch (_: Exception) {
                    // Ignore close errors after a Bluetooth drop.
                }
                bluetoothSocket = null
                removeMockProviders()
                if (!bridgeStatus.startsWith("bluetooth_error")) {
                    bridgeStatus = "bluetooth_disconnected"
                }
            }
        }
    }

    private fun disconnectBluetooth() {
        bluetoothThread?.interrupt()
        bluetoothThread = null
        bluetoothSocket?.close()
        bluetoothSocket = null
        removeMockProviders()
        if (bridgeStatus.startsWith("bluetooth") || bridgeStatus == "nmea_streaming") {
            bridgeStatus = "bluetooth_disconnected"
        }
    }

    private fun statusPayload(): Map<String, Any?> {
        return mapOf(
            "status" to bridgeStatus,
            "mockLocationSelected" to isMockLocationSelected(),
            "lastNmea" to lastNmea,
            "lastLocation" to lastLocationPayload,
            "bluetoothName" to currentBluetoothName,
            "bluetoothAddress" to currentBluetoothAddress,
        )
    }

    private data class ParsedNmeaLocation(
        val latitude: Double?,
        val longitude: Double?,
        val altitude: Double?,
        val accuracy: Float,
        val speed: Float?,
        val bearing: Float?,
        val fixQuality: Int?,
        val satellites: Int?,
        val hdop: Float?,
        val projectedX: Double? = null,
        val projectedY: Double? = null,
        val projectedZ: Double? = null,
        val coordinateSource: String? = null,
    )

    private fun parseNmea(sentence: String): ParsedNmeaLocation? {
        val clean = sentence.trim()
        if (!clean.startsWith("$")) return null
        val body = clean.substring(1).substringBefore("*")
        val parts = body.split(",")
        if (parts.isEmpty()) return null
        val type = parts[0].uppercase(Locale.US)
        val subtype = parts.getOrNull(1)?.uppercase(Locale.US)
        if (type.endsWith("GST") || subtype == "GST") {
            cacheGstAccuracy(parts)
            return null
        }
        val parsed = when {
            type.endsWith("GGA") -> parseGga(parts)
            type.endsWith("RMC") -> parseRmc(parts)
            type.endsWith("PJK") || subtype == "PJK" -> parsePjk(parts)
            else -> null
        }
        return mergeParsedFix(parsed)
    }

    private fun mergeParsedFix(parsed: ParsedNmeaLocation?): ParsedNmeaLocation? {
        if (parsed == null) return null
        val now = System.currentTimeMillis()
        if (parsed.latitude != null && parsed.longitude != null) {
            lastGeographicFix = parsed
            lastGeographicFixAtMs = now
        }
        if (parsed.projectedX != null || parsed.projectedY != null || parsed.projectedZ != null) {
            lastProjectedFix = parsed
            lastProjectedFixAtMs = now
        }

        val geographic = if (now - lastGeographicFixAtMs <= fixMergeFreshnessWindowMs) {
            lastGeographicFix
        } else null
        val projected = if (now - lastProjectedFixAtMs <= fixMergeFreshnessWindowMs) {
            lastProjectedFix
        } else null

        val mergedLatitude = parsed.latitude ?: geographic?.latitude
        val mergedLongitude = parsed.longitude ?: geographic?.longitude
        if (mergedLatitude == null || mergedLongitude == null) {
            return null
        }

        return ParsedNmeaLocation(
            latitude = mergedLatitude,
            longitude = mergedLongitude,
            altitude = parsed.projectedZ ?: parsed.altitude ?: projected?.projectedZ ?: geographic?.altitude,
            accuracy = parsed.accuracy.takeIf { it > 0f }
                ?: projected?.accuracy
                ?: geographic?.accuracy
                ?: 2.0f,
            speed = parsed.speed ?: geographic?.speed,
            bearing = parsed.bearing ?: geographic?.bearing,
            fixQuality = parsed.fixQuality ?: projected?.fixQuality ?: geographic?.fixQuality,
            satellites = parsed.satellites ?: projected?.satellites ?: geographic?.satellites,
            hdop = parsed.hdop ?: projected?.hdop ?: geographic?.hdop,
            projectedX = parsed.projectedX ?: projected?.projectedX,
            projectedY = parsed.projectedY ?: projected?.projectedY,
            projectedZ = parsed.projectedZ ?: projected?.projectedZ ?: parsed.altitude,
            coordinateSource = parsed.coordinateSource ?: projected?.coordinateSource ?: geographic?.coordinateSource,
        )
    }

    private fun cacheGstAccuracy(parts: List<String>) {
        if (parts.size < 9) return
        val sigmaLat = parts[6].toFloatOrNull() ?: return
        val sigmaLon = parts[7].toFloatOrNull() ?: return
        val radial = kotlin.math.sqrt(
            (sigmaLat * sigmaLat + sigmaLon * sigmaLon).toDouble()
        ).toFloat()
        if (radial.isNaN() || radial <= 0f) return
        lastGstAccuracy = radial
        lastGstAccuracyAtMs = System.currentTimeMillis()
    }

    private fun resolveAccuracy(hdop: Float?): Float {
        val gstAge = System.currentTimeMillis() - lastGstAccuracyAtMs
        val cached = lastGstAccuracy
        if (cached != null && gstAge in 0..gstFreshnessWindowMs) {
            return cached.coerceAtLeast(0.001f)
        }
        return ((hdop ?: 0.2f) * 2.0f).coerceAtLeast(0.2f)
    }

    private fun parseGga(parts: List<String>): ParsedNmeaLocation? {
        if (parts.size < 10) return null
        val fixQuality = parts[6].toIntOrNull() ?: 0
        if (fixQuality <= 0) return null
        val satellites = parts[7].toIntOrNull()
        val latitude = parseNmeaCoordinate(parts[2], parts[3], isLatitude = true)
            ?: return null
        val longitude = parseNmeaCoordinate(parts[4], parts[5], isLatitude = false)
            ?: return null
        val hdop = parts[8].toFloatOrNull()
        val altitude = parts[9].toDoubleOrNull()
        return ParsedNmeaLocation(
            latitude = latitude,
            longitude = longitude,
            altitude = altitude,
            accuracy = resolveAccuracy(hdop),
            speed = null,
            bearing = null,
            fixQuality = fixQuality,
            satellites = satellites,
            hdop = hdop,
            coordinateSource = "gga",
        )
    }

    private fun parseRmc(parts: List<String>): ParsedNmeaLocation? {
        if (parts.size < 9) return null
        if (!parts[2].equals("A", ignoreCase = true)) return null
        val latitude = parseNmeaCoordinate(parts[3], parts[4], isLatitude = true)
            ?: return null
        val longitude = parseNmeaCoordinate(parts[5], parts[6], isLatitude = false)
            ?: return null
        val speedKnots = parts[7].toFloatOrNull()
        val bearing = parts[8].toFloatOrNull()
        return ParsedNmeaLocation(
            latitude = latitude,
            longitude = longitude,
            altitude = null,
            accuracy = 2.0f,
            speed = speedKnots?.let { it * 0.514444f },
            bearing = bearing,
            fixQuality = null,
            satellites = null,
            hdop = null,
            coordinateSource = "rmc",
        )
    }

    private fun parsePjk(parts: List<String>): ParsedNmeaLocation? {
        if (parts.size < 4) return null

        val northing = extractProjectedCoordinate(parts, positiveMarker = "N", negativeMarker = "S")
        val easting = extractProjectedCoordinate(parts, positiveMarker = "E", negativeMarker = "W")
        val fallbackCoords = extractFallbackProjectedCoordinates(parts)
        val projectedY = northing ?: fallbackCoords?.first
        val projectedX = easting ?: fallbackCoords?.second
        if (projectedX == null || projectedY == null) return null

        val altitude = extractAltitudeMeters(parts)
        val fixQuality = extractLikelyFixQuality(parts)
        val satellites = extractLikelySatellites(parts)
        val hdop = extractLikelyHdop(parts)

        return ParsedNmeaLocation(
            latitude = null,
            longitude = null,
            altitude = altitude,
            accuracy = resolveAccuracy(hdop),
            speed = null,
            bearing = null,
            fixQuality = fixQuality,
            satellites = satellites,
            hdop = hdop,
            projectedX = projectedX,
            projectedY = projectedY,
            projectedZ = altitude,
            coordinateSource = "pjk",
        )
    }

    private fun extractProjectedCoordinate(
        parts: List<String>,
        positiveMarker: String,
        negativeMarker: String,
    ): Double? {
        for (index in 0 until parts.size - 1) {
            val value = parts[index].toDoubleOrNull() ?: continue
            if (kotlin.math.abs(value) <= 180.0 || kotlin.math.abs(value) >= 2_000_000.0) continue
            when (parts[index + 1].trim().uppercase(Locale.US)) {
                positiveMarker -> return value
                negativeMarker -> return -value
            }
        }
        return null
    }

    private fun extractFallbackProjectedCoordinates(parts: List<String>): Pair<Double, Double>? {
        val candidates = mutableListOf<Double>()
        for (part in parts) {
            val value = part.toDoubleOrNull() ?: continue
            if (kotlin.math.abs(value) <= 180.0 || kotlin.math.abs(value) >= 2_000_000.0) continue
            candidates.add(value)
        }
        if (candidates.size < 2) return null
        return candidates[0] to candidates[1]
    }

    private fun extractAltitudeMeters(parts: List<String>): Double? {
        var fallback: Double? = null
        for (index in 0 until parts.size - 1) {
            val value = parts[index].toDoubleOrNull() ?: continue
            val marker = parts[index + 1].trim().uppercase(Locale.US)
            if (marker != "M") continue
            if (kotlin.math.abs(value) > 100_000.0) continue
            fallback = value
        }
        return fallback
    }

    private fun extractLikelyFixQuality(parts: List<String>): Int? {
        val fixQualityValues = setOf(1, 2, 4, 5, 6)
        for (part in parts) {
            val value = part.toIntOrNull() ?: continue
            if (value in fixQualityValues) return value
        }
        return null
    }

    private fun extractLikelySatellites(parts: List<String>): Int? {
        for (part in parts) {
            val value = part.toIntOrNull() ?: continue
            if (value in 3..60) return value
        }
        return null
    }

    private fun extractLikelyHdop(parts: List<String>): Float? {
        for (part in parts) {
            val value = part.toFloatOrNull() ?: continue
            if (value in 0.1f..50.0f) return value
        }
        return null
    }

    private fun parseNmeaCoordinate(
        value: String,
        hemisphere: String,
        isLatitude: Boolean,
    ): Double? {
        if (value.isBlank() || hemisphere.isBlank()) return null
        val degreeDigits = if (isLatitude) 2 else 3
        if (value.length <= degreeDigits) return null
        val degrees = value.substring(0, degreeDigits).toDoubleOrNull() ?: return null
        val minutes = value.substring(degreeDigits).toDoubleOrNull() ?: return null
        var decimal = degrees + (minutes / 60.0)
        if (hemisphere.equals("S", ignoreCase = true) ||
            hemisphere.equals("W", ignoreCase = true)
        ) {
            decimal *= -1.0
        }
        return decimal
    }
}
