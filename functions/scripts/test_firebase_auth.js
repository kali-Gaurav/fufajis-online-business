const fs = require('fs');
const path = require('path');
const axios = require('axios');
const { OAuth2Client } = require('google-auth-library');

async function test() {
    const homeDir = process.env.USERPROFILE || process.env.HOME || 'C:\\Users\\Gaurav Nagar';
    const firebaseConfigPath = path.join(homeDir, '.config', 'configstore', 'firebase-tools.json');
    console.log('Reading config from:', firebaseConfigPath);
    
    if (!fs.existsSync(firebaseConfigPath)) {
        console.error('Config file not found');
        return;
    }
    
    const config = JSON.parse(fs.readFileSync(firebaseConfigPath, 'utf8'));
    const refreshToken = config.tokens?.refresh_token;
    if (!refreshToken) {
        console.error('No refresh token found');
        return;
    }
    
    const client = new OAuth2Client(
        "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
        "j9iVZfS8kkCEFUPaAeJV0sAi"
    );
    client.setCredentials({ refresh_token: refreshToken });
    
    console.log('Refreshing access token...');
    const tokenRes = await client.getAccessToken();
    const accessToken = tokenRes.token;
    console.log('Access token obtained successfully!');
    
    console.log('Attempting to query Firestore REST API for users...');
    const url = 'https://firestore.googleapis.com/v1/projects/fufaji-online-business/databases/(default)/documents/users?pageSize=1';
    const res = await axios.get(url, {
        headers: {
            Authorization: `Bearer ${accessToken}`
        }
    });
    
    console.log('REST API Success! Response data:');
    console.log(JSON.stringify(res.data, null, 2));
}

test().catch(console.error);
