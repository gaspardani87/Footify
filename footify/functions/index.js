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

// Function to fetch leagues with their logos
exports.fetchLeagues = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  try {
    const response = await axios.get(`${BASE_URL}/competitions`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });

    // Process the response to include replacement logos where needed
    const leagues = response.data.competitions.map(league => {
      const replacementLogos = {
        2013: 'https://upload.wikimedia.org/wikipedia/en/0/04/Campeonato_Brasileiro_S%C3%A9rie_A.png',
        2018: 'https://static.wikia.nocookie.net/future/images/8/84/Euro_2028_Logo_Concept_v2.png/revision/latest?cb=20231020120018',
        2003: 'https://cdn.freelogovectors.net/wp-content/uploads/2021/08/eredivisie_logo-freelogovectors.net_.png',
        2000: 'https://upload.wikimedia.org/wikipedia/en/thumb/1/17/2026_FIFA_World_Cup_emblem.svg/1200px-2026_FIFA_World_Cup_emblem.svg.png',
        2015: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Ligue1_Uber_Eats_logo.png/640px-Ligue1_Uber_Eats_logo.png',
        2019: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/Serie_A_logo_2022.svg/800px-Serie_A_logo_2022.svg.png',
        2014: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/LaLiga_logo_2023.svg/2048px-LaLiga_logo_2023.svg.png',
        2021: 'https://b.fssta.com/uploads/application/soccer/competition-logos/EnglishPremierLeague.vresize.350.350.medium.0.png',
        2152: 'https://upload.wikimedia.org/wikipedia/en/thumb/a/a1/Copa_Libertadores_logo.svg/800px-Copa_Libertadores_logo.svg.png',
      };

      return {
        id: league.id,
        name: league.name,
        logo: replacementLogos[league.id] || league.emblem || league.crest || league.logo || (league.area && league.area.flag)
      };
    });

    res.status(200).json(leagues);
  } catch (error) {
    console.error('Error fetching leagues:', error.message);
    res.status(500).json({
      error: 'Failed to fetch leagues',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch league standings
exports.fetchLeagueStandings = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const leagueId = req.query.id;
  if (!leagueId) {
    res.status(400).json({ error: 'Missing league ID parameter' });
    return;
  }

  try {
    const response = await axios.get(`${BASE_URL}/competitions/${leagueId}/standings`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error(`Error fetching standings for league ${leagueId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch league standings',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch team images with proper error handling
exports.fetchTeamImages = functions.https.onRequest(async (req, res) => {
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

    // Process the response to ensure we have the best available image
    const teamData = response.data;
    const imageUrl = teamData.crest || teamData.emblem || teamData.logo;

    if (!imageUrl) {
      res.status(404).json({ error: 'No image found for team' });
      return;
    }

    // If the image URL is from our API, use it directly
    if (imageUrl.startsWith('https://crests.football-data.org/')) {
      res.status(200).json({ imageUrl });
      return;
    }

    // For other URLs, proxy the image
    const imageResponse = await axios.get(imageUrl, {
      responseType: 'arraybuffer',
    });

    res.set('Content-Type', imageResponse.headers['content-type'] || 'image/png');
    res.status(200).send(imageResponse.data);
  } catch (error) {
    console.error(`Error fetching team images for team ${teamId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch team images',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch last matches for a competition
exports.fetchLastMatches = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const competitionId = req.query.id;
  if (!competitionId) {
    res.status(400).json({ error: 'Missing competition ID parameter' });
    return;
  }

  try {
    const response = await axios.get(`${BASE_URL}/competitions/${competitionId}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        status: 'FINISHED',
        limit: 10
      }
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error(`Error fetching last matches for competition ${competitionId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch last matches',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch last round's matches for a competition
exports.fetchLastRoundMatches = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const competitionId = req.query.id;
  if (!competitionId) {
    res.status(400).json({ error: 'Missing competition ID parameter' });
    return;
  }

  try {
    // First, get the current matchday
    const standingsResponse = await axios.get(`${BASE_URL}/competitions/${competitionId}/standings`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    
    const currentMatchday = standingsResponse.data.season.currentMatchday;
    
    // Then, get the matches for the last matchday
    const matchesResponse = await axios.get(`${BASE_URL}/competitions/${competitionId}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        matchday: currentMatchday - 1, // Get the previous matchday
        status: 'FINISHED'
      }
    });

    // Process the matches to remove duplicates
    const matches = matchesResponse.data.matches;
    const uniqueMatches = matches.filter((match, index, self) =>
      index === self.findIndex((m) => 
        (m.homeTeam.id === match.homeTeam.id && m.awayTeam.id === match.awayTeam.id) ||
        (m.homeTeam.id === match.awayTeam.id && m.awayTeam.id === match.homeTeam.id)
      )
    );

    res.status(200).json({
      matches: uniqueMatches,
      currentMatchday: currentMatchday
    });
  } catch (error) {
    console.error(`Error fetching last round matches for competition ${competitionId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch last round matches',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch competition images with proper error handling
exports.fetchCompetitionImages = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const competitionId = req.query.id;
  if (!competitionId) {
    res.status(400).json({ error: 'Missing competition ID parameter' });
    return;
  }

  try {
    const response = await axios.get(`${BASE_URL}/competitions/${competitionId}`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });

    // Process the response to ensure we have the best available image
    const competitionData = response.data;
    const imageUrl = competitionData.emblem || competitionData.crest || competitionData.logo;

    if (!imageUrl) {
      res.status(404).json({ error: 'No image found for competition' });
      return;
    }

    // If the image URL is from our API, use it directly
    if (imageUrl.startsWith('https://crests.football-data.org/')) {
      res.status(200).json({ imageUrl });
      return;
    }

    // For other URLs, proxy the image
    const imageResponse = await axios.get(imageUrl, {
      responseType: 'arraybuffer',
    });

    res.set('Content-Type', imageResponse.headers['content-type'] || 'image/png');
    res.status(200).send(imageResponse.data);
  } catch (error) {
    console.error(`Error fetching competition images for competition ${competitionId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch competition images',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});