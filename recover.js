const fs = require('fs');
const path = 'C:\\Users\\Gaurav Nagar\\.gemini\\tmp\\fufaji-online-business\\tool-outputs\\session-005d0119-31af-431d-98ba-d93c4a3dac1a\\read_file_read_file_1779272934354_0_fx9lai.txt';
const target = 'lib/providers/product_provider.dart';

try {
    const rawData = fs.readFileSync(path, 'utf8');
    const json = JSON.parse(rawData);
    if (json.output) {
        fs.writeFileSync(target, json.output, 'utf8');
        console.log('Recovery successful: ' + json.output.length + ' characters written.');
    } else {
        console.error('Error: "output" property not found in JSON.');
    }
} catch (e) {
    console.error('Recovery failed: ' + e.message);
}
