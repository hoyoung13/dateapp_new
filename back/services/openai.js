const axios = require('axios');
const dotenv = require('dotenv');

dotenv.config();

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!OPENAI_API_KEY) {
  console.warn('OPENAI_API_KEY is not set');
}

/**
 * Send chat messages to OpenAI's chat completion API and return the response text.
 * @param {Array} messages - Chat messages following OpenAI Chat format
 * @param {Object} [options] - Additional options for the API call
 * @returns {Promise<string>} The assistant's reply
 */
async function sendChat(messages, options = {}) {
  const data = {
    model: 'gpt-3.5-turbo',
    messages,
    ...options,
  };
  try {
    const res = await axios.post('https://api.openai.com/v1/chat/completions', data, {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
    });
    const content = res.data.choices[0].message.content;
    return content.trim();
  } catch (err) {
    console.error('OpenAI API error:', err.response ? err.response.data : err.message);
    throw err;
  }
}

module.exports = { sendChat };
