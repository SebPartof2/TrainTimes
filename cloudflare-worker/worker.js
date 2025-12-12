/**
 * Train Times API - Cloudflare Worker
 * Handles GTFS data processing and serves API endpoints for the Flutter app
 */

import { unzip } from 'fflate';

// Agency configurations
const AGENCIES = {
  metra: {
    id: 'metra',
    name: 'Metra',
    gtfsUrl: 'https://schedules.metrarail.com/gtfs/schedule.zip',
    website: 'https://metra.com',
    timezone: 'America/Chicago',
    defaultRouteTypes: [2], // Rail only
  },
  cta: {
    id: 'cta',
    name: 'CTA',
    gtfsUrl: 'https://www.transitchicago.com/downloads/sch_data/google_transit.zip',
    website: 'https://transitchicago.com',
    timezone: 'America/Chicago',
    defaultRouteTypes: [1], // Subway only
  },
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return handleCors(request);
    }

    // Route requests
    try {
      if (url.pathname === '/api/agencies') {
        return await handleGetAgencies(request, env);
      } else if (url.pathname === '/api/stations') {
        return await handleGetStations(request, env);
      } else if (url.pathname === '/api/departures') {
        return await handleGetDepartures(request, env);
      } else if (url.pathname === '/api/refresh' && request.method === 'POST') {
        return await handleRefresh(request, env);
      } else {
        return jsonResponse({ error: 'Not found' }, 404);
      }
    } catch (error) {
      console.error('Error:', error);
      return jsonResponse({ error: error.message }, 500);
    }
  },
};

/**
 * GET /api/agencies
 * Returns list of all configured transit agencies
 */
async function handleGetAgencies(request, env) {
  const agencies = Object.values(AGENCIES).map(agency => ({
    id: agency.id,
    name: agency.name,
    defaultRouteTypes: agency.defaultRouteTypes,
  }));

  return jsonResponse({ agencies });
}

/**
 * GET /api/stations?agency=cta&routeTypes=1
 * Returns filtered stations with their routes
 */
async function handleGetStations(request, env) {
  const url = new URL(request.url);
  const agencyId = url.searchParams.get('agency');
  const routeTypesParam = url.searchParams.get('routeTypes');

  if (!agencyId) {
    return jsonResponse({ error: 'Missing agency parameter' }, 400);
  }

  if (!AGENCIES[agencyId]) {
    return jsonResponse({ error: 'Invalid agency' }, 400);
  }

  const routeTypes = routeTypesParam
    ? routeTypesParam.split(',').map(t => parseInt(t.trim()))
    : AGENCIES[agencyId].defaultRouteTypes;

  // Query stations from D1
  const stations = await getStationsWithRoutes(env.DB, agencyId, routeTypes);

  return jsonResponse({ stations });
}

/**
 * GET /api/departures?stopId=30001&limit=15
 * Returns upcoming departures for a station
 */
async function handleGetDepartures(request, env) {
  const url = new URL(request.url);
  const stopId = url.searchParams.get('stopId');
  const limit = parseInt(url.searchParams.get('limit') || '15');

  if (!stopId) {
    return jsonResponse({ error: 'Missing stopId parameter' }, 400);
  }

  // Query departures from D1
  const departures = await getUpcomingDepartures(env.DB, stopId, limit);

  return jsonResponse({ departures });
}

/**
 * POST /api/refresh?agency=cta
 * Downloads and processes GTFS data, updates D1 database
 */
async function handleRefresh(request, env) {
  const url = new URL(request.url);
  const agencyId = url.searchParams.get('agency');

  if (!agencyId) {
    return jsonResponse({ error: 'Missing agency parameter' }, 400);
  }

  const agency = AGENCIES[agencyId];
  if (!agency) {
    return jsonResponse({ error: 'Invalid agency' }, 400);
  }

  // Download GTFS data
  const gtfsData = await downloadAndParseGTFS(agency.gtfsUrl);

  // Update database
  const stats = await updateDatabase(env.DB, agencyId, gtfsData);

  return jsonResponse({
    success: true,
    agency: agencyId,
    stats,
  });
}

/**
 * Download and parse GTFS ZIP file
 */
async function downloadAndParseGTFS(gtfsUrl) {
  const response = await fetch(gtfsUrl);
  if (!response.ok) {
    throw new Error(`Failed to download GTFS data: ${response.status}`);
  }

  const zipData = new Uint8Array(await response.arrayBuffer());

  // Unzip the GTFS data
  const files = await new Promise((resolve, reject) => {
    unzip(zipData, (err, unzipped) => {
      if (err) reject(err);
      else resolve(unzipped);
    });
  });

  // Parse required CSV files
  const stops = parseCSV(new TextDecoder().decode(files['stops.txt']));
  const routes = parseCSV(new TextDecoder().decode(files['routes.txt']));
  const trips = parseCSV(new TextDecoder().decode(files['trips.txt']));
  const stopTimes = parseCSV(new TextDecoder().decode(files['stop_times.txt']));

  return {
    stops,
    routes,
    trips,
    stopTimes,
  };
}

/**
 * Parse CSV data into array of objects
 */
function parseCSV(csvText) {
  const lines = csvText.split('\n').filter(line => line.trim());
  if (lines.length === 0) return [];

  const headers = lines[0].split(',').map(h => h.trim().replace(/"/g, ''));
  const rows = [];

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i];
    const values = parseCSVLine(line);

    if (values.length === headers.length) {
      const row = {};
      headers.forEach((header, index) => {
        row[header] = values[index];
      });
      rows.push(row);
    }
  }

  return rows;
}

