/**
 * Cloudflare Worker to proxy GTFS data requests
 * This solves CORS issues when fetching GTFS feeds from transit agencies
 */

export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight requests
    if (request.method === 'OPTIONS') {
      return handleOptions(request);
    }

    // Only allow GET requests
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405 });
    }

    try {
      // Get the target URL from query parameter
      const url = new URL(request.url);
      const targetUrl = url.searchParams.get('url');

      if (!targetUrl) {
        return new Response('Missing url parameter', { status: 400 });
      }

      // Validate that it's a GTFS URL (optional security measure)
      if (!targetUrl.endsWith('.zip') && !targetUrl.includes('gtfs')) {
        return new Response('Invalid GTFS URL', { status: 400 });
      }

      // Fetch the GTFS data
      const gtfsResponse = await fetch(targetUrl, {
        headers: {
          'User-Agent': 'TrainTimesApp/1.0',
        },
      });

      if (!gtfsResponse.ok) {
        return new Response(`Failed to fetch GTFS data: ${gtfsResponse.status}`, {
          status: gtfsResponse.status,
        });
      }

      // Create response with CORS headers
      const response = new Response(gtfsResponse.body, {
        status: gtfsResponse.status,
        statusText: gtfsResponse.statusText,
        headers: {
          'Content-Type': gtfsResponse.headers.get('Content-Type') || 'application/zip',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
          'Cache-Control': 'public, max-age=3600', // Cache for 1 hour
        },
      });

      return response;
    } catch (error) {
      return new Response(`Error: ${error.message}`, {
        status: 500,
        headers: {
          'Access-Control-Allow-Origin': '*',
        },
      });
    }
  },
};

function handleOptions(request) {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
  };

  return new Response(null, {
    status: 204,
    headers,
  });
}
