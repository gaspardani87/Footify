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
    // Check if it's an SVG image and try to load PNG version first
    let urlToFetch = imageUrl;
    console.log(`Attempting to fetch image: ${urlToFetch}`);
    
    try {
      const response = await axios.get(urlToFetch, {
        responseType: 'arraybuffer',
        timeout: 10000, // 10 second timeout
        validateStatus: function (status) {
          return status < 500; // Accept any status code less than 500 to handle 404 properly
        }
      });
      
      // Handle 404 separately
      if (response.status === 404) {
        console.log(`Image not found at ${urlToFetch}, sending 404`);
        res.status(404).send('Image not found');
        return;
      }
      
      // If status is not 200, throw error to trigger fallback
      if (response.status !== 200) {
        throw new Error(`Received status ${response.status} for ${urlToFetch}`);
      }
      
      // Get the content type from the response, or determine it from the URL
      let contentType = response.headers['content-type'];
      
      // If content-type is not provided or is octet-stream, try to determine from extension
      if (!contentType || contentType === 'application/octet-stream') {
        if (urlToFetch.toLowerCase().endsWith('.png')) {
          contentType = 'image/png';
        } else if (urlToFetch.toLowerCase().endsWith('.jpg') || urlToFetch.toLowerCase().endsWith('.jpeg')) {
          contentType = 'image/jpeg';
        } else if (urlToFetch.toLowerCase().endsWith('.svg')) {
          contentType = 'image/svg+xml';
        } else {
          // Default to png if we can't determine the type
          contentType = 'image/png';
        }
      }
      
      res.set('Content-Type', contentType);
      res.set('Cache-Control', 'public, max-age=86400'); // Cache for 24 hours
      res.send(response.data);
      
    } catch (error) {
      console.error(`Error proxying image from ${urlToFetch}:`, error.message);
      
      // Check if we were trying to fetch SVG and provide helpful response
      if (imageUrl.toLowerCase().endsWith('.svg')) {
        res.status(500).send('SVG images are not supported directly. Please provide PNG version.');
      } else {
        res.status(500).send('Error loading image: ' + error.message);
      }
    }
  } catch (error) {
    console.error('Unexpected error in proxyImage:', error);
    res.status(500).send('Internal server error');
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

    // Process the response to include proper league data
    const leagues = response.data.competitions.map(league => {
      // Use specific replacement logos for certain leagues
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
        id: league.id.toString(),
        name: league.name,
        code: league.code || '',
        emblem: replacementLogos[league.id] || league.emblem || league.crest || ''
      };
    });

    // Filter out leagues without emblems and sort alphabetically
    const filteredLeagues = leagues
      .filter(league => league.emblem || league.name.includes('Premier') || league.name.includes('La Liga') || league.name.includes('Serie A'))
      .sort((a, b) => a.name.localeCompare(b.name));

    res.status(200).json(filteredLeagues);
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