/**
 * Parse a single CSV line, handling quoted fields
 */
function parseCSVLine(line) {
  const values = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];

    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      values.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }

  values.push(current.trim());
  return values;
}

/**
 * Update D1 database with parsed GTFS data
 */
async function updateDatabase(db, agencyId, gtfsData) {
  // Begin transaction
  const statements = [];

  // Delete old data for this agency
  statements.push(
    db.prepare('DELETE FROM stop_routes WHERE agency_id = ?').bind(agencyId),
    db.prepare('DELETE FROM stop_times WHERE agency_id = ?').bind(agencyId),
    db.prepare('DELETE FROM trips WHERE agency_id = ?').bind(agencyId),
    db.prepare('DELETE FROM routes WHERE agency_id = ?').bind(agencyId),
    db.prepare('DELETE FROM stops WHERE agency_id = ?').bind(agencyId)
  );

  // TODO: Insert new data
  // This requires implementing the GTFS parsing first

  // Execute all statements in a batch
  await db.batch(statements);

  return {
    stopsCount: gtfsData.stops?.length || 0,
    routesCount: gtfsData.routes?.length || 0,
  };
}

/**
 * Query stations with their routes from D1
 */
async function getStationsWithRoutes(db, agencyId, routeTypes) {
  // Build route type filter
  const routeTypePlaceholders = routeTypes.map(() => '?').join(',');

  // Query to get stations with their routes
  const query = `
    SELECT DISTINCT
      s.stop_id,
      s.stop_name,
      s.stop_lat,
      s.stop_lon,
      s.stop_code,
      s.stop_desc,
      s.location_type,
      s.parent_station,
      s.wheelchair_boarding,
      r.route_id,
      r.route_short_name,
      r.route_long_name,
      r.route_type,
      r.route_color,
      r.route_text_color
    FROM stops s
    INNER JOIN stop_routes sr ON s.stop_id = sr.stop_id AND s.agency_id = sr.agency_id
    INNER JOIN routes r ON sr.route_id = r.route_id AND sr.agency_id = r.agency_id
    WHERE s.agency_id = ?
      AND r.route_type IN (${routeTypePlaceholders})
      AND (s.location_type = 1 OR s.parent_station IS NULL OR s.parent_station = '')
    ORDER BY s.stop_name
  `;

  const stmt = db.prepare(query).bind(agencyId, ...routeTypes);
  const results = await stmt.all();

  // Group routes by station
  const stationsMap = new Map();

  for (const row of results.results) {
    const stopId = row.stop_id;

    if (!stationsMap.has(stopId)) {
      stationsMap.set(stopId, {
        stopId: row.stop_id,
        stopName: row.stop_name,
        stopLat: row.stop_lat,
        stopLon: row.stop_lon,
        stopCode: row.stop_code,
        stopDesc: row.stop_desc,
        locationType: row.location_type,
        parentStation: row.parent_station,
        wheelchairBoarding: row.wheelchair_boarding,
        routes: [],
      });
    }

    // Add route to station
    stationsMap.get(stopId).routes.push({
      routeId: row.route_id,
      routeShortName: row.route_short_name,
      routeLongName: row.route_long_name,
      routeType: row.route_type,
      routeColor: row.route_color,
      routeTextColor: row.route_text_color,
    });
  }

  return Array.from(stationsMap.values());
}

/**
 * Query upcoming departures from D1
 */
async function getUpcomingDepartures(db, stopId, limit) {
  const now = new Date();
  const currentHour = now.getHours();
  const currentMinute = now.getMinutes();
  const currentTimeInMinutes = currentHour * 60 + currentMinute;

  // Query stop times joined with trips and routes
  const query = `
    SELECT
      st.trip_id,
      st.departure_time,
      st.stop_headsign,
      r.route_short_name,
      r.route_long_name,
      r.route_color,
      r.route_text_color
    FROM stop_times st
    INNER JOIN trips t ON st.trip_id = t.trip_id AND st.agency_id = t.agency_id
    INNER JOIN routes r ON t.route_id = r.route_id AND t.agency_id = r.agency_id
    WHERE st.stop_id = ?
    ORDER BY st.departure_time
    LIMIT ?
  `;

  const stmt = db.prepare(query).bind(stopId, limit * 3); // Get more to filter
  const results = await stmt.all();

  // Filter for upcoming times only
  const departures = [];
  for (const row of results.results) {
    const timeParts = row.departure_time.split(':');
    if (timeParts.length === 3) {
      let hours = parseInt(timeParts[0]);
      const minutes = parseInt(timeParts[1]);

      // Handle times exceeding 24 hours (next day service)
      if (hours >= 24) {
        hours = hours % 24;
      }

      const departureMinutes = hours * 60 + minutes;

      // Only include future departures
      if (departureMinutes >= currentTimeInMinutes) {
        departures.push({
          tripId: row.trip_id,
          departureTime: row.departure_time,
          stopHeadsign: row.stop_headsign,
          route: {
            routeShortName: row.route_short_name,
            routeLongName: row.route_long_name,
            routeColor: row.route_color,
            routeTextColor: row.route_text_color,
          },
        });

        if (departures.length >= limit) break;
      }
    }
  }

  return departures;
}

/**
 * Handle CORS preflight requests
 */
function handleCors(request) {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Max-Age': '86400',
    },
  });
}

/**
 * Return JSON response with CORS headers
 */
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  });
}
