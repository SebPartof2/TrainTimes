-- Train Times D1 Database Schema
-- Stores parsed GTFS data for fast querying

-- Agencies table
CREATE TABLE IF NOT EXISTS agencies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  gtfs_url TEXT NOT NULL,
  website TEXT,
  timezone TEXT,
  default_route_types TEXT, -- JSON array of route types
  last_updated INTEGER -- Unix timestamp
);

-- Stops table (stations)
CREATE TABLE IF NOT EXISTS stops (
  stop_id TEXT NOT NULL,
  agency_id TEXT NOT NULL,
  stop_name TEXT NOT NULL,
  stop_lat REAL,
  stop_lon REAL,
  stop_code TEXT,
  stop_desc TEXT,
  zone_id TEXT,
  stop_url TEXT,
  location_type INTEGER,
  parent_station TEXT,
  wheelchair_boarding TEXT,
  PRIMARY KEY (stop_id, agency_id),
  FOREIGN KEY (agency_id) REFERENCES agencies(id) ON DELETE CASCADE
);

-- Routes table
CREATE TABLE IF NOT EXISTS routes (
  route_id TEXT NOT NULL,
  agency_id TEXT NOT NULL,
  route_short_name TEXT,
  route_long_name TEXT,
  route_type INTEGER NOT NULL,
  route_color TEXT,
  route_text_color TEXT,
  PRIMARY KEY (route_id, agency_id),
  FOREIGN KEY (agency_id) REFERENCES agencies(id) ON DELETE CASCADE
);

-- Stop-Route junction (which routes serve which stops)
CREATE TABLE IF NOT EXISTS stop_routes (
  stop_id TEXT NOT NULL,
  route_id TEXT NOT NULL,
  agency_id TEXT NOT NULL,
  PRIMARY KEY (stop_id, route_id, agency_id),
  FOREIGN KEY (stop_id, agency_id) REFERENCES stops(stop_id, agency_id) ON DELETE CASCADE,
  FOREIGN KEY (route_id, agency_id) REFERENCES routes(route_id, agency_id) ON DELETE CASCADE
);

-- Trips table (for linking stop_times to routes)
CREATE TABLE IF NOT EXISTS trips (
  trip_id TEXT NOT NULL,
  agency_id TEXT NOT NULL,
  route_id TEXT NOT NULL,
  service_id TEXT,
  trip_headsign TEXT,
  PRIMARY KEY (trip_id, agency_id),
  FOREIGN KEY (agency_id) REFERENCES agencies(id) ON DELETE CASCADE,
  FOREIGN KEY (route_id, agency_id) REFERENCES routes(route_id, agency_id) ON DELETE CASCADE
);

-- Stop times (for departure schedules)
-- NOTE: This table can get very large (millions of rows)
-- Consider filtering to only today's service or using GTFS-RT instead
CREATE TABLE IF NOT EXISTS stop_times (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agency_id TEXT NOT NULL,
  trip_id TEXT NOT NULL,
  stop_id TEXT NOT NULL,
  arrival_time TEXT NOT NULL,
  departure_time TEXT NOT NULL,
  stop_sequence INTEGER NOT NULL,
  stop_headsign TEXT,
  pickup_type INTEGER,
  drop_off_type INTEGER,
  FOREIGN KEY (agency_id) REFERENCES agencies(id) ON DELETE CASCADE,
  FOREIGN KEY (trip_id, agency_id) REFERENCES trips(trip_id, agency_id) ON DELETE CASCADE,
  FOREIGN KEY (stop_id, agency_id) REFERENCES stops(stop_id, agency_id) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_stops_agency ON stops(agency_id);
CREATE INDEX IF NOT EXISTS idx_routes_agency ON routes(agency_id);
CREATE INDEX IF NOT EXISTS idx_routes_type ON routes(route_type);
CREATE INDEX IF NOT EXISTS idx_stop_routes_stop ON stop_routes(stop_id);
CREATE INDEX IF NOT EXISTS idx_stop_routes_route ON stop_routes(route_id);
CREATE INDEX IF NOT EXISTS idx_stop_routes_agency ON stop_routes(agency_id);
CREATE INDEX IF NOT EXISTS idx_stop_times_stop ON stop_times(stop_id);
CREATE INDEX IF NOT EXISTS idx_stop_times_trip ON stop_times(trip_id);
CREATE INDEX IF NOT EXISTS idx_stop_times_agency ON stop_times(agency_id);
CREATE INDEX IF NOT EXISTS idx_trips_route ON trips(route_id);
CREATE INDEX IF NOT EXISTS idx_trips_agency ON trips(agency_id);

-- Insert initial agency configurations
INSERT OR REPLACE INTO agencies (id, name, gtfs_url, website, timezone, default_route_types, last_updated)
VALUES
  ('metra', 'Metra', 'https://schedules.metrarail.com/gtfs/schedule.zip', 'https://metra.com', 'America/Chicago', '[2]', NULL),
  ('cta', 'CTA', 'https://www.transitchicago.com/downloads/sch_data/google_transit.zip', 'https://transitchicago.com', 'America/Chicago', '[1]', NULL);
