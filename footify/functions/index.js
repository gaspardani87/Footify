const functions = require('firebase-functions');
const axios = require('axios');

exports.fetchMatches = functions.https.onRequest(async (req, res) => {
  // Get the API key from Firebase config
  const apiKey = functions.config().football_data.key;
  
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const response = await axios.get('https://api.football-data.org/v4/matches', {
      headers: {
        'X-Auth-Token': apiKey // Use the configured API key here
      }
    });
    res.status(200).json(response.data);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});