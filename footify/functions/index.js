const functions = require('firebase-functions');
const axios = require('axios');

// Function to fetch match data
exports.fetchFootballData = functions.https.onRequest(async (req, res) => {
  // Enable CORS for all origins and handle preflight requests
  res.set('Access-Control-Allow-Origin', '');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  // Handle OPTIONS preflight request
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const response = await axios.get('https://api.football-data.org/v4/matches', {
      headers: {
        'X-Auth-Token': '4c553fac5d704101906782d1ecbe1b12',
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

// Function to proxy images
exports.proxyImage = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '');
  res.set('Access-Control-Allow-Methods', 'GET');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  // Handle OPTIONS preflight request
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

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