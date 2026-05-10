"""Bluetooth NMEA GPS simulator for SRM Collecte demos.

Sends NMEA 0183 sentences (GPGGA + GPRMC) at a configurable rate to a serial
port. Intended use: pair an Android phone with the PC, expose an "Incoming"
Bluetooth COM port on Windows, then run this script. A companion app on the
phone (e.g. "Bluetooth GPS" by GG MobLab) reads the NMEA stream and feeds the
Android mock-location provider, so the Flutter app sees a simulated fix.

Setup (Windows + Android):
    1. Pair the phone with the PC.
    2. Bluetooth settings -> "More Bluetooth options" -> tab "COM Ports"
       -> "Add" -> "Incoming". Note the assigned COM number (e.g. COM3).
    3. pip install pyserial
    4. python tools/gps_simulator_bt.py --port COM3
    5. On the phone: install "Bluetooth GPS", connect to the PC, then enable
       Developer Options > "Select mock location app" -> Bluetooth GPS.

Examples:
    python tools/gps_simulator_bt.py --list
    python tools/gps_simulator_bt.py --port COM3
    python tools/gps_simulator_bt.py --port COM3 --lat 34.70 --lon -1.91
    python tools/gps_simulator_bt.py --port COM3 --mode route \
        --route tools/gps_routes/oujda_demo.json --speed 25 --loop
    python tools/gps_simulator_bt.py --dry-run --mode route \
        --route tools/gps_routes/oujda_demo.json --speed 40
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    print("ERROR: pyserial not installed. Run: pip install pyserial", file=sys.stderr)
    sys.exit(1)


OUJDA_CENTER = (34.6814, -1.9086)
DEFAULT_ALTITUDE_M = 470.0
EARTH_R = 6371000.0


def nmea_checksum(body: str) -> str:
    cs = 0
    for ch in body:
        cs ^= ord(ch)
    return f"{cs:02X}"


def deg_to_nmea(value: float, is_lat: bool) -> tuple[str, str]:
    if is_lat:
        hemi = "N" if value >= 0 else "S"
        width = 2
    else:
        hemi = "E" if value >= 0 else "W"
        width = 3
    v = abs(value)
    deg = int(v)
    minutes = (v - deg) * 60.0
    return f"{deg:0{width}d}{minutes:07.4f}", hemi


def build_gga(t: datetime, lat: float, lon: float, alt: float) -> str:
    lat_str, ns = deg_to_nmea(lat, True)
    lon_str, ew = deg_to_nmea(lon, False)
    hms = t.strftime("%H%M%S.00")
    body = (
        f"GPGGA,{hms},{lat_str},{ns},{lon_str},{ew},"
        f"1,10,0.9,{alt:.1f},M,0.0,M,,"
    )
    return f"${body}*{nmea_checksum(body)}\r\n"


def build_rmc(t: datetime, lat: float, lon: float, speed_knots: float, course_deg: float) -> str:
    lat_str, ns = deg_to_nmea(lat, True)
    lon_str, ew = deg_to_nmea(lon, False)
    hms = t.strftime("%H%M%S.00")
    dmy = t.strftime("%d%m%y")
    body = (
        f"GPRMC,{hms},A,{lat_str},{ns},{lon_str},{ew},"
        f"{speed_knots:.2f},{course_deg:.2f},{dmy},,,A"
    )
    return f"${body}*{nmea_checksum(body)}\r\n"


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * EARTH_R * math.asin(math.sqrt(a))


def initial_bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2 - lon1)
    y = math.sin(dl) * math.cos(p2)
    x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.degrees(math.atan2(y, x)) + 360.0) % 360.0


def move_along(lat: float, lon: float, bearing_deg: float, distance_m: float) -> tuple[float, float]:
    p1 = math.radians(lat)
    l1 = math.radians(lon)
    br = math.radians(bearing_deg)
    d_r = distance_m / EARTH_R
    p2 = math.asin(
        math.sin(p1) * math.cos(d_r) + math.cos(p1) * math.sin(d_r) * math.cos(br)
    )
    l2 = l1 + math.atan2(
        math.sin(br) * math.sin(d_r) * math.cos(p1),
        math.cos(d_r) - math.sin(p1) * math.sin(p2),
    )
    return math.degrees(p2), math.degrees(l2)


class StaticSource:
    def __init__(self, lat: float, lon: float, alt: float, jitter_m: float):
        self.lat = lat
        self.lon = lon
        self.alt = alt
        self.jitter = max(0.0, jitter_m)

    def step(self, dt: float) -> tuple[float, float, float, float, float]:
        if self.jitter == 0.0:
            return self.lat, self.lon, self.alt, 0.0, 0.0
        bearing = random.uniform(0.0, 360.0)
        dist = random.uniform(0.0, self.jitter)
        lat, lon = move_along(self.lat, self.lon, bearing, dist)
        return lat, lon, self.alt, 0.0, 0.0


class RouteSource:
    def __init__(self, waypoints: list[tuple[float, float]], speed_kmh: float, alt: float, loop: bool):
        if len(waypoints) < 2:
            raise ValueError("Route mode needs at least 2 waypoints")
        self.wps = waypoints
        self.speed_ms = max(0.1, speed_kmh) / 3.6
        self.alt = alt
        self.loop = loop
        self.idx = 0
        self.lat, self.lon = waypoints[0]
        self.next_lat, self.next_lon = waypoints[1]
        self.bearing = initial_bearing(self.lat, self.lon, self.next_lat, self.next_lon)
        self.finished = False

    def _advance_segment(self) -> bool:
        self.idx += 1
        if self.idx >= len(self.wps) - 1:
            if not self.loop:
                self.finished = True
                return False
            self.idx = 0
            self.lat, self.lon = self.wps[0]
        self.next_lat, self.next_lon = self.wps[self.idx + 1]
        self.bearing = initial_bearing(self.lat, self.lon, self.next_lat, self.next_lon)
        return True

    def step(self, dt: float) -> tuple[float, float, float, float, float]:
        if self.finished:
            return self.lat, self.lon, self.alt, 0.0, self.bearing
        travel = self.speed_ms * dt
        while travel > 0.0 and not self.finished:
            remaining = haversine(self.lat, self.lon, self.next_lat, self.next_lon)
            if travel < remaining:
                self.lat, self.lon = move_along(self.lat, self.lon, self.bearing, travel)
                travel = 0.0
            else:
                self.lat, self.lon = self.next_lat, self.next_lon
                travel -= remaining
                if not self._advance_segment():
                    break
        speed_knots = self.speed_ms * 1.943844
        return self.lat, self.lon, self.alt, speed_knots, self.bearing


def list_com_ports() -> None:
    ports = list(list_ports.comports())
    if not ports:
        print("No COM ports detected. Pair the phone and add an incoming Bluetooth COM port.")
        return
    print(f"{len(ports)} COM port(s) detected:")
    for p in ports:
        print(f"  {p.device:<8} {p.description}")


def load_route(path: Path) -> list[tuple[float, float]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    wps: list[tuple[float, float]] = []
    for item in data:
        if isinstance(item, dict):
            wps.append((float(item["lat"]), float(item["lon"])))
        elif isinstance(item, (list, tuple)) and len(item) >= 2:
            wps.append((float(item[0]), float(item[1])))
        else:
            raise ValueError(f"Invalid waypoint entry: {item!r}")
    if len(wps) < 2:
        raise ValueError("Route file must contain at least 2 waypoints")
    return wps


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(description="Bluetooth NMEA GPS simulator for Android demos.")
    ap.add_argument("--list", action="store_true", help="List available COM ports and exit")
    ap.add_argument("--port", help="Serial COM port to write NMEA to (e.g. COM3)")
    ap.add_argument("--baud", type=int, default=9600)
    ap.add_argument("--mode", choices=("static", "route"), default="static")
    ap.add_argument("--lat", type=float, default=OUJDA_CENTER[0], help="Latitude for static mode (default: Oujda)")
    ap.add_argument("--lon", type=float, default=OUJDA_CENTER[1], help="Longitude for static mode (default: Oujda)")
    ap.add_argument("--alt", type=float, default=DEFAULT_ALTITUDE_M, help="Altitude in meters")
    ap.add_argument("--jitter", type=float, default=1.5, help="Static random walk amplitude in meters")
    ap.add_argument("--route", help="Path to JSON waypoint list for route mode")
    ap.add_argument("--speed", type=float, default=20.0, help="Route speed in km/h")
    ap.add_argument("--rate", type=float, default=1.0, help="NMEA emission rate in Hz")
    ap.add_argument("--loop", action="store_true", help="Restart route when finished")
    ap.add_argument("--dry-run", action="store_true", help="Print NMEA to stdout instead of opening a serial port")
    return ap.parse_args()


def main() -> int:
    args = parse_args()

    if args.list:
        list_com_ports()
        return 0

    if args.mode == "route":
        if not args.route:
            print("ERROR: --route <file.json> required for route mode", file=sys.stderr)
            return 2
        waypoints = load_route(Path(args.route))
        source: StaticSource | RouteSource = RouteSource(waypoints, args.speed, args.alt, args.loop)
    else:
        source = StaticSource(args.lat, args.lon, args.alt, args.jitter)

    if not args.dry_run and not args.port:
        print("ERROR: --port required (or use --dry-run / --list)", file=sys.stderr)
        return 2

    ser: serial.Serial | None = None
    if not args.dry_run:
        try:
            ser = serial.Serial(args.port, args.baud, timeout=1)
        except serial.SerialException as e:
            print(f"ERROR: cannot open {args.port}: {e}", file=sys.stderr)
            return 1
        print(f"Opened {args.port} @ {args.baud} baud. Waiting for phone to connect...")

    period = 1.0 / max(args.rate, 0.1)
    print(f"Mode={args.mode} rate={args.rate}Hz. Ctrl+C to stop.")

    next_tick = time.monotonic()
    last_t = time.monotonic()
    try:
        while True:
            now_mono = time.monotonic()
            dt = now_mono - last_t
            last_t = now_mono

            lat, lon, alt, speed_knots, course = source.step(dt)
            t = datetime.now(timezone.utc)
            payload = (build_gga(t, lat, lon, alt) + build_rmc(t, lat, lon, speed_knots, course)).encode("ascii")

            if ser is not None:
                try:
                    ser.write(payload)
                    ser.flush()
                except serial.SerialException as e:
                    print(f"Serial write failed: {e}", file=sys.stderr)
                    return 1
            else:
                sys.stdout.write(payload.decode("ascii"))

            print(
                f"[{t.strftime('%H:%M:%S')}Z] lat={lat:.6f} lon={lon:.6f} "
                f"spd={speed_knots * 1.852:6.2f}km/h hdg={course:5.1f}",
                flush=True,
            )

            next_tick += period
            sleep_for = next_tick - time.monotonic()
            if sleep_for > 0:
                time.sleep(sleep_for)
            else:
                next_tick = time.monotonic()
    except KeyboardInterrupt:
        print("\nStopped by user.")
    finally:
        if ser is not None:
            ser.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
