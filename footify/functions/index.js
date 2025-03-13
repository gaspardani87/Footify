const functions = require('firebase-functions');
const axios = require('axios');

// API Key for football-data.org
const API_KEY = '4c553fac5d704101906782d1ecbe1b12';
const BASE_URL = 'https://api.football-data.org/v4';

// Helper function to set CORS headers
const setCorsHeaders = (res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
};

// Helper function to handle OPTIONS preflight requests
const handleOptions = (req, res) => {
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return true;
  }
  return false;
};

// Function to fetch all matches
exports.fetchFootballData = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  try {
    const response = await axios.get(`${BASE_URL}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error('Error fetching football data:', error.message);
    res.status(500).json({
      error: 'Failed to fetch football data',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch a specific match by ID
exports.fetchMatchById = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const matchId = req.query.id;
  if (!matchId) {
    res.status(400).json({ error: 'Missing match ID parameter' });
    return;
  }

  try {
    const response = await axios.get(`${BASE_URL}/matches/${matchId}`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error(`Error fetching match with ID ${matchId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch match data',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch competitions
exports.fetchCompetitions = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  try {
    const response = await axios.get(`${BASE_URL}/competitions`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error('Error fetching competitions:', error.message);
    res.status(500).json({
      error: 'Failed to fetch competitions',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch a specific competition by code
exports.fetchCompetitionByCode = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const code = req.query.code;
  if (!code) {
    res.status(400).json({ error: 'Missing competition code parameter' });
    return;
  }

  try {
    const response = await axios.get(`${BASE_URL}/competitions/${code}`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error(`Error fetching competition with code ${code}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch competition data',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch standings for a competition
exports.fetchStandings = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const code = req.query.code;
  if (!code) {
    res.status(400).json({ error: 'Missing competition code parameter' });
    return;
  }

  try {
    const response = await axios.get(`${BASE_URL}/competitions/${code}/standings`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error(`Error fetching standings for competition ${code}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch standings',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch team information
exports.fetchTeam = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const teamId = req.query.id;
  if (!teamId) {
    res.status(400).json({ error: 'Missing team ID parameter' });
    return;
  }

  try {
    const response = await axios.get(`${BASE_URL}/teams/${teamId}`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error(`Error fetching team with ID ${teamId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch team data',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch matches for a team
exports.fetchTeamMatches = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const teamId = req.query.id;
  if (!teamId) {
    res.status(400).json({ error: 'Missing team ID parameter' });
    return;
  }

  // Optional parameters
  const status = req.query.status; // SCHEDULED, LIVE, IN_PLAY, PAUSED, FINISHED, POSTPONED, SUSPENDED, CANCELED
  const dateFrom = req.query.dateFrom; // YYYY-MM-DD
  const dateTo = req.query.dateTo; // YYYY-MM-DD
  const limit = req.query.limit || 10;

  let url = `${BASE_URL}/teams/${teamId}/matches`;
  let params = {};
  
  if (status) params.status = status;
  if (dateFrom) params.dateFrom = dateFrom;
  if (dateTo) params.dateTo = dateTo;
  if (limit) params.limit = limit;

  try {
    const response = await axios.get(url, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: params
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error(`Error fetching matches for team ${teamId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch team matches',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch player information
exports.fetchPlayer = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const playerId = req.query.id;
  if (!playerId) {
    res.status(400).json({ error: 'Missing player ID parameter' });
    return;
  }

  try {
    const response = await axios.get(`${BASE_URL}/persons/${playerId}`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error(`Error fetching player with ID ${playerId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch player data',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to proxy images
exports.proxyImage = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const imageUrl = req.query.url;
  if (!imageUrl) {
    res.status(400).send('Missing url parameter');
    return;
  }

  try {
    const response = await axios.get(imageUrl, {
      responseType: 'arraybuffer',
    });
    res.set('Content-Type', response.headers['content-type'] || 'image/png'); // Fallback to PNG if unspecified
    res.status(200).send(response.data);
  } catch (error) {
    console.error('Error fetching image:', error.message);
    res.status(500).send(`Failed to fetch image: ${error.message}`);
  }
});