// Function to fetch head-to-head matches between two teams
exports.fetchHeadToHead = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const team1Id = req.query.team1Id;
  const team2Id = req.query.team2Id;
  const limit = req.query.limit || 10;

  if (!team1Id || !team2Id) {
    res.status(400).json({ error: 'Missing team ID parameters (team1Id and team2Id required)' });
    return;
  }

  try {
    // Get matches for team1 with a higher limit to ensure we find enough head-to-head matches
    const response = await axios.get(`${BASE_URL}/teams/${team1Id}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        limit: limit * 2  // Get more matches to filter for head-to-head
      }
    });

    if (response.status === 200) {
      // Filter matches where team2 was involved
      const allMatches = response.data.matches || [];
      const h2hMatches = allMatches.filter(match => {
        return (match.homeTeam.id === parseInt(team1Id) && match.awayTeam.id === parseInt(team2Id)) || 
               (match.homeTeam.id === parseInt(team2Id) && match.awayTeam.id === parseInt(team1Id));
      }).slice(0, limit);  // Take only the requested number of matches

      res.status(200).json({ matches: h2hMatches });
    } else {
      throw new Error(`API returned status: ${response.status}`);
    }
  } catch (error) {
    console.error(`Error fetching head-to-head matches for teams ${team1Id} and ${team2Id}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch head-to-head matches',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch detailed match statistics
exports.fetchMatchStatistics = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const matchId = req.query.id;
  if (!matchId) {
    res.status(400).json({ error: 'Missing match ID parameter' });
    return;
  }

  try {
    // Get match details first to extract all relevant data
    const response = await axios.get(`${BASE_URL}/matches/${matchId}`, {
      headers: {
        'X-Auth-Token': API_KEY,
      }
    });

    if (response.status === 200) {
      const matchData = response.data;
      
      // Extract existing statistics if available
      const statistics = matchData.statistics || {};
      
      // Process additional statistics
      const processedStats = {
        // Include original statistics if available
        ...statistics,
        
        // Calculate cards count
        cards: {
          home: { yellow: 0, red: 0 },
          away: { yellow: 0, red: 0 }
        },
        
        // Extract goal data
        goals: {
          home: { total: 0, firstHalf: 0, secondHalf: 0 },
          away: { total: 0, firstHalf: 0, secondHalf: 0 }
        }
      };
      
      // Count cards
      if (matchData.bookings && Array.isArray(matchData.bookings)) {
        matchData.bookings.forEach(booking => {
          if (booking.team && booking.team.id) {
            const isHomeTeam = booking.team.id === matchData.homeTeam.id;
            const teamKey = isHomeTeam ? 'home' : 'away';
            
            if (booking.card === 'YELLOW') {
              processedStats.cards[teamKey].yellow++;
            } else if (booking.card === 'RED') {
              processedStats.cards[teamKey].red++;
            }
          }
        });
      }
      
      // Count goals and when they were scored
      if (matchData.goals && Array.isArray(matchData.goals)) {
        matchData.goals.forEach(goal => {
          if (goal.team && goal.team.id) {
            const isHomeTeam = goal.team.id === matchData.homeTeam.id;
            const teamKey = isHomeTeam ? 'home' : 'away';
            
            // Increment total goals
            processedStats.goals[teamKey].total++;
            
            // Determine when the goal was scored
            if (goal.minute <= 45) {
              processedStats.goals[teamKey].firstHalf++;
            } else {
              processedStats.goals[teamKey].secondHalf++;
            }
          }
        });
      }
      
      // Include possession statistics if available in match data
      if (matchData.homeTeam.statistics && matchData.awayTeam.statistics) {
        processedStats.possession = {
          home: matchData.homeTeam.statistics.possession || 0,
          away: matchData.awayTeam.statistics.possession || 0
        };
      }
      
      res.status(200).json({ 
        statistics: processedStats,
        matchId: matchId
      });
    } else {
      throw new Error(`API returned status: ${response.status}`);
    }
  } catch (error) {
    console.error(`Error fetching statistics for match ${matchId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch match statistics',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch top scorers for a competition
exports.fetchTopScorers = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const leagueCode = req.query.leagueCode;
  if (!leagueCode) {
    res.status(400).json({ error: 'Missing league code parameter' });
    return;
  }

  try {
    const response = await axios.get(`${BASE_URL}/competitions/${leagueCode}/scorers`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        limit: 20 // Lekérjük a top 20 góllövőt
      }
    });

    if (response.status === 200) {
      res.status(200).json(response.data);
    } else {
      throw new Error(`API returned status: ${response.status}`);
    }
  } catch (error) {
    console.error(`Error fetching top scorers for league ${leagueCode}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch top scorers',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch all teams
exports.fetchTeams = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  try {
    // We'll use the competitions endpoint and extract teams from there
    const competitions = await axios.get(`${BASE_URL}/competitions`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    
    // Get a few top competitions
    const topCompetitionIds = [2021, 2014, 2019, 2002, 2015]; // Premier League, La Liga, Serie A, Bundesliga, Ligue 1
    
    // Fetch teams from each competition
    const teamsPromises = topCompetitionIds.map(async (competitionId) => {
      try {
        const response = await axios.get(`${BASE_URL}/competitions/${competitionId}/teams`, {
          headers: {
            'X-Auth-Token': API_KEY,
          },
        });
        return response.data.teams || [];
      } catch (error) {
        console.error(`Error fetching teams for competition ${competitionId}: ${error.message}`);
        return [];
      }
    });
    
    // Wait for all teams to be fetched
    const teamSets = await Promise.all(teamsPromises);
    
    // Combine all teams into a single array and remove duplicates
    let allTeams = [];
    const teamIds = new Set();
    
    teamSets.forEach(teamSet => {
      teamSet.forEach(team => {
        if (!teamIds.has(team.id)) {
          teamIds.add(team.id);
          allTeams.push(team);
        }
      });
    });
    
    // Sort teams alphabetically by name
    allTeams.sort((a, b) => a.name.localeCompare(b.name));
    
    res.status(200).json({ teams: allTeams });
  } catch (error) {
    console.error('Error fetching teams:', error.message);
    res.status(500).json({
      error: 'Failed to fetch teams',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch all areas/countries
exports.fetchAreas = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  try {
    // Fetch all areas from the football-data.org API
    const response = await axios.get(`${BASE_URL}/areas`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    
    if (response.status === 200) {
      // Return the complete data with all areas
      res.status(200).json(response.data);
    } else {
      throw new Error(`API returned status: ${response.status}`);
    }
  } catch (error) {
    console.error('Error fetching areas/countries:', error.message);
    res.status(500).json({
      error: 'Failed to fetch areas/countries',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch matches for a team and return data optimized for calendar display
exports.fetchCalendarTeamMatches = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  // Handle CORS preflight requests
  if (handleOptions(req, res)) return;

  const teamId = req.query.id;
  if (!teamId) {
    res.status(400).json({ 
      error: 'Missing team ID parameter',
      success: false
    });
    return;
  }

  try {
    console.log(`Fetching calendar matches for team ${teamId}`);
    
    // We'll try to request matches in two parts to maximize coverage
    // First, get current and future matches
    const futureResponse = await axios.get(`${BASE_URL}/teams/${teamId}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        dateFrom: getDateString(0),     // Today
        dateTo: getDateString(180)      // 6 months in the future (covers future season)
      }
    });
    
    // Next, get historical matches from the past year
    const pastResponse = await axios.get(`${BASE_URL}/teams/${teamId}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        dateFrom: getDateString(-365),  // 1 year ago
        dateTo: getDateString(-1)       // Yesterday
      }
    });
    
    // Combine the matches
    let matches = [];
    
    if (futureResponse.status === 200) {
      const futureMatches = futureResponse.data.matches || [];
      matches = matches.concat(futureMatches);
    }
    
    if (pastResponse.status === 200) {
      const pastMatches = pastResponse.data.matches || [];
      matches = matches.concat(pastMatches);
    }
    
    // Sort matches by date (newest to oldest)
    matches.sort((a, b) => {
      const dateA = new Date(a.utcDate);
      const dateB = new Date(b.utcDate);
      return dateA - dateB;  // Ascending order (oldest to newest)
    });
    
    console.log(`Successfully retrieved ${matches.length} matches for team ${teamId}`);
    
    // Return in a format that's easy to use in the calendar
    res.status(200).json({
      success: true,
      teamId: teamId,
      matches: matches,
      count: matches.length
    });
  } catch (error) {
    console.error(`Error fetching calendar matches for team ${teamId}:`, error);
    
    // Detailed error response to help with debugging
    res.status(500).json({
      error: 'Failed to fetch team matches for calendar',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
      success: false
    });
  }
});

// Helper function to get a date string in YYYY-MM-DD format
// offset is the number of days from today (negative for past, positive for future)
function getDateString(offset = 0) {
  const date = new Date();
  date.setDate(date.getDate() + offset);
  return date.toISOString().split('T')[0];
}

// Function to get team's league
exports.getTeamLeague = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const teamId = req.query.id;
  if (!teamId) {
    res.status(400).json({ error: 'Missing team ID parameter' });
    return;
  }

  try {
    console.log(`Fetching league information for team ${teamId}`);
    
    // First get the team info to check which competitions they are in
    const teamResponse = await axios.get(`${BASE_URL}/teams/${teamId}`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    
    if (teamResponse.status !== 200) {
      throw new Error(`Team API returned status: ${teamResponse.status}`);
    }
    
    const team = teamResponse.data;
    const runningCompetitions = team.runningCompetitions || [];
    
    // Filter for league competitions only (not cups)
    const leagueCompetitions = runningCompetitions.filter(comp => 
      comp.type === 'LEAGUE'
    );
    
    // If we found at least one league
    if (leagueCompetitions.length > 0) {
      // Sort by tier/importance, with top leagues first
      const priorityLeagues = ["PL", "BL1", "SA", "PD", "FL1"]; // Premier League, Bundesliga, Serie A, La Liga, Ligue 1
      
      // Sort leagues by priority
      leagueCompetitions.sort((a, b) => {
        const aPriority = priorityLeagues.indexOf(a.code);
        const bPriority = priorityLeagues.indexOf(b.code);
        
        // If both leagues are in priority list, compare their priorities
        if (aPriority !== -1 && bPriority !== -1) {
          return aPriority - bPriority;
        }
        
        // If only a is in priority list, a comes first
        if (aPriority !== -1) {
          return -1;
        }
        
        // If only b is in priority list, b comes first
        if (bPriority !== -1) {
          return 1;
        }
        
        // If neither is in priority list, sort alphabetically
        return a.name.localeCompare(b.name);
      });
      
      // Take the highest priority league
      const primaryLeague = leagueCompetitions[0];
      
      // Get the league standings for this league
      const standingsResponse = await axios.get(`${BASE_URL}/competitions/${primaryLeague.id}/standings`, {
        headers: {
          'X-Auth-Token': API_KEY,
        },
      });
      
      if (standingsResponse.status !== 200) {
        throw new Error(`Standings API returned status: ${standingsResponse.status}`);
      }
      
      // Return both the league info and the standings
      res.status(200).json({
        success: true,
        team: {
          id: team.id,
          name: team.name,
          crest: team.crest || team.emblem
        },
        league: primaryLeague,
        standings: standingsResponse.data
      });
    } else {
      // No league competitions found
      res.status(200).json({
        success: true,
        team: {
          id: team.id,
          name: team.name,
          crest: team.crest || team.emblem
        },
        league: null,
        message: 'No league competitions found for this team'
      });
    }
  } catch (error) {
    console.error(`Error fetching league for team ${teamId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch team league',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to get national team's competitions
exports.getNationalTeamLeague = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const teamId = req.query.id;
  if (!teamId) {
    res.status(400).json({ error: 'Missing team ID parameter' });
    return;
  }

  try {
    console.log(`Fetching competition information for national team ${teamId}`);
    
    // First get the team info
    const teamResponse = await axios.get(`${BASE_URL}/teams/${teamId}`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
    });
    
    if (teamResponse.status !== 200) {
      throw new Error(`Team API returned status: ${teamResponse.status}`);
    }
    
    const team = teamResponse.data;
    const runningCompetitions = team.runningCompetitions || [];
    
    // For national teams, we're interested in international tournaments
    // like World Cup, Euro, Copa America, etc.
    const internationalCompetitions = runningCompetitions.filter(comp => 
      comp.type === 'CUP' || comp.name.includes('World') || 
      comp.name.includes('Euro') || comp.name.includes('Cup') ||
      comp.name.includes('Championship')
    );
    
    if (internationalCompetitions.length > 0) {
      // Sort by current (ongoing competitions take priority)
      internationalCompetitions.sort((a, b) => {
        // Check if a competition is currently active
        const aHasCurrentSeason = a.currentSeason && 
          new Date(a.currentSeason.startDate) <= new Date() && 
          new Date(a.currentSeason.endDate) >= new Date();
          
        const bHasCurrentSeason = b.currentSeason && 
          new Date(b.currentSeason.startDate) <= new Date() && 
          new Date(b.currentSeason.endDate) >= new Date();
        
        // Current competitions first
        if (aHasCurrentSeason && !bHasCurrentSeason) return -1;
        if (!aHasCurrentSeason && bHasCurrentSeason) return 1;
        
        // Otherwise sort by start date (most recent first)
        if (a.currentSeason && b.currentSeason) {
          return new Date(b.currentSeason.startDate) - new Date(a.currentSeason.startDate);
        }
        
        return 0;
      });
      
      // Take the top competition
      const primaryCompetition = internationalCompetitions[0];
      
      // Try to get standings if available
      try {
        const standingsResponse = await axios.get(`${BASE_URL}/competitions/${primaryCompetition.id}/standings`, {
          headers: {
            'X-Auth-Token': API_KEY,
          },
        });
        
        if (standingsResponse.status === 200) {
          // Return both the competition info and the standings
          res.status(200).json({
            success: true,
            team: {
              id: team.id,
              name: team.name,
              crest: team.crest || team.emblem
            },
            competition: primaryCompetition,
            standings: standingsResponse.data
          });
          return;
        }
      } catch (standingsError) {
        console.log(`No standings available for competition ${primaryCompetition.id}, continuing without standings`);
      }
      
      // If we reach here, no standings were available
      res.status(200).json({
        success: true,
        team: {
          id: team.id,
          name: team.name,
          crest: team.crest || team.emblem
        },
        competition: primaryCompetition,
        standings: null,
        message: 'No standings available for this competition'
      });
    } else {
      // No international competitions found
      res.status(200).json({
        success: true,
        team: {
          id: team.id,
          name: team.name,
          crest: team.crest || team.emblem
        },
        competition: null,
        message: 'No active competitions found for this national team'
      });
    }
  } catch (error) {
    console.error(`Error fetching competitions for national team ${teamId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch national team competitions',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch matches for a specific date
exports.getMatchesByDate = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const date = req.query.date;
  if (!date) {
    res.status(400).json({ error: 'Missing date parameter (format: YYYY-MM-DD)' });
    return;
  }

  try {
    console.log(`Fetching matches for date: ${date}`);
    
    // Date validation - ensure it's in YYYY-MM-DD format
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(date)) {
      res.status(400).json({ error: 'Invalid date format. Use YYYY-MM-DD' });
      return;
    }
    
    // Get matches for the specified date
    const response = await axios.get(`${BASE_URL}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        dateFrom: date,
        dateTo: date,
      }
    });
    
    if (response.status === 200) {
      const matches = response.data.matches || [];
      
      // Group matches by competition for better organization
      const matchesByCompetition = {};
      
      matches.forEach(match => {
        const competition = match.competition;
        const competitionId = competition.id;
        
        if (!matchesByCompetition[competitionId]) {
          matchesByCompetition[competitionId] = {
            competition: {
              id: competition.id,
              name: competition.name,
              code: competition.code,
              type: competition.type,
              emblem: competition.emblem
            },
            matches: []
          };
        }
        
        matchesByCompetition[competitionId].matches.push(match);
      });
      
      // Convert to array and sort by competition name
      const matchesArray = Object.values(matchesByCompetition)
        .sort((a, b) => a.competition.name.localeCompare(b.competition.name));
      
      res.status(200).json({
        success: true,
        date: date,
        matchCount: matches.length,
        competitions: matchesArray,
        matches: matches  // Also include flat list for backward compatibility
      });
    } else {
      throw new Error(`API returned status: ${response.status}`);
    }
  } catch (error) {
    console.error(`Error fetching matches for date ${date}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch matches by date',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to get next match for a team
exports.getNextMatch = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const teamId = req.query.id;
  if (!teamId) {
    res.status(400).json({ error: 'Missing team ID parameter' });
    return;
  }

  try {
    console.log(`Fetching next match for team ${teamId}`);
    
    // Get future matches for this team
    const today = new Date();
    const dateFrom = today.toISOString().split('T')[0]; // Today in YYYY-MM-DD
    
    // Get date 6 months from now
    const dateTo = new Date(today);
    dateTo.setMonth(today.getMonth() + 6);
    const dateToString = dateTo.toISOString().split('T')[0];
    
    const response = await axios.get(`${BASE_URL}/teams/${teamId}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        dateFrom: dateFrom,
        dateTo: dateToString,
        status: 'SCHEDULED',
        limit: 1  // We only need the next match
      }
    });
    
    if (response.status === 200) {
      const matches = response.data.matches || [];
      
      if (matches.length > 0) {
        // Return the first upcoming match
        res.status(200).json({
          success: true,
          teamId: teamId,
          match: matches[0]
        });
      } else {
        // No upcoming matches found
        res.status(200).json({
          success: true,
          teamId: teamId,
          match: null,
          message: 'No upcoming matches found for this team'
        });
      }
    } else {
      throw new Error(`API returned status: ${response.status}`);
    }
  } catch (error) {
    console.error(`Error fetching next match for team ${teamId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch next match',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to get next match for a national team
exports.getNationalTeamNextMatch = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const teamId = req.query.id;
  if (!teamId) {
    res.status(400).json({ error: 'Missing team ID parameter' });
    return;
  }

  try {
    console.log(`Fetching next match for national team ${teamId}`);
    
    // Get future matches for this national team
    const today = new Date();
    const dateFrom = today.toISOString().split('T')[0]; // Today in YYYY-MM-DD
    
    // Get date 1 year from now (national teams play less often)
    const dateTo = new Date(today);
    dateTo.setFullYear(today.getFullYear() + 1);
    const dateToString = dateTo.toISOString().split('T')[0];
    
    const response = await axios.get(`${BASE_URL}/teams/${teamId}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        dateFrom: dateFrom,
        dateTo: dateToString,
        status: 'SCHEDULED',
        limit: 1  // We only need the next match
      }
    });
    
    if (response.status === 200) {
      const matches = response.data.matches || [];
      
      if (matches.length > 0) {
        // Return the first upcoming match
        res.status(200).json({
          success: true,
          teamId: teamId,
          match: matches[0]
        });
      } else {
        // No upcoming matches found
        res.status(200).json({
          success: true,
          teamId: teamId,
          match: null,
          message: 'No upcoming matches found for this national team'
        });
      }
    } else {
      throw new Error(`API returned status: ${response.status}`);
    }
  } catch (error) {
    console.error(`Error fetching next match for national team ${teamId}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch next match for national team',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to get upcoming matches (not limited by date)
exports.getUpcomingMatches = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  try {
    console.log('Fetching upcoming matches');
    
    // Get today's date and format it as YYYY-MM-DD
    const today = new Date();
    const dateFrom = today.toISOString().split('T')[0];
    
    // Get date 7 days from now
    const dateTo = new Date(today);
    dateTo.setDate(today.getDate() + 7);
    const dateToString = dateTo.toISOString().split('T')[0];
    
    // Get matches for the next 7 days
    const response = await axios.get(`${BASE_URL}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        dateFrom: dateFrom,
        dateTo: dateToString,
        status: 'SCHEDULED'
      }
    });
    
    if (response.status === 200) {
      const matches = response.data.matches || [];
      
      // Group matches by date
      const matchesByDate = {};
      
      matches.forEach(match => {
        // Extract date from match.utcDate (format: YYYY-MM-DD)
        const matchDate = match.utcDate.split('T')[0];
        
        if (!matchesByDate[matchDate]) {
          matchesByDate[matchDate] = [];
        }
        
        matchesByDate[matchDate].push(match);
      });
      
      // Convert to array of objects with date and matches
      const matchesArray = Object.entries(matchesByDate).map(([date, dateMatches]) => ({
        date,
        matches: dateMatches
      }));
      
      // Sort by date (ascending)
      matchesArray.sort((a, b) => new Date(a.date) - new Date(b.date));
      
      res.status(200).json({
        success: true,
        dateFrom: dateFrom,
        dateTo: dateToString,
        matchCount: matches.length,
        matchesByDate: matchesArray,
        matches: matches  // Also include flat list for backward compatibility
      });
    } else {
      throw new Error(`API returned status: ${response.status}`);
    }
  } catch (error) {
    console.error('Error fetching upcoming matches:', error.message);
    res.status(500).json({
      error: 'Failed to fetch upcoming matches',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Function to fetch matches for a date range
exports.getMatchesForDateRange = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const dateFrom = req.query.dateFrom;
  const dateTo = req.query.dateTo;
  
  if (!dateFrom || !dateTo) {
    res.status(400).json({ error: 'Missing dateFrom and dateTo parameters (format: YYYY-MM-DD)' });
    return;
  }

  try {
    console.log(`Fetching matches for date range: ${dateFrom} to ${dateTo}`);
    
    // Date validation
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(dateFrom) || !dateRegex.test(dateTo)) {
      res.status(400).json({ error: 'Invalid date format. Use YYYY-MM-DD' });
      return;
    }
    
    // Get matches for the specified date range
    const response = await axios.get(`${BASE_URL}/matches`, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      params: {
        dateFrom: dateFrom,
        dateTo: dateTo,
      }
    });
    
    if (response.status === 200) {
      const matches = response.data.matches || [];
      
      // Organize matches by date for easier lookup
      const matchesByDate = {};
      
      matches.forEach(match => {
        // Extract date from match.utcDate (format: YYYY-MM-DD)
        const matchDate = match.utcDate.split('T')[0];
        
        if (!matchesByDate[matchDate]) {
          matchesByDate[matchDate] = [];
        }
        
        matchesByDate[matchDate].push(match);
      });
      
      res.status(200).json({
        success: true,
        dateFrom: dateFrom,
        dateTo: dateTo,
        totalMatchCount: matches.length,
        matchesByDate: matchesByDate
      });
    } else {
      throw new Error(`API returned status: ${response.status}`);
    }
  } catch (error) {
    console.error(`Error fetching matches for date range ${dateFrom} to ${dateTo}:`, error.message);
    res.status(500).json({
      error: 'Failed to fetch matches by date range',
      details: error.message || 'Unknown error',
      status: error.response ? error.response.status : null,
    });
  }
});

// Search matches by query
exports.searchMatches = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const { query } = req.query;
  if (!query) {
    console.log("[searchMatches] Error: Query parameter is missing.");
    return res.status(400).json({ error: 'Query parameter is required' });
  }
  console.log(`[searchMatches] Received query: "${query}"`);

  try {
    // Get matches from top competitions
    const topCompetitionIds = [2021, 2014, 2019, 2002, 2015]; // Premier League, La Liga, Serie A, Bundesliga, Ligue 1
    console.log(`[searchMatches] Fetching matches for competitions: ${topCompetitionIds.join(', ')} for query "${query}"`);
    
    const matchesPromises = topCompetitionIds.map(async (competitionId) => {
      try {
        const url = `${BASE_URL}/competitions/${competitionId}/matches`;
        console.log(`[searchMatches] Fetching from URL: ${url}`);
        const response = await axios.get(url, {
          headers: {
            'X-Auth-Token': API_KEY,
          },
          timeout: 10000, // 10 second timeout
        });
        console.log(`[searchMatches] API response status for competition ${competitionId}: ${response.status}`);
        return response.data.matches || [];
      } catch (error) {
        console.error(`[searchMatches] Error fetching matches for competition ${competitionId}:`, error.message);
        if (error.response) {
          console.error(`[searchMatches] API Error Status: ${error.response.status}`);
          console.error(`[searchMatches] API Error Data:`, error.response.data);
          if (error.response.status === 429) {
            console.warn(`[searchMatches] Rate limit hit for competition ${competitionId}.`);
          }
        } else if (error.request) {
          console.error("[searchMatches] API No response received for competition", competitionId);
        } else {
          console.error("[searchMatches] API Request setup error for competition", competitionId, error.message);
        }
        return []; // Return empty on error for this specific competition
      }
    });

    const matchesSets = await Promise.all(matchesPromises);
    let allMatches = matchesSets.flat(); // Combine results from all competitions
    console.log(`[searchMatches] Total matches fetched before filtering: ${allMatches.length}`);

    // Filter matches based on query
    const searchQuery = query.toLowerCase();
    const filteredMatches = allMatches.filter(match => {
      const homeTeam = match?.homeTeam?.name?.toLowerCase() || '';
      const awayTeam = match?.awayTeam?.name?.toLowerCase() || '';
      const competitionName = match?.competition?.name?.toLowerCase() || '';
      
      return homeTeam.includes(searchQuery) || 
             awayTeam.includes(searchQuery) || 
             competitionName.includes(searchQuery);
    });
    console.log(`[searchMatches] Total matches after filtering for "${query}": ${filteredMatches.length}`);

    // Sort matches by date (most recent first)
    filteredMatches.sort((a, b) => {
      try {
        return new Date(b.utcDate) - new Date(a.utcDate);
      } catch (e) {
        return 0; // Avoid crash if date is invalid
      }
    });

    res.status(200).json(filteredMatches);
  } catch (error) {
    console.error(`[searchMatches] Unexpected error searching matches for "${query}":`, error.message);
    res.status(500).json({
      error: 'Failed to search matches',
      details: error.message || 'Unknown error',
    });
  }
});

// Search teams by query
exports.searchTeams = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const { query } = req.query;
  if (!query) {
    console.log("[searchTeams] Error: Query parameter is missing.");
    return res.status(400).json({ error: 'Query parameter is required' });
  }
  console.log(`[searchTeams] Received query: "${query}"`);

  try {
    // Get teams from top competitions
    const topCompetitionIds = [2021, 2014, 2019, 2002, 2015];
    console.log(`[searchTeams] Fetching teams for competitions: ${topCompetitionIds.join(', ')} for query "${query}"`);

    const teamsPromises = topCompetitionIds.map(async (competitionId) => {
      try {
        const url = `${BASE_URL}/competitions/${competitionId}/teams`;
        console.log(`[searchTeams] Fetching from URL: ${url}`);
        const response = await axios.get(url, {
          headers: {
            'X-Auth-Token': API_KEY,
          },
           timeout: 10000, // 10 second timeout
        });
        console.log(`[searchTeams] API response status for competition ${competitionId}: ${response.status}`);
        return response.data.teams || [];
      } catch (error) {
        console.error(`[searchTeams] Error fetching teams for competition ${competitionId}:`, error.message);
         if (error.response) {
          console.error(`[searchTeams] API Error Status: ${error.response.status}`);
          console.error(`[searchTeams] API Error Data:`, error.response.data);
           if (error.response.status === 429) {
            console.warn(`[searchTeams] Rate limit hit for competition ${competitionId}.`);
          }
        } else if (error.request) {
          console.error("[searchTeams] API No response received for competition", competitionId);
        } else {
          console.error("[searchTeams] API Request setup error for competition", competitionId, error.message);
        }
        return [];
      }
    });

    const teamsSets = await Promise.all(teamsPromises);
    let allTeams = teamsSets.flat();
    console.log(`[searchTeams] Total teams fetched before filtering: ${allTeams.length}`);

    // Remove duplicates
    const uniqueTeams = [];
    const teamIds = new Set();
    allTeams.forEach(team => {
      if (team && team.id && !teamIds.has(team.id)) { // Added check for team and team.id
        teamIds.add(team.id);
        uniqueTeams.push(team);
      }
    });
    console.log(`[searchTeams] Total unique teams: ${uniqueTeams.length}`);

    // Filter teams based on query
    const searchQuery = query.toLowerCase();
    const filteredTeams = uniqueTeams.filter(team => {
      const teamName = team?.name?.toLowerCase() || '';
      const shortName = team?.shortName?.toLowerCase() || '';
      const tla = team?.tla?.toLowerCase() || '';
      
      return teamName.includes(searchQuery) || 
             shortName.includes(searchQuery) || 
             tla.includes(searchQuery);
    });
    console.log(`[searchTeams] Total teams after filtering for "${query}": ${filteredTeams.length}`);

    // Sort teams alphabetically
    filteredTeams.sort((a, b) => (a.name || '').localeCompare(b.name || ''));

    res.status(200).json(filteredTeams);
  } catch (error) {
    console.error(`[searchTeams] Unexpected error searching teams for "${query}":`, error.message);
    res.status(500).json({
      error: 'Failed to search teams',
      details: error.message || 'Unknown error',
    });
  }
});

// Search competitions by query
exports.searchCompetitions = functions.https.onRequest(async (req, res) => {
  setCorsHeaders(res);
  
  if (handleOptions(req, res)) return;

  const { query } = req.query;
  if (!query) {
    console.log("[searchCompetitions] Error: Query parameter is missing.");
    return res.status(400).json({ error: 'Query parameter is required' });
  }
  console.log(`[searchCompetitions] Received query: "${query}"`);

  try {
    const url = `${BASE_URL}/competitions`;
    console.log(`[searchCompetitions] Fetching from URL: ${url}`);
    const response = await axios.get(url, {
      headers: {
        'X-Auth-Token': API_KEY,
      },
      timeout: 10000, // 10 second timeout
    });
    console.log(`[searchCompetitions] API response status: ${response.status}`);

    const competitions = response.data.competitions || [];
    console.log(`[searchCompetitions] Total competitions fetched: ${competitions.length}`);
    const searchQuery = query.toLowerCase();

    // Filter competitions based on query
    const filteredCompetitions = competitions.filter(competition => {
      const name = competition?.name?.toLowerCase() || '';
      const code = competition?.code?.toLowerCase() || '';
      
      return name.includes(searchQuery) || 
             code.includes(searchQuery);
    });
    console.log(`[searchCompetitions] Total competitions after filtering for "${query}": ${filteredCompetitions.length}`);

    // Sort competitions alphabetically
    filteredCompetitions.sort((a, b) => (a.name || '').localeCompare(b.name || ''));

    res.status(200).json(filteredCompetitions);
  } catch (error) {
    console.error(`[searchCompetitions] Error searching competitions for "${query}":`, error.message);
    if (error.response) {
      console.error(`[searchCompetitions] API Error Status: ${error.response.status}`);
      console.error(`[searchCompetitions] API Error Data:`, error.response.data);
      if (error.response.status === 429) {
        console.warn(`[searchCompetitions] Rate limit hit.`);
      }
    } else if (error.request) {
      console.error("[searchCompetitions] API No response received.");
    } else {
      console.error("[searchCompetitions] API Request setup error.", error.message);
    }
    res.status(500).json({
      error: 'Failed to search competitions',
      details: error.message || 'Unknown error',
    });
  }
